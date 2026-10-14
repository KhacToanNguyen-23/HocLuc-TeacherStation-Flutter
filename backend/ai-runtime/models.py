"""Local checkpoints only. No training, model downloads or lesson logging."""
from pathlib import Path
import gc
import json
import os
import time

ROOT = Path(__file__).resolve().parent

def settings():
    path = Path(os.environ.get('HOC_LUC_AI_CONFIG', ROOT / 'config/models.local.json'))
    if not path.is_file():
        path = ROOT / 'config/models.example.json'
    config = json.loads(path.read_text(encoding='utf-8'))
    config['root'] = os.environ.get('HOC_LUC_AI_MODELS', config['root'])
    return config

def preflight():
    config = settings()
    paths = {key: Path(config['root']) / config[key] for key in ('asr', 'translation', 'tts')}
    required = {
        'asr': ['config.json', 'pytorch_model.bin', 'tokenizer.json', 'preprocessor_config.json'],
        'translation': ['config.json', 'pytorch_model.bin', 'sentencepiece.bpe.model'],
        'tts': ['config.json', 'kokoro-v1_0.pth', 'voices/' + config['voice'] + '.pt'],
    }
    missing = [str(paths[key] / item) for key, names in required.items() for item in names
               if not (paths[key] / item).is_file() or (paths[key] / item).stat().st_size < 2]
    return {'assetsReady': not missing, 'missing': missing, 'device': config['device'],
            'voices': sorted(p.stem for p in (paths['tts'] / 'voices').glob('[ab][fm]_*.pt')),
            'modelNames': {key: config[key] for key in paths},
            'asrInt8Available': (Path(config['root']) / (config['asr']+'-ct2-int8') / 'model.bin').is_file(),
            'translationInt8Available': (Path(config['root']) / (config['translation']+'-ct2-int8') / 'model.bin').is_file()}

