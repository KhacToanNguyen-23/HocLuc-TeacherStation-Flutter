import argparse
import json
import sys
import time
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from models import Pipeline, preflight
import numpy as np
import soundfile as sf
from scipy.signal import resample_poly
from math import gcd
parser = argparse.ArgumentParser()
parser.add_argument('--wav')
parser.add_argument('--text', default='Hôm nay chúng ta học về lực hấp dẫn. Khối lượng của vật là hai ki lô gam.')
parser.add_argument('--output', required=True)
parser.add_argument('--repeat', type=int, default=1)
args = parser.parse_args()
start = time.perf_counter()
pipeline = Pipeline()
pipeline.load()
load_ms = round((time.perf_counter()-start)*1000)
if args.wav:
    audio, rate = sf.read(args.wav, dtype='float32', always_2d=True)
    audio = audio.mean(axis=1)
    divisor = gcd(rate, 16000)
    audio = resample_poly(audio, 16000//divisor, rate//divisor).astype(np.float32)
    vi, en, samples, metrics = pipeline.segment(audio)
else:
    vi = args.text
    start = time.perf_counter()
    en = pipeline.translate(vi)
    mt_ms = round((time.perf_counter()-start)*1000)
    start = time.perf_counter()
    samples = pipeline.speak(en)
    metrics = {'translationMs': mt_ms, 'ttsMs': round((time.perf_counter()-start)*1000)}
out = Path(args.output)
out.mkdir(parents=True, exist_ok=True)
sf.write(out/'english.wav', samples, 24000)
report = {'assets': preflight(), 'modelLoadMs': load_ms, 'source': vi, 'translation': en,
          'metrics': metrics, 'audioSeconds': len(samples)/24000, 'asrSpeechTested': bool(args.wav)}
report['actualDevices'] = pipeline.execution()
if args.repeat > 1:
    report['warmRuns'] = []
    for _ in range(min(args.repeat-1, 5)):
        start = time.perf_counter()
        again = pipeline.translate(vi)
        mt_ms = round((time.perf_counter()-start)*1000)
        start = time.perf_counter()
        sound = pipeline.speak(again)
        report['warmRuns'].append({'translationMs':mt_ms,'ttsMs':round((time.perf_counter()-start)*1000),'audioSeconds':len(sound)/24000,'sameTranslation':again==en})
(out/'report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(report, ensure_ascii=True, indent=2))
