"""Contract/privacy boundaries and real FFmpeg rendering, without mock inference."""
import json
from pathlib import Path
import subprocess
import sys
import wave

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from preparation_runtime import atomic_json, ffmpeg
from preparation_worker import Job, main, validate_scenes


@pytest.mark.parametrize('key', ['ollamaUrl', 'authoringModel', 'apiKey', 'endpoint', 'model'])
def test_python_runtime_rejects_authoring_configuration(key, tmp_path, monkeypatch):
    import preparation_runtime as runtime
    configuration = tmp_path / 'runtime.json'
    monkeypatch.setattr(runtime, 'CONFIG', configuration)
    with pytest.raises(ValueError, match='Unknown runtime setting'):
        runtime.configure({key: 'must-not-be-stored'})
    assert not configuration.exists()


def test_capabilities_ignore_legacy_ollama_configuration(tmp_path, monkeypatch):
    import preparation_runtime as runtime
    configuration = tmp_path / 'runtime.json'
    atomic_json(configuration, {'ollamaUrl': 'http://obsolete.invalid', 'authoringModel': 'legacy-model',
                                'apiKey': 'SECRET_SENTINEL'})
    monkeypatch.setattr(runtime, 'CONFIG', configuration)
    # The runtime must never discover tags or send a legacy credential anywhere.
    import urllib.request
    monkeypatch.setattr(urllib.request, 'urlopen', lambda *a, **k: pytest.fail('Unexpected network request'))
    monkeypatch.setattr(urllib.request, 'build_opener', lambda *a, **k: pytest.fail('Unexpected network client'))
    result = runtime.capabilities()
    assert result['authoring']['provider'] == 'managed-by-backend'
    assert result['authoring']['ready'] is False
    assert result['authoring']['models'] == []
    assert 'SECRET_SENTINEL' not in json.dumps(result)
    assert 'legacy-model' not in json.dumps(result)


def test_script_path_is_manual_and_keeps_private_fields_out(tmp_path):
    result = Job({'kind': 'author', 'workspace': str(tmp_path), 'inputMode': 'script',
                  'language': 'en', 'text': 'First paragraph.\n\nSecond paragraph.',
                  'teacherNotes': 'PRIVATE_SENTINEL'}).execute()
    assert result['method'] == 'manual-script'
    assert len(result['scenes']) == 2
    assert 'PRIVATE_SENTINEL' not in json.dumps(result)
    assert json.loads((tmp_path / 'progress.json').read_text())['ratio'] == 1


def test_invalid_authoring_is_not_a_fake_success(tmp_path, monkeypatch):
    monkeypatch.setattr('preparation_worker.config', lambda: {'authoringModel': 'legacy-model'})
    request = tmp_path / 'request.json'
    output = tmp_path / 'result.json'
    atomic_json(request, {'kind': 'author', 'workspace': str(tmp_path / 'job'), 'text': 'Explain photosynthesis'})
    assert main(['--request', str(request), '--output', str(output)]) == 1
    assert 'handled by the backend API' in json.loads(output.read_text(encoding='utf-8'))['error']
    assert json.loads(output.read_text(encoding='utf-8'))['artifacts'] == []


@pytest.mark.parametrize('text', ['', 'x' * 40001, None], ids=['empty', 'oversized', 'non-text'])
def test_manual_script_keeps_input_validation(text, tmp_path):
    with pytest.raises(ValueError):
        Job({'kind': 'author', 'workspace': str(tmp_path), 'inputMode': 'script',
             'language': 'en', 'text': text}).execute()


def test_manual_script_rejects_oversized_scene(tmp_path):
    with pytest.raises(ValueError, match='1800'):
        Job({'kind': 'author', 'workspace': str(tmp_path), 'inputMode': 'script',
             'language': 'en', 'text': 'x' * 1801}).execute()


def test_scene_ids_and_templates_are_not_executable():
    with pytest.raises(ValueError):
        validate_scenes([{'id': '../escape', 'text': 'Hello'}])
    with pytest.raises(ValueError):
        validate_scenes([{'text': 'Hello', 'template': '<script>alert(1)</script>'}])
    with pytest.raises(ValueError):
        validate_scenes([{'id': 'same', 'text': 'A'}, {'id': 'same', 'text': 'B'}])


