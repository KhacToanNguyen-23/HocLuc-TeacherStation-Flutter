# Lesson preparation worker

This process runs one owned job, separately from the live Meet streaming server.
The backend must authenticate the teacher, resolve source/image/audio IDs to owned
local files, create a per-job workspace, serialize heavy jobs and terminate the
whole process tree on cancellation. It must not forward arbitrary browser paths.

Use the isolated Python environment with `requirements.lock`. Pillow and
imageio-ffmpeg provide local slide rendering and a bundled FFmpeg executable.
No checkpoint is downloaded automatically. Missing packages, checkpoints,
tokenizers or voices produce explicit failures. AI lesson authoring is a backend
third-party API responsibility; this process never calls a content-generation provider.

## CLI contract (backend invokes these; teacher uses app controls)

`python preparation_worker.py --capabilities` prints JSON without loading torch or
speech models. It reports packages, FFmpeg and model-folder presence. Authoring
reports `provider: managed-by-backend`, `ready: false`; the backend supplies the
actual API configuration status. No Ollama discovery or network request occurs.
Folder presence is not checksum verification or inference readiness.

`python preparation_worker.py --configure settings.json` accepts `modelRoot`,
`ffmpegPath` only, persists to ignored `config/preparation.local.json`, and prints
capabilities. Authoring settings and API credentials are rejected by this CLI.
Legacy saved Ollama settings are ignored and are never returned in capabilities.
The worker does not enable cloud access; the authenticated backend owns API calls.
Existing `HOC_LUC_AI_CONFIG` and `HOC_LUC_AI_MODELS` remain supported by speech
configuration. The launching backend selects the Python executable.

`python preparation_worker.py --request request.json --output result.json`
atomically writes a result; exit 0 means success, nonzero writes
`{"error": "...", "artifacts": []}`. A `progress.json` sidecar in workspace has
`stage`, `ratio` and elapsed seconds. Input text is bounded; scenes use an
allowlist, model responses cannot select local files or executable templates.

Request common fields: `kind`, `workspace`. Kinds:

- `transcribe`: `sourcePath`, optional `start`/`end` seconds and `language: vi`.
  FFmpeg creates mono 16k WAV on disk, inference reads 20-second chunks. Segment
  timestamps are source chunk ranges, not word-level alignment. A transcript
  checkpoint is written after each chunk. Current media extraction cap is two
  hours (longer sources are rejected, not silently truncated). A retry in the same
  workspace resumes after the last completed chunk only when source metadata,
  range and runtime configuration match the checkpoint fingerprint.
- `author`: `text`, `language` and optional `inputMode: script`. Script mode only
  maps paragraphs to editable sections/scenes, labeled `manual-script`. Prompt
  mode is rejected explicitly: AI authoring is handled by the backend API, with
  no local model fallback. Manual-script drafts have `reviewRequired: true`.
  No generated text is asserted correct or automatically approved.
- `translate`: Vietnamese `text`; returns English using the local VinAI adapter.
  Splits by tokenizer budget instead of silently truncating a long lesson.
- `speech`: English `text`, optional `voice` (default `af_heart`); returns local
  Kokoro WAV. Vietnamese synthesis is rejected explicitly.
- `render`: `scenes` with safe unique `id`, `title`, `text`, `narration`, `language`
  (`en`/`vi`), `template` (`slide`/`diagram`/`highlight`/`image`), optional uploaded
  `imagePath`, and optional already prepared `audioPath`. The backend must validate
  all asset ownership. Without audioPath, Vietnamese narration is translated and
  real English TTS generated; source-language slide text can remain Vietnamese.
  Diagram text has 2–5 newline/arrow-separated nodes. Overfull text is rejected.

Render returns 1280×720 25fps H.264/AAC MP4, SRT, thumbnail and timeline metadata.
The template uses actual fade/slow zoom animation. Audio determines frame-rounded
scene duration and is padded rather than cut. SRT cues are estimated from the
final narration, **not forced-aligned**; the teacher must review them. Maximum
80 scenes, 15 minutes per audio scene, 30 minutes total. No character generation,
voice cloning, recognition of images/formulas or automatic recording is implied.

Output artifacts have `path`, `name`, `kind`, `mimeType`, all inside workspace.
There is no teacher-note field in student render projection. The backend's
revision/approval gate and teacher preview still determine publish eligibility;
arbitrary externally uploaded files cannot be guaranteed free of private content.

## Verification

`python -m pytest tests/test_preparation.py` covers schema/error/path boundaries,
no eager torch load during capabilities and real three-scene FFmpeg MP4 decoding
with synthetic audio. That fixture does not prove model speech/STT/translation
quality. Real inference and long-media hardware benchmarks are separate gates.

## Speech-model distribution

STT (PhoWhisper), translation (VinAI) and TTS (Kokoro) stay local and unchanged.
Their checkpoints are obtained separately from repository release/model artifacts
or the existing verified offline installer, then configured through `modelRoot`.
Cloning application source alone does not install checkpoints. The worker does
not download weights automatically, and the authoring migration does not add
weights to Git or change model-installation verification.
