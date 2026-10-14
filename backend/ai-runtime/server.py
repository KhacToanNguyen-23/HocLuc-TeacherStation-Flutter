import argparse
import asyncio
import hmac
import json
import os
import threading
import time
import secrets
from contextlib import asynccontextmanager
import numpy as np
from fastapi import FastAPI, HTTPException, Request, WebSocket, WebSocketDisconnect
import base64
import io
import uvicorn
from models import Pipeline, preflight
from streaming import Segmenter

TOKEN = os.environ.get('HOC_LUC_AI_TOKEN', '')
if len(TOKEN) < 32:
    TOKEN = secrets.token_urlsafe(32)
pipeline = Pipeline()
model_lock = threading.Lock()
active_lock = asyncio.Lock()
last_activity = time.monotonic()

def ensure_models():
    with model_lock:
        pipeline.load()

def process_segment(audio, voice):
    with model_lock:
        return pipeline.segment(audio, voice)

@asynccontextmanager
async def lifespan(app):
    async def parent_watch():
        import ctypes
        parent = int(os.environ.get('HOC_LUC_AI_PARENT_PID', '0'))
        if not parent or os.name != 'nt':
            return
        kernel = ctypes.WinDLL('kernel32', use_last_error=True)
        kernel.OpenProcess.restype = ctypes.c_void_p
        handle = kernel.OpenProcess(0x100000, False, parent)
        if not handle:
            os._exit(0)
        kernel.WaitForSingleObject.argtypes = [ctypes.c_void_p, ctypes.c_ulong]
        while kernel.WaitForSingleObject(handle, 0) == 258:
            await asyncio.sleep(1)
        os._exit(0)
    watch = asyncio.create_task(parent_watch())
    async def idle_exit():
        while True:
            await asyncio.sleep(5)
            if not active_lock.locked() and time.monotonic()-last_activity > 120:
                os._exit(0)
    idle = asyncio.create_task(idle_exit())
    yield
    watch.cancel()
    idle.cancel()

app = FastAPI(lifespan=lifespan)

def authorize(token, host):
    if host not in ('127.0.0.1', '::1', 'testclient') or not token or not hmac.compare_digest(token, TOKEN):
        raise HTTPException(403, 'Local runtime session required')

@app.get('/health')
def health(request: Request):
    authorize(request.headers.get('X-AI-Token', ''), request.client.host)
    return {**preflight(), 'ready': True, 'modelsLoaded': pipeline.loaded, 'supportedLanguages': ['en'],
            'execution': pipeline.execution()}

