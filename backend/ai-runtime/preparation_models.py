"""Load only the speech checkpoint needed by a preparation stage.

Reuses Pipeline inference methods; does not call Pipeline.load(), which eagerly
loads all three models for the older streaming workflow.
"""
from pathlib import Path
import os
from models import Pipeline, settings
from preparation_runtime import config


class StagePipeline(Pipeline):
    def __init__(self, stage):
        super().__init__()
        cfg = settings()
        root = config().get('modelRoot', cfg['root'])
        os.environ['HOC_LUC_AI_MODELS'] = root
        import torch
        torch.set_num_threads(int(cfg['threads']))
        self.device = cfg['device']
        if self.device == 'cuda' and not torch.cuda.is_available():
            raise RuntimeError('Configured CUDA device is unavailable.')
        base = Path(root)
        if stage == 'asr':
            self.asr_int8 = cfg.get('prefer_int8', False) and (base / (cfg['asr'] + '-ct2-int8') / 'model.bin').is_file()
            if self.asr_int8:
                from faster_whisper import WhisperModel
                self.asr_device = cfg.get('asr_device', 'cpu')
                if self.asr_device == 'auto':
                    self.asr_device = 'cuda' if torch.cuda.is_available() else 'cpu'
                if self.asr_device == 'cuda' and os.name == 'nt':
                    self.cuda_dll_handle = os.add_dll_directory(str(Path(torch.__file__).parent / 'lib'))
                self.asr_compute = 'int8_float32' if self.asr_device == 'cuda' else 'int8'
                self.asr = WhisperModel(str(base / (cfg['asr'] + '-ct2-int8')), device=self.asr_device,
                    compute_type=self.asr_compute, cpu_threads=int(cfg['threads']), num_workers=1, local_files_only=True)
            else:
                from transformers import WhisperProcessor, WhisperForConditionalGeneration
                self.processor = WhisperProcessor.from_pretrained(base / cfg['asr'], local_files_only=True)
                self.asr = WhisperForConditionalGeneration.from_pretrained(base / cfg['asr'], local_files_only=True).eval().to(self.device)
        elif stage == 'translation':
            from transformers import AutoTokenizer, AutoModelForSeq2SeqLM, MBart50Tokenizer
            self.mt_int8 = cfg.get('prefer_int8', False) and (base / (cfg['translation'] + '-ct2-int8') / 'model.bin').is_file()
            mt_path = base / cfg['translation']
            # Converted local model folders can carry their own tokenizer files.
            token_path = mt_path if mt_path.is_dir() else base / (cfg['translation'] + '-ct2-int8')
            if not mt_path.is_dir() and self.mt_int8 and (token_path / 'sentencepiece.bpe.model').is_file():
                # CT2 config.json describes inference, not a Hugging Face model.
                self.tokenizer = MBart50Tokenizer(vocab_file=str(token_path / 'sentencepiece.bpe.model'), src_lang='vi_VN')
            else:
                self.tokenizer = AutoTokenizer.from_pretrained(token_path, src_lang='vi_VN', local_files_only=True)
            if self.mt_int8:
                import ctranslate2
                self.mt = ctranslate2.Translator(str(base / (cfg['translation'] + '-ct2-int8')), device='cpu',
                    compute_type='int8', inter_threads=1, intra_threads=int(cfg['threads']))
            else:
                self.mt = AutoModelForSeq2SeqLM.from_pretrained(mt_path, local_files_only=True).eval()
        elif stage == 'tts':
            from kokoro import KModel, KPipeline
            path = base / cfg['tts']
            self.tts_device = cfg.get('tts_device', 'cpu')
            if self.tts_device == 'auto':
                self.tts_device = 'cuda' if torch.cuda.is_available() else 'cpu'
            model = KModel(config=str(path / 'config.json'), model=str(path / 'kokoro-v1_0.pth'),
                           repo_id='hexgrad/Kokoro-82M').eval().to(self.tts_device)
            self.tts = KPipeline(lang_code='a', model=model, repo_id='hexgrad/Kokoro-82M', device=self.tts_device)
            self.voice_dir = path / 'voices'
        else:
            raise ValueError('Unknown speech stage.')
        self.loaded = True

    def unload(self):
        super().unload()
        import torch
        if torch.cuda.is_available():
            torch.cuda.empty_cache()