class Pipeline:
    def __init__(self):
        self.loaded = False
        self.asr = self.processor = self.mt = self.tokenizer = self.tts = None

    def load(self):
        if self.loaded:
            return
        assets = preflight()
        if not assets['assetsReady']:
            raise RuntimeError('Thiếu model local: ' + ', '.join(assets['missing']))
        import torch
        from transformers import WhisperProcessor, WhisperForConditionalGeneration, AutoTokenizer, AutoModelForSeq2SeqLM
        from kokoro import KModel, KPipeline
        cfg = settings()
        torch.set_num_threads(int(cfg['threads']))
        self.device = cfg['device']
        if self.device == 'cuda' and not torch.cuda.is_available():
            raise RuntimeError('CUDA chưa sẵn sàng trong runtime này.')
        base = Path(cfg['root'])
        asr = base / cfg['asr']
        mt = base / cfg['translation']
        tts = base / cfg['tts']
        self.asr_int8 = cfg.get('prefer_int8', False) and (base / (cfg['asr']+'-ct2-int8') / 'model.bin').is_file()
        self.mt_int8 = cfg.get('prefer_int8', False) and (base / (cfg['translation']+'-ct2-int8') / 'model.bin').is_file()
        if self.asr_int8:
            self.asr_device = cfg.get('asr_device', 'cpu')
            if self.asr_device == 'auto':
                self.asr_device = 'cuda' if torch.cuda.is_available() else 'cpu'
            # Keep DLL handles alive. CUDA libraries come from the isolated Torch wheel.
            if self.asr_device == 'cuda' and os.name == 'nt':
                self.cuda_dll_handle = os.add_dll_directory(str(Path(torch.__file__).parent / 'lib'))
            from faster_whisper import WhisperModel
            # GTX 1650 pilot produced unrelated transcripts with float16 activations.
            self.asr_compute = 'int8_float32' if self.asr_device == 'cuda' else 'int8'
            self.asr = WhisperModel(str(base / (cfg['asr']+'-ct2-int8')), device=self.asr_device, compute_type=self.asr_compute, cpu_threads=int(cfg['threads']), num_workers=1, local_files_only=True)
        else:
            self.asr_device, self.asr_compute = self.device, 'float32'
            self.processor = WhisperProcessor.from_pretrained(asr, local_files_only=True)
            self.asr = WhisperForConditionalGeneration.from_pretrained(asr, local_files_only=True).eval().to(self.device)
        self.tokenizer = AutoTokenizer.from_pretrained(mt, src_lang='vi_VN', local_files_only=True)
        if self.mt_int8:
            import ctranslate2
            self.mt = ctranslate2.Translator(str(base / (cfg['translation']+'-ct2-int8')), device='cpu', compute_type='int8', inter_threads=1, intra_threads=int(cfg['threads']))
        else:
            self.mt = AutoModelForSeq2SeqLM.from_pretrained(mt, local_files_only=True).eval()
        self.tts_device = cfg.get('tts_device', 'cpu')
        if self.tts_device == 'auto':
            self.tts_device = 'cuda' if torch.cuda.is_available() else 'cpu'
        model = KModel(config=str(tts / 'config.json'), model=str(tts / 'kokoro-v1_0.pth'), repo_id='hexgrad/Kokoro-82M').eval().to(self.tts_device)
        self.tts = KPipeline(lang_code='a', model=model, repo_id='hexgrad/Kokoro-82M', device=self.tts_device)
        self.voice_dir = tts / 'voices'
        self.loaded = True

    def execution(self):
        if not self.loaded:
            return {}
        return {'asrDevice': self.asr_device, 'asrCompute': self.asr_compute,
                'translationDevice': 'cpu', 'translationCompute': 'int8' if self.mt_int8 else 'float32',
                'ttsDevice': self.tts_device}

    def transcribe(self, audio):
        import numpy as np
        import torch
        samples = np.asarray(audio, dtype=np.float32)
        if len(samples) < 1600 or float(np.sqrt(np.mean(samples * samples))) < 0.004:
            return ''
        if self.asr_int8:
            segments, _ = self.asr.transcribe(samples, language='vi', task='transcribe', beam_size=2,
                                             condition_on_previous_text=False, vad_filter=False)
            return ' '.join(segment.text.strip() for segment in segments).strip()
        with torch.inference_mode():
            features = self.processor(samples, sampling_rate=16000, return_tensors='pt').input_features.to(self.device)
            tokens = self.asr.generate(features, language='vi', task='transcribe', max_new_tokens=160)
        return self.processor.batch_decode(tokens, skip_special_tokens=True)[0].strip()

    def translate(self, text):
        import torch
        if not text.strip():
            return ''
        if self.mt_int8:
            ids = self.tokenizer.encode(text, truncation=True, max_length=512)
            tokens = self.tokenizer.convert_ids_to_tokens(ids)
            output = self.mt.translate_batch([tokens], target_prefix=[['en_XX']], beam_size=2, max_decoding_length=192)[0].hypotheses[0]
            return self.tokenizer.decode(self.tokenizer.convert_tokens_to_ids(output), skip_special_tokens=True).strip()
        inputs = self.tokenizer(text, return_tensors='pt', truncation=True, max_length=512)
        with torch.inference_mode():
            output = self.mt.generate(**inputs, decoder_start_token_id=self.tokenizer.lang_code_to_id['en_XX'],
                                      num_beams=2, max_new_tokens=192, early_stopping=True)
        return self.tokenizer.batch_decode(output, skip_special_tokens=True)[0].strip()

    def speak(self, text, voice='af_heart'):
        import numpy as np
        import torch
        if voice not in preflight()['voices']:
            raise ValueError('Giọng đọc English không hợp lệ.')
        if not text.strip():
            return np.empty(0, dtype=np.float32)
        voice_tensor = torch.load(self.voice_dir / (voice + '.pt'), map_location='cpu', weights_only=True)
        parts = [item.audio.detach().cpu().numpy() for item in self.tts(text, voice=voice_tensor) if item.audio is not None]
        return np.concatenate(parts).astype(np.float32) if parts else np.empty(0, dtype=np.float32)

    def segment(self, audio, voice='af_heart'):
        start = time.perf_counter()
        vi = self.transcribe(audio)
        asr_end = time.perf_counter()
        en = self.translate(vi)
        mt_end = time.perf_counter()
        sound = self.speak(en, voice)
        return vi, en, sound, {'asrMs': round((asr_end-start)*1000), 'translationMs': round((mt_end-asr_end)*1000),
                              'ttsMs': round((time.perf_counter()-mt_end)*1000)}

    def unload(self):
        self.asr = self.processor = self.mt = self.tokenizer = self.tts = None
        self.loaded = False
        gc.collect()
