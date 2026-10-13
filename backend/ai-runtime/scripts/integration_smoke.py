"""Opt-in real Java/Python smoke with a user-provided Vietnamese WAV.

Never writes bootstrap tokens or WebSocket URLs to reports.
"""
import argparse
import asyncio
import base64
import json
import secrets
import time
from pathlib import Path

import httpx
import numpy as np
import soundfile as sf
import websockets
from scipy.signal import resample_poly
from math import gcd


async def run(args):
    out = Path(args.report_dir)
    out.mkdir(parents=True, exist_ok=True)
    owner = secrets.token_urlsafe(24)
    report = {'scope': 'Real Java HTTP + Python models + WebSocket; no microphone, native playback or Meet',
              'input': str(Path(args.wav).resolve())}
    async with httpx.AsyncClient(base_url=args.base, timeout=180) as client:
        bootstrap = (await client.get('/api/bootstrap')).json()
        client.headers['X-Companion-Token'] = bootstrap['token']
        report['before'] = (await client.get('/api/audio/status')).json()
        try:
            start = time.perf_counter()
            result = await client.post('/api/audio/file', params={'voice': 'af_heart', 'clientId': owner},
                                       content=Path(args.wav).read_bytes(), headers={'Content-Type': 'audio/wav'})
            result.raise_for_status()
            data = result.json()
            sound = np.frombuffer(base64.b64decode(data.pop('samples')), dtype='<f4')
            if not data['vi'] or not data['en'] or not len(sound):
                raise RuntimeError('Offline pipeline produced empty speech/text')
            sf.write(out/'http-english.wav', sound, data['sampleRate'])
            report['file'] = {**data, 'elapsedMs': round((time.perf_counter()-start)*1000),
                              'audioSeconds': round(len(sound)/data['sampleRate'], 3)}
            report['loaded'] = (await client.get('/api/audio/status')).json()
            session = await client.post('/api/audio/connect', json={'voice': 'af_heart', 'language': 'en', 'clientId': owner})
            session.raise_for_status()
            audio, rate = sf.read(args.wav, dtype='float32', always_2d=True)
            factor = gcd(rate, 16000)
            audio = resample_poly(audio.mean(axis=1), 16000//factor, rate//factor).astype('<f4')[:88000]
            audio = np.concatenate([audio, np.zeros(16000, dtype='<f4')])
            async with websockets.connect(session.json()['url'], max_size=2_000_000) as socket:
                while True:
                    state = json.loads(await asyncio.wait_for(socket.recv(), 90))
                    if state['type'] == 'error':
                        raise RuntimeError(state['message'])
                    if state['type'] == 'ready':
                        break
                async def feed():
                    for i in range(0, len(audio), 1600):
                        await socket.send(audio[i:i+1600].tobytes())
                        await asyncio.sleep(.1)
                feeding = asyncio.create_task(feed())
                transcript = None
                try:
                    while True:
                        message = await asyncio.wait_for(socket.recv(), 60)
                        if isinstance(message, bytes):
                            if transcript is None or not message:
                                raise RuntimeError('Unexpected or empty stream PCM')
                            sf.write(out/'stream-english.wav', np.frombuffer(message, dtype='<f4'), 24000)
                            report['stream'] = {**transcript, 'audioSeconds': round(len(message)/(4*24000), 3)}
                            break
                        event = json.loads(message)
                        if event['type'] == 'error':
                            raise RuntimeError(event['message'])
                        if event['type'] == 'transcript':
                            transcript = event
                    await feeding
                    await socket.send('stop')
                finally:
                    feeding.cancel()
        finally:
            stopped = await client.post('/api/audio/stop', json={'clientId': owner})
            stopped.raise_for_status()
            report['after'] = (await client.get('/api/audio/status')).json()
            (out/'report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
        if report['after']['running']:
            raise RuntimeError('Owned worker did not stop')
    print(json.dumps({'report': str(out/'report.json'), 'workerStopped': True}, ensure_ascii=False))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--wav', required=True)
    parser.add_argument('--report-dir', required=True)
    parser.add_argument('--base', default='http://127.0.0.1:47831')
    asyncio.run(run(parser.parse_args()))
