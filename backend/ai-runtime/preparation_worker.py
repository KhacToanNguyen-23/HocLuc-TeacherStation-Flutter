"""Managed one-job CLI for lesson preparation; never imported by live Meet.

python preparation_worker.py --request request.json --output result.json
All generated paths are inside request.workspace. Caller authenticates ownership
of source/image/audio paths before passing a request. No shell or generated code.
"""
from pathlib import Path
import argparse
import hashlib
import json
import math
import os
import re
import sys
import time

from preparation_runtime import atomic_json, capabilities, configure, config, run_ffmpeg

KINDS = {'transcribe', 'author', 'translate', 'speech', 'render'}
TEMPLATES = {'slide', 'diagram', 'highlight', 'image'}
MAX_TEXT = 100_000
MAX_SCENES = 80


def bounded_text(value, limit=MAX_TEXT, label='text'):
    if not isinstance(value, str) or not value.strip() or len(value) > limit:
        raise ValueError('%s must be nonempty text (maximum %d characters).' % (label, limit))
    return value.strip()


def number(value, label, minimum=0, maximum=7200):
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or not minimum <= value <= maximum:
        raise ValueError('Invalid ' + label)
    return value


def language(request, default='en'):
    result = request.get('language', default)
    if result not in ('vi', 'en'):
        raise ValueError('Only Vietnamese source and English narration are supported.')
    return result


def validate_scenes(scenes):
    if not isinstance(scenes, list) or not 1 <= len(scenes) <= MAX_SCENES:
        raise ValueError('A lesson requires 1–80 scenes.')
    result, ids = [], set()
    for index, item in enumerate(scenes):
        if not isinstance(item, dict):
            raise ValueError('Invalid scene object.')
        scene_id = str(item.get('id', 'scene-%d' % (index + 1)))
        if not re.fullmatch(r'[A-Za-z0-9_-]{1,80}', scene_id) or scene_id in ids:
            raise ValueError('Scene IDs must be unique safe identifiers.')
        ids.add(scene_id)
        template = item.get('template', 'slide')
        if template == 'text':
            template = 'slide'  # Early editor drafts used this alias.
        if template not in TEMPLATES:
            raise ValueError('Unsupported scene template.')
        text = bounded_text(item.get('text', item.get('narration', '')), 1800, 'scene text')
        narration = item.get('narration', text)
        bounded_text(narration, 5000, 'narration')
        scene = {'id': scene_id, 'title': bounded_text(item.get('title', 'Scene %d' % (index + 1)), 160, 'scene title'),
                 'text': text, 'narration': narration, 'language': language(item), 'template': template}
        for key in ('captions', 'captionsReviewed', 'captionsNarration', 'captionMode', 'captionsVisible'):
            if key in item:
                scene[key] = item[key]
        if scene.get('captionMode', 'english') not in ('english', 'bilingual'):
            raise ValueError('Caption mode must be english or bilingual.')
        if not isinstance(scene.get('captionsVisible', True), bool):
            raise ValueError('Caption visibility must be boolean.')
        if scene.get('captionsReviewed') is True and scene.get('captionsNarration') != narration:
            raise ValueError('Reviewed captions are stale: review them after changing narration.')
        for key in ('audioPath', 'imagePath'):
            if item.get(key):
                path = Path(item[key]).resolve(strict=True)
                if not path.is_file():
                    raise ValueError('Scene asset must be a local file.')
                scene[key] = str(path)
        if template == 'image' and not scene.get('imagePath'):
            raise ValueError('Image template requires an uploaded image.')
        result.append(scene)
    return result


def apply_pronunciation_glossary(text, entries):
    """Apply only explicitly reviewed narration substitutions, never private notes."""
    if not isinstance(entries, list) or len(entries) > 200:
        raise ValueError('Glossary must contain at most 200 entries.')
    for entry in entries:
        if not isinstance(entry, dict):
            raise ValueError('Invalid glossary entry.')
        term = bounded_text(entry.get('term'), 100, 'term')
        replacement = bounded_text(entry.get('replacement'), 2000, 'replacement')
        pattern = (r'(?<!\w)' if term[0].isalnum() else '') + re.escape(term) + (r'(?!\w)' if term[-1].isalnum() else '')
        text = re.sub(pattern, lambda _: replacement, text)
    return text


