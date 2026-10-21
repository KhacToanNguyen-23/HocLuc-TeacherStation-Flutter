"""Configuration and bounded subprocess primitives for offline lesson jobs.

Imported by capabilities without importing torch or loading a checkpoint.
"""
from pathlib import Path
import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent
CONFIG = ROOT / 'config' / 'preparation.local.json'


def atomic_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=path.name + '.', dir=path.parent)
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as stream:
            json.dump(value, stream, ensure_ascii=False, allow_nan=False)
        os.replace(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)


def config():
    result = json.loads(CONFIG.read_text(encoding='utf-8')) if CONFIG.exists() else {}
    if os.environ.get('HOC_LUC_PREPARATION_CONFIG'):
        result.update(json.loads(Path(os.environ['HOC_LUC_PREPARATION_CONFIG']).read_text(encoding='utf-8')))
    return result


def configure(values):
    allowed = {'modelRoot', 'ffmpegPath'}
    if set(values) - allowed:
        raise ValueError('Unknown runtime setting.')
    saved = config()
    for key, value in values.items():
        if not isinstance(value, str) or len(value) > 2048:
            raise ValueError('Invalid setting: ' + key)
        if key in ('modelRoot', 'ffmpegPath'):
            target = Path(value).resolve(strict=True)
            if key == 'modelRoot' and not target.is_dir():
                raise ValueError('Model root must be a directory.')
            if key == 'ffmpegPath' and not target.is_file():
                raise ValueError('FFmpeg must be an executable file.')
            value = str(target)
        saved[key] = value
    atomic_json(CONFIG, saved)
    return capabilities()


def ffmpeg():
    value = config().get('ffmpegPath') or shutil.which('ffmpeg')
    if not value and importlib.util.find_spec('imageio_ffmpeg'):
        import imageio_ffmpeg
        value = imageio_ffmpeg.get_ffmpeg_exe()
    if not value or not Path(value).is_file():
        raise RuntimeError('FFmpeg missing. Select an installed FFmpeg executable in runtime settings.')
    return str(value)


def run_ffmpeg(arguments, timeout=1800):
    # stderr is kept local, never copied wholesale into the UI/log (source filenames).
    completed = subprocess.run([ffmpeg(), '-hide_banner', '-nostdin', '-y', *map(str, arguments)],
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout,
                               creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
    if completed.returncode:
        raise RuntimeError('FFmpeg failed (exit %s). Check media format, disk space and runtime.' % completed.returncode)
    return completed


def capabilities():
    cfg = config()
    packages = {name: importlib.util.find_spec(name) is not None
                for name in ('torch', 'transformers', 'kokoro', 'PIL', 'soundfile', 'numpy')}
    try:
        binary = ffmpeg()
        version = subprocess.run([binary, '-version'], capture_output=True, timeout=10,
                                 creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
        ff = {'ready': version.returncode == 0,
              'version': version.stdout.decode('utf-8', errors='replace').splitlines()[0]}
    except Exception:
        ff = {'ready': False}
    # Authoring credentials and provider calls belong exclusively to the backend.
    author = {'provider': 'managed-by-backend', 'ready': False, 'models': [],
              'reason': 'Lesson AI authoring is handled by the backend API.'}
    from models import settings
    model_cfg = settings()
    base = Path(cfg.get('modelRoot', model_cfg['root']))
    models = {stage: {'path': str(base / model_cfg[stage]), 'present': (base / model_cfg[stage]).is_dir(),
                      'int8Present': (base / (model_cfg[stage] + '-ct2-int8') / 'model.bin').is_file()}
              for stage in ('asr', 'translation', 'tts')}
    return {'python': sys.executable, 'packages': packages, 'ffmpeg': ff, 'models': models,
            'authoring': author, 'cloudEnabled': False,
            'recording': {'supported': False, 'reason': 'Upload a recording produced by the app capture flow.'}}
