import sys
import types
from pathlib import Path
from unittest.mock import patch

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from preparation_cache import LessonCache, cache_key
from preparation_worker import Job


def request(tmp_path, name='one'):
    return {'kind':'render', 'workspace':str(tmp_path/'lesson'/'jobs'/name),
            'cacheDirectory':str(tmp_path/'lesson'/'render-cache')}


def test_cache_reuses_across_jobs_but_detects_corruption_and_bounds_path(tmp_path):
    first = Job(request(tmp_path))
    source = first.path('sound.wav')
    source.write_bytes(b'cached sound')
    key = cache_key({'text':'independent scene'})
    cache = LessonCache(first)
    cache.save(key,'.wav',source)
    next_job = Job(request(tmp_path,'two'))
    target = next_job.path('copy.wav')
    assert LessonCache(next_job).restore(key,'.wav',target)
    assert target.read_bytes() == source.read_bytes()
    cache.file(key,'.wav').write_bytes(b'corrupted')
    assert not cache.restore(key,'.wav',target)
    next_job.request['cacheDirectory'] = str(tmp_path/'other-lesson'/'render-cache')
    with pytest.raises(ValueError):
        LessonCache(next_job)


def test_speech_only_resynthesizes_changed_spoken_dependency(tmp_path):
    import numpy as np
    calls = []
    class FakePipeline:
        def __init__(self, stage):
            assert stage == 'tts'
        def speak(self,text,voice):
            calls.append((text,voice))
            return np.zeros(4800,dtype=np.float32)
        def unload(self):
            pass
    stub = types.ModuleType('preparation_models')
    stub.StagePipeline = FakePipeline
    model_version = ['v1']
    with patch.dict(sys.modules,{'preparation_models':stub}), patch('preparation_cache.speech_identity',side_effect=lambda voice:{'voice':voice,'model':model_version[0]}):
        first = Job(request(tmp_path))
        first.synthesize(['Read API.', 'Other independent scene.'],[first.path('a.wav'),first.path('b.wav')])
        assert len(calls) == 2
        second = Job(request(tmp_path,'two'))
        second.request['glossary'] = [{'term':'API','replacement':'A P I'}]
        second.synthesize(['Read API.', 'Other independent scene.'],[second.path('a.wav'),second.path('b.wav')])
        assert calls[-1][0] == 'Read A P I.'
        assert len(calls) == 3
        third = Job(request(tmp_path,'three'))
        third.request['glossary'] = second.request['glossary']
        third.request['scenes'] = [{'captions':[{'text':'Caption-only edit'}]}]
        with patch.object(FakePipeline,'__init__',side_effect=AssertionError('must not load model')):
            third.synthesize(['Read API.', 'Other independent scene.'],[third.path('a.wav'),third.path('b.wav')])
        assert len(calls) == 3
        fourth = Job(request(tmp_path,'four'))
        fourth.request.update(glossary=second.request['glossary'],voice='am_michael')
        fourth.synthesize(['Read API.', 'Other independent scene.'],[fourth.path('a.wav'),fourth.path('b.wav')])
        assert len(calls) == 5
        model_version[0] = 'v2'
        fifth = Job(request(tmp_path,'five'))
        fifth.request.update(glossary=second.request['glossary'],voice='am_michael')
        fifth.synthesize(['Read API.', 'Other independent scene.'],[fifth.path('a.wav'),fifth.path('b.wav')])
        assert len(calls) == 7


def test_cache_key_ignores_dictionary_order_but_tracks_visual_changes():
    assert cache_key({'text':'a','template':'slide'}) == cache_key({'template':'slide','text':'a'})
    assert cache_key({'text':'a'}) != cache_key({'text':'b'})


def test_render_reuses_independent_scene_video_when_other_scene_changes(tmp_path,monkeypatch):
    import numpy as np
    import soundfile as sf
    import preparation_render as renderer
    encoded = []
    def draw(scene,path):
        path.write_bytes(scene['text'].encode())
    def encode(image,audio,video,duration):
        encoded.append(image.read_bytes())
        video.write_bytes(b'rendered-'+image.read_bytes())
        return duration
    monkeypatch.setattr(renderer,'draw_scene',draw)
    monkeypatch.setattr(renderer,'encode_scene',encode)
    monkeypatch.setattr(renderer,'run_ffmpeg',lambda arguments:Path(arguments[-1]).write_bytes(b'assembled'))
    def setup(name,changed=False):
        job=Job(request(tmp_path,name))
        job.request['scenes']=[{'id':'a','title':'A','text':'Changed' if changed else 'A', 'narration':'A','language':'en','template':'slide'},
                               {'id':'b','title':'B','text':'B','narration':'B','language':'en','template':'slide'}]
        def synthesize(texts,paths,*args):
            for path in paths:
                sf.write(path,np.zeros(4800,dtype=np.float32),24000,subtype='PCM_16')
        job.synthesize=synthesize
        return job
    renderer.render(setup('one'))
    assert encoded == [b'A',b'B']
    renderer.render(setup('two',True))
    assert encoded == [b'A',b'B',b'Changed']