class Job:
    def __init__(self, request):
        if not isinstance(request, dict) or request.get('kind') not in KINDS:
            raise ValueError('Unknown preparation job kind.')
        self.request = request
        self.workspace = Path(bounded_text(request.get('workspace'), 2048, 'workspace')).resolve()
        self.workspace.mkdir(parents=True, exist_ok=True)
        self.started = time.monotonic()
        self.progress('queued', 0)

    def path(self, name):
        path = (self.workspace / name).resolve()
        if not path.is_relative_to(self.workspace):
            raise ValueError('Output escaped job workspace.')
        return path

    def progress(self, stage, ratio):
        atomic_json(self.path('progress.json'), {'stage': stage, 'ratio': round(ratio, 4),
                    'elapsedSeconds': round(time.monotonic() - self.started, 2)})

    def artifact(self, path, kind, mime):
        path = Path(path).resolve(strict=True)
        if not path.is_relative_to(self.workspace) or not path.is_file() or path.stat().st_size == 0:
            raise ValueError('Invalid generated artifact.')
        return {'path': str(path), 'name': path.name, 'kind': kind, 'mimeType': mime}

    def execute(self):
        method = getattr(self, self.request['kind'])
        result = method()
        result.setdefault('artifacts', [])
        self.progress('complete', 1)
        return result

    def transcribe(self):
        if language(self.request, 'vi') != 'vi':
            raise ValueError('Current STT checkpoint supports Vietnamese; select Vietnamese source.')
        source = Path(self.request['sourcePath']).resolve(strict=True)
        start = number(self.request.get('start', 0), 'start')
        end = self.request.get('end')
        arguments = ['-ss', start, '-i', source]
        if end is not None:
            end = number(end, 'end', start + .01)
            arguments += ['-t', end - start]
        else:
            arguments += ['-t', 7200.04]
        wav = self.path('source-16k.wav')
        self.progress('extracting-audio', .02)
        run_ffmpeg(arguments + ['-vn', '-ac', 1, '-ar', 16000, '-c:a', 'pcm_s16le', wav])
        import soundfile as sf
        from preparation_models import StagePipeline
        self.progress('loading-asr', .08)
        model = StagePipeline('asr')
        from models import settings
        source_stat = source.stat()
        model_settings = settings()
        model_root = Path(config().get('modelRoot', model_settings['root']))
        checkpoint_stats = {}
        for candidate in (model_root / model_settings['asr'] / 'pytorch_model.bin',
                          model_root / (model_settings['asr'] + '-ct2-int8') / 'model.bin'):
            if candidate.is_file():
                stat = candidate.stat()
                checkpoint_stats[str(candidate)] = [stat.st_size, stat.st_mtime_ns]
        identity = hashlib.sha256(json.dumps({'source': str(source), 'size': source_stat.st_size,
                 'mtime': source_stat.st_mtime_ns, 'start': start, 'end': end, 'config': config(),
                 'modelSettings': model_settings, 'checkpoints': checkpoint_stats}, sort_keys=True).encode()).hexdigest()
        checkpoint_path = self.path('transcript.checkpoint.json')
        transcript, processed_seconds = [], 0
        if checkpoint_path.exists():
            checkpoint = json.loads(checkpoint_path.read_text(encoding='utf-8'))
            if checkpoint.get('identity') == identity:
                transcript = checkpoint['transcript']
                processed_seconds = checkpoint['processedSeconds']
        try:
            with sf.SoundFile(wav) as stream:
                if stream.samplerate != 16000 or stream.channels != 1 or stream.frames <= 0:
                    raise ValueError('Decoded source has no supported audio.')
                if stream.frames / 16000 > 7200:
                    raise ValueError('Source exceeds the current two-hour limit; select a shorter range.')
                total = stream.frames
                stream.seek(min(total, round(processed_seconds * 16000)))
                index = round(processed_seconds / 20)
                while stream.tell() < total:
                    offset = stream.tell() / 16000
                    audio = stream.read(20 * 16000, dtype='float32')
                    text = model.transcribe(audio)
                    if text:
                        transcript.append({'id': 'segment-%d' % index, 'start': round(start + offset, 3),
                            'end': round(start + offset + len(audio) / 16000, 3), 'text': text})
                    index += 1
                    atomic_json(checkpoint_path, {'identity': identity, 'transcript': transcript,
                                'processedSeconds': stream.tell() / 16000})
                    self.progress('transcribing', .1 + .85 * stream.tell() / total)
        finally:
            model.unload()
        return {'text': '\n'.join(item['text'] for item in transcript), 'transcript': transcript,
                'timingMethod': '20-second source chunks; not word alignment',
                'artifacts': [self.artifact(self.path('transcript.checkpoint.json'), 'transcript', 'application/json')]}

    def translate_texts(self, texts, begin=.1, span=.8):
        from preparation_models import StagePipeline
        self.progress('loading-translation', begin)
        model = StagePipeline('translation')
        results = []
        try:
            for index, text in enumerate(texts):
                # Token-aware split avoids Pipeline.translate's truncation at 512.
                words, fragments, current = text.split(), [], []
                for word in words:
                    proposed = ' '.join([*current, word])
                    if len(model.tokenizer.encode(proposed)) > 100:
                        if not current:
                            raise ValueError('A translation token exceeds supported segment size.')
                        fragments.append(' '.join(current))
                        current = [word]
                    else:
                        current.append(word)
                if current:
                    fragments.append(' '.join(current))
                result = []
                for fragment in fragments:
                    translated = model.translate(fragment)
                    if not translated:
                        raise RuntimeError('Translation returned empty text; review source.')
                    result.append(translated)
                results.append(' '.join(result))
                self.progress('translating', begin + span * (index + 1) / len(texts))
        finally:
            model.unload()
        return results

    def translate(self):
        if language(self.request, 'vi') != 'vi':
            raise ValueError('Current translation supports Vietnamese → English only.')
        text = bounded_text(self.request.get('text'))
        return {'text': self.translate_texts([text])[0], 'language': 'en'}

    def synthesize(self, texts, paths, begin=.1, span=.8):
        import soundfile as sf
        from preparation_cache import LessonCache, cache_key, speech_identity
        cache = LessonCache(self)
        voice = self.request.get('voice', 'af_heart')
        identity = speech_identity(voice)
        spoken = [apply_pronunciation_glossary(text, self.request.get('glossary', [])) for text in texts]
        keys = [cache_key({'speech': identity, 'text': text}) for text in spoken]
        missing = [index for index, (key, path) in enumerate(zip(keys, paths)) if not cache.restore(key, '.wav', path)]
        if not missing:
            self.progress('reusing-audio', begin + span)
            return
        from preparation_models import StagePipeline
        self.progress('loading-tts', begin)
        model = StagePipeline('tts')
        try:
            for position, index in enumerate(missing):
                samples = model.speak(spoken[index], voice)
                if len(samples) == 0:
                    raise RuntimeError('TTS returned no audio; no artifact was created.')
                sf.write(paths[index], samples, 24000, subtype='PCM_16')
                cache.save(keys[index], '.wav', paths[index])
                self.progress('synthesizing', begin + span * (position + 1) / len(missing))
        finally:
            model.unload()

    def speech(self):
        if language(self.request) != 'en':
            raise ValueError('Kokoro narration is English only. Translate the script first.')
        text = bounded_text(self.request.get('text'), 20_000)
        path = self.path('narration.wav')
        self.synthesize([text], [path])
        return {'text': text, 'artifacts': [self.artifact(path, 'audio', 'audio/wav')]}

    def author(self):
        text = bounded_text(self.request.get('text'), 40_000)
        lang = language(self.request)
        if self.request.get('inputMode') == 'script':
            # Explicitly a manual script conversion, not AI-written lesson content.
            paragraphs = [x.strip() for x in re.split(r'\n\s*\n', text) if x.strip()]
            if any(len(x) > 1800 for x in paragraphs):
                raise ValueError('Split script into paragraphs of at most 1800 characters per scene.')
            scenes = validate_scenes([{'id': 'scene-%d' % (i + 1), 'title': 'Scene %d' % (i + 1),
                      'text': part, 'narration': part, 'language': lang} for i, part in enumerate(paragraphs)])
            return {'scenes': scenes, 'sections': [{'id': s['id'], 'title': s['title'], 'body': s['text'],
                    'objective': '', 'teacherNotes': '', 'minutes': 0} for s in scenes], 'method': 'manual-script', 'reviewRequired': True}
        raise RuntimeError('Lesson AI authoring is handled by the backend API. '
                           'This local worker supports manual-script conversion only; no local model fallback.')

    def render(self):
        from preparation_render import render
        return render(self)


def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument('--request')
    parser.add_argument('--output')
    parser.add_argument('--capabilities', action='store_true')
    parser.add_argument('--configure', help='JSON local media settings file; unknown keys rejected')
    args = parser.parse_args(argv)
    if args.capabilities or args.configure:
        result = configure(json.loads(Path(args.configure).read_text(encoding='utf-8-sig'))) if args.configure else capabilities()
        print(json.dumps(result, ensure_ascii=False))
        return 0
    if not args.request or not args.output:
        parser.error('--request and --output are required for a job')
    job = None
    try:
        request_path = Path(args.request)
        if request_path.stat().st_size > 2 * 1024 * 1024:
            raise ValueError('Job request exceeds size limit.')
        job = Job(json.loads(request_path.read_text(encoding='utf-8-sig')))
        result = job.execute()
        atomic_json(args.output, result)
        return 0
    except Exception as error:
        # A failed result is explicit, never a successful placeholder transcript.
        safe = str(error) if isinstance(error, (ValueError, RuntimeError)) else type(error).__name__ + ': job failed; check installed runtime and local assets.'
        if job:
            job.progress('failed', 0)
        atomic_json(args.output, {'error': safe, 'artifacts': []})
        print(safe, file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