@app.websocket('/stream')
async def stream(socket: WebSocket):
    global last_activity
    last_activity = time.monotonic()
    try:
        authorize(socket.query_params.get('token', ''), socket.client.host)
    except HTTPException:
        await socket.close(code=1008)
        return
    origin = socket.headers.get('origin')
    if origin:
        from urllib.parse import urlparse
        if urlparse(origin).hostname not in ('127.0.0.1', 'localhost', '::1'):
            await socket.close(code=1008)
            return
    await socket.accept()
    if active_lock.locked():
        await socket.send_json({'type': 'error', 'message': 'Một phiên dịch khác đang dùng runtime.'})
        await socket.close(code=1013)
        return
    async with active_lock:
        queue = asyncio.Queue(maxsize=3)
        closed = asyncio.Event()
        send_lock = asyncio.Lock()
        voice = socket.query_params.get('voice', 'af_heart')
        async def send(data):
            async with send_lock:
                if not closed.is_set():
                    if isinstance(data, bytes):
                        await socket.send_bytes(data)
                    else:
                        await socket.send_json(data)
        async def consume():
            index = 0
            while not closed.is_set():
                audio, finished = await queue.get()
                if time.monotonic()-finished > 8:
                    raise RuntimeError('Dịch không theo kịp lời giảng. Đã quay về giọng gốc.')
                result = await asyncio.to_thread(process_segment, audio, voice)
                if closed.is_set():
                    return
                vi, en, samples, metrics = result
                index += 1
                if len(samples) > 8*24000:
                    raise RuntimeError('Bản dịch quá dài để phát trực tiếp. Đã quay về giọng gốc.')
                await send({'type': 'transcript', 'segmentId': index, 'vi': vi, 'en': en, 'metrics': metrics,
                            'sampleRate': 24000, 'endToFirstAudioMs': round((time.monotonic()-finished)*1000)})
                if len(samples):
                    await send(samples.astype('<f4').tobytes())
        worker = None
        receive = None
        try:
            await send({'type': 'preparing'})
            await asyncio.to_thread(ensure_models)
            if voice not in preflight()['voices']:
                raise ValueError('Giọng English không hợp lệ.')
            await send({'type': 'ready'})
            worker = asyncio.create_task(consume())
            segmenter = Segmenter()
            while True:
                receive = asyncio.create_task(socket.receive())
                done, _ = await asyncio.wait([receive, worker], return_when=asyncio.FIRST_COMPLETED)
                if worker in done:
                    worker.result()
                message = receive.result()
                if message['type'] == 'websocket.disconnect':
                    break
                if message.get('bytes') is not None:
                    data = message['bytes']
                    if len(data) % 4 or len(data) > 64000:
                        raise ValueError('Kích thước frame PCM không hợp lệ.')
                    audio = segmenter.push(np.frombuffer(data, dtype='<f4'))
                    if audio is not None:
                        queue.put_nowait((audio, time.monotonic()))
                elif message.get('text') == 'stop':
                    break
                else:
                    raise ValueError('Chỉ chấp nhận PCM float32 mono 16 kHz.')
        except WebSocketDisconnect:
            pass
        except Exception as error:
            try:
                reason = 'Hàng đợi dịch đã đầy. Đã quay về giọng gốc.' if isinstance(error, asyncio.QueueFull) else str(error)
                await send({'type': 'error', 'message': reason[:500]})
            except Exception:
                pass

        finally:
            last_activity = time.monotonic()
            closed.set()
            for task in (worker, receive):
                if task:
                    task.cancel()
            try:
                await socket.close()
            except Exception:
                pass

@app.post('/file')
async def file_preview(request: Request):
    global last_activity
    last_activity = time.monotonic()
    authorize(request.headers.get('X-AI-Token', ''), request.client.host)
    data = await request.body()
    if len(data) > 4_000_000:
        raise HTTPException(400, 'WAV tối đa 4 MB và 15 giây.')
    import soundfile as sf
    from scipy.signal import resample_poly
    from math import gcd
    try:
        with sf.SoundFile(io.BytesIO(data)) as source:
            rate = source.samplerate
            if source.format not in ('WAV', 'WAVEX') or not 8000 <= rate <= 48000 or source.channels > 2 or len(source) > 15*rate:
                raise ValueError('WAV cần mono/stereo, 8–48 kHz, tối đa 15 giây.')
            audio = source.read(frames=15*rate+1, dtype='float32', always_2d=True).mean(axis=1)
        factor = gcd(rate, 16000)
        audio = resample_poly(audio, 16000//factor, rate//factor).astype(np.float32)
    except Exception as error:
        raise HTTPException(400, str(error)) from error
    voice = request.query_params.get('voice', 'af_heart')
    if active_lock.locked():
        raise HTTPException(409, 'Dừng phiên dịch trực tiếp trước khi nghe thử WAV.')
    async with active_lock:
        try:
            await asyncio.to_thread(ensure_models)
            vi, en, samples, metrics = await asyncio.to_thread(process_segment, audio, voice)
            if len(samples) > 30*24000:
                raise ValueError('Bản dịch WAV dài quá 30 giây.')
            return {'vi':vi,'en':en,'metrics':metrics,'sampleRate':24000,
                    'samples':base64.b64encode(samples.astype('<f4').tobytes()).decode('ascii')}
        except Exception as error:
            raise HTTPException(503, str(error)[:500]) from error
        finally:
            last_activity = time.monotonic()

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int, default=47832)
    args = parser.parse_args()
    uvicorn.run(app, host='127.0.0.1', port=args.port, access_log=False, log_level='warning')