def test_editor_text_alias_and_generated_templates_match_renderer():
    for template in ('text', 'slide', 'diagram', 'highlight'):
        scenes = validate_scenes([{'id': 'scene', 'text': 'Hello', 'template': template}])
        assert scenes[0]['template'] == ('slide' if template == 'text' else template)


def test_generated_paths_cannot_escape_workspace(tmp_path):
    job = Job({'kind': 'speech', 'workspace': str(tmp_path), 'text': 'Hello'})
    with pytest.raises(ValueError):
        job.path('../outside.wav')


def test_real_ffmpeg_three_scene_render_has_video_audio_and_captions(tmp_path):
    # A synthetic WAV is a media fixture only, not presented as model speech.
    import math
    import struct
    with wave.open(str(tmp_path / 'fixture.wav'), 'wb') as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(24000)
        wav.writeframes(b''.join(struct.pack('<h', int(1600 * math.sin(2 * math.pi * 440 * i / 24000)))
                                 for i in range(24_000)))
    request = {'kind': 'render', 'workspace': str(tmp_path / 'render'), 'teacherNotes': 'PRIVATE_SENTINEL',
               'scenes': [{'id': 'scene-' + str(i), 'title': 'Example ' + str(i),
                          'text': 'Water → Evaporation → Clouds' if i == 1 else 'A short classroom example.',
                          'narration': 'A short classroom example.', 'language': 'en',
                          'template': ['slide', 'diagram', 'highlight'][i],
                          'audioPath': str(tmp_path / 'fixture.wav')} for i in range(3)]}
    request['scenes'][0].update({'captionsReviewed': True,
        'captionsNarration': 'A short classroom example.',
        'captions': [{'id': 'reviewed-a', 'start': .1, 'end': .9, 'text': 'Teacher-edited public caption.'}]})
    result = Job(request).execute()
    artifacts = {a['kind']: Path(a['path']) for a in result['artifacts']}
    assert artifacts['video'].stat().st_size > 10_000
    # Decode the actual MP4 to verify both streams, not only file existence.
    completed = subprocess.run([ffmpeg(), '-v', 'error', '-i', str(artifacts['video']),
                                '-map', '0:v:0', '-map', '0:a:0', '-f', 'null', '-'], capture_output=True)
    assert completed.returncode == 0, completed.stderr
    timeline = json.loads(artifacts['timeline'].read_text())
    assert timeline['width'] == 1280 and timeline['height'] == 720 and timeline['fps'] == 25
    assert abs(timeline['duration'] - 3) < .25
    decoded_audio = subprocess.run([ffmpeg(), '-v', 'error', '-i', str(artifacts['video']),
        '-map', '0:a:0', '-ac', '1', '-ar', '24000', '-f', 's16le', '-'], capture_output=True)
    assert decoded_audio.returncode == 0, decoded_audio.stderr
    # One final AAC frame of tail padding is allowed, not one per scene.
    assert abs(len(decoded_audio.stdout) / 48000 - timeline['duration']) <= .05
    assert 'A short classroom example.' in artifacts['subtitle'].read_text()
    assert 'Teacher-edited public caption.' in artifacts['subtitle'].read_text()
    assert '00:00:00,100 --> 00:00:00,900' in artifacts['subtitle'].read_text()
    assert 'PRIVATE_SENTINEL' not in artifacts['subtitle'].read_text()
    assert 'PRIVATE_SENTINEL' not in artifacts['timeline'].read_text()


def test_capabilities_does_not_load_torch(tmp_path):
    runtime = Path(__file__).resolve().parents[1]
    code = "import sys; from preparation_runtime import capabilities; capabilities(); assert 'torch' not in sys.modules"
    result = subprocess.run([sys.executable, '-c', code], cwd=runtime, capture_output=True, timeout=20)
    assert result.returncode == 0, result.stderr
