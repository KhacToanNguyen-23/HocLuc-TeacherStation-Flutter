# NovelKeys Cream samples from kbsim

- Project: https://github.com/tplai/kbsim
- Author/copyright: Thomas Lai
- Revision: ba103f3b0afa9dab80447aa2e7e2ed80b6bd80e4
- Source directory: src/assets/audio/cream/press/
- Bundled files: GENERIC_R1.mp3, GENERIC_R2.mp3, GENERIC_R3.mp3
- License: MIT, full original notice retained in LICENSE.md beside these files.

The approved v6 clip preserves the recording's tone and pitch, with only mono
44.1 kHz decoding, short boundary fades and gain 0.5. Three recorded keys
alternate in the audition sequence; the app uses the R2 single key for input.
The user approved this sound and requested quieter playback: both key clicks
and the single audition apply an additional gain of 0.6 (roughly -4.4 dB).
No synthesized tones, pitch shifts, filtering or normalization are added.

Regenerate offline using `python scripts/prepare-cream-sounds.py` with FFmpeg.
Only `nk-cream-quiet-v6.wav` and `nk-cream-click-quiet-v6.wav` are generated.
All previous audition variants have been removed from the app's public assets.
