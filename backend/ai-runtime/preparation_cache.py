"""Bounded per-lesson cache, keyed by actual speech/render dependencies."""
from pathlib import Path
import hashlib
import json
import os
import shutil
import tempfile

LIMIT = 512 * 1024 * 1024


def digest_file(path):
    value = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            value.update(block)
    return value.hexdigest()


def cache_key(value):
    return hashlib.sha256(json.dumps(value, ensure_ascii=False, sort_keys=True,
                                     separators=(',', ':'), allow_nan=False).encode('utf-8')).hexdigest()


def speech_identity(voice):
    from models import settings
    from preparation_runtime import config
    cfg = settings()
    base = Path(config().get('modelRoot', cfg['root'])) / cfg['tts']
    stamps = []
    for relative in ['config.json', 'kokoro-v1_0.pth', 'voices/' + voice + '.pt']:
        path = base / relative
        stat = path.stat() if path.is_file() else None
        stamps.append([str(path.resolve()), stat.st_size if stat else None, stat.st_mtime_ns if stat else None])
    return {'engine': 'kokoro-pcm24k-v1', 'voice': voice, 'modelFiles': stamps,
            'device': cfg.get('tts_device', 'cpu')}


class LessonCache:
    def __init__(self, job):
        requested = job.request.get('cacheDirectory')
        self.root = None
        if requested:
            expected = job.workspace.parent.parent / 'render-cache'
            root = Path(requested).resolve()
            if job.workspace.parent.name != 'jobs' or root != expected.resolve():
                raise ValueError('Cache must belong to the current lesson.')
            root.mkdir(parents=True, exist_ok=True)
            self.root = root

    def file(self, key, suffix):
        if not self.root:
            return None
        if len(key) != 64 or any(c not in '0123456789abcdef' for c in key) or suffix not in ('.wav', '.png', '.mkv'):
            raise ValueError('Invalid cache key.')
        return self.root / (key + suffix)

    def restore(self, key, suffix, destination):
        path = self.file(key, suffix)
        if not path or not path.is_file() or path.stat().st_size == 0:
            return False
        try:
            stamp = path.with_suffix(suffix + '.sha256')
            if not stamp.is_file() or digest_file(path) != stamp.read_text(encoding='ascii'):
                return False
            shutil.copyfile(path, destination)
            path.touch()
            return True
        except OSError:
            return False

    def save(self, key, suffix, source):
        path = self.file(key, suffix)
        if not path or Path(source).stat().st_size > LIMIT:
            return
        temporary = None
        try:
            fd, temporary = tempfile.mkstemp(dir=self.root, prefix='cache-')
            os.close(fd)
            shutil.copyfile(source, temporary)
            os.replace(temporary, path)
            path.with_suffix(suffix + '.sha256').write_text(digest_file(path), encoding='ascii')
            files = sorted((p for p in self.root.iterdir() if p.suffix in ('.wav', '.png', '.mkv')), key=lambda p: p.stat().st_mtime)
            total = sum(p.stat().st_size for p in files)
            for old in files:
                if total <= LIMIT:
                    break
                total -= old.stat().st_size
                old.unlink(missing_ok=True)
                old.with_suffix(old.suffix + '.sha256').unlink(missing_ok=True)
        except OSError:
            # Cache is optional; a disk-cache failure must not invalidate output.
            pass
        finally:
            if temporary:
                Path(temporary).unlink(missing_ok=True)
