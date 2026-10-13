import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import asyncio
import numpy as np
import pytest
from fastapi.testclient import TestClient
from streaming import Segmenter
import server

def test_silence_never_produces_segment():
    detector = Segmenter()
    assert all(detector.push(np.zeros(1600, np.float32)) is None for _ in range(100))

def test_sentence_is_finalized_once_after_pause():
    detector = Segmenter()
    assert all(detector.push(np.full(1600, .1, np.float32)) is None for _ in range(10))
    outputs = [detector.push(np.zeros(1600, np.float32)) for _ in range(20)]
    assert sum(value is not None for value in outputs) == 1
    assert outputs[5] is not None

def test_long_speech_has_bounded_segments():
    detector = Segmenter()
    outputs = [detector.push(np.full(1600, .1, np.float32)) for _ in range(125)]
    assert sum(value is not None for value in outputs) == 2
    assert max(len(value) for value in outputs if value is not None) == 96000

@pytest.mark.parametrize('frame', [np.array([float('nan')],np.float32), np.zeros((10,2)), np.zeros(16001)])
def test_invalid_pcm_is_rejected(frame):
    with pytest.raises(ValueError):
        Segmenter().push(frame)

@pytest.fixture
def client(monkeypatch):
    monkeypatch.setattr(server, 'TOKEN', 'test-proof-that-has-thirty-two-bytes')
    monkeypatch.setattr(server, 'active_lock', asyncio.Lock())
    monkeypatch.setattr(server, 'preflight', lambda: {'assetsReady': True, 'voices': ['af_heart']})
    monkeypatch.setattr(server, 'ensure_models', lambda: None)
    monkeypatch.setattr(server, 'process_segment', lambda audio, voice: ('câu Việt', 'English sentence', np.ones(2400,np.float32)*.1, {'asrMs': 1}))
    with TestClient(server.app) as value:
        yield value

def test_health_requires_internal_proof(client):
    assert client.get('/health').status_code == 403
    assert client.get('/health',headers={'X-AI-Token': server.TOKEN}).status_code == 200

def test_websocket_finalized_segment_has_ordered_text_and_audio(client):
    with client.websocket_connect('/stream?token='+server.TOKEN) as socket:
        assert socket.receive_json()['type'] == 'preparing'
        assert socket.receive_json()['type'] == 'ready'
        for _ in range(10): socket.send_bytes(np.full(1600,.1,np.float32).tobytes())
        for _ in range(6): socket.send_bytes(np.zeros(1600,np.float32).tobytes())
        result = socket.receive_json()
        assert result['type'] == 'transcript' and result['segmentId'] == 1
        assert result['en'] == 'English sentence'
        assert len(socket.receive_bytes()) == 2400*4
        socket.send_text('stop')

def test_bad_frame_stops_session_instead_of_speaking(client):
    with client.websocket_connect('/stream?token='+server.TOKEN) as socket:
        socket.receive_json(); socket.receive_json()
        socket.send_bytes(b'bad')
        assert socket.receive_json()['type'] == 'error'

def test_foreign_origin_cannot_open_audio_session(client):
    from starlette.websockets import WebSocketDisconnect
    with pytest.raises(WebSocketDisconnect):
        with client.websocket_connect('/stream?token='+server.TOKEN,headers={'Origin':'https://example.invalid'}):
            pass

def test_offline_wav_has_same_contract_without_microphone_capture(client):
    import soundfile as sf
    import io
    buffer = io.BytesIO()
    sf.write(buffer, np.full(16000, .1, np.float32), 16000, format='WAV')
    response = client.post('/file', content=buffer.getvalue(), headers={'X-AI-Token':server.TOKEN,'Content-Type':'audio/wav'})
    assert response.status_code == 200
    assert response.json()['en'] == 'English sentence'
    assert response.json()['sampleRate'] == 24000

def test_offline_wav_rejects_invalid_and_oversized_input(client):
    headers = {'X-AI-Token':server.TOKEN,'Content-Type':'audio/wav'}
    assert client.post('/file',content=b'not a wav',headers=headers).status_code == 400
    assert client.post('/file',content=b'x'*4_000_001,headers=headers).status_code == 400
