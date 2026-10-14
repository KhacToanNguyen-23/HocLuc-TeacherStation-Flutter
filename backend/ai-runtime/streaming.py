"""Bounded VAD, generation cancellation and ordered speech work."""
import numpy as np

class Segmenter:
    rate = 16000
    def __init__(self):
        self.parts = []
        self.samples = 0
        self.quiet = 0
        self.speech = 0

    def push(self, frame):
        if frame.ndim != 1 or not np.isfinite(frame).all() or len(frame) > 16000:
            raise ValueError('PCM không hợp lệ.')
        loud = float(np.sqrt(np.mean(frame*frame))) >= 0.012 if len(frame) else False
        if not loud and not self.parts:
            return None
        self.parts.append(frame.copy())
        self.samples += len(frame)
        self.speech += len(frame) if loud else 0
        self.quiet = 0 if loud else self.quiet + len(frame)
        if self.samples >= 6*self.rate or self.quiet >= int(0.55*self.rate):
            result = np.concatenate(self.parts) if self.speech >= int(.25*self.rate) else None
            self.parts, self.samples, self.speech, self.quiet = [], 0, 0, 0
            return result
        return None
