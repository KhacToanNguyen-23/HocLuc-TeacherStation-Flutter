# Offline components for Soạn bài

An operator supplies a reviewed ZIP; the teacher uses **Soạn bài → Cài đặt → Nhập bundle offline** inside HocLuc. No command line is needed by the teacher. Installation does not download files, execute package scripts, run pip, or start a model. Capability checks remain separate.

SHA256 checks prove that extracted bytes match the supplied manifest. **They do not authenticate the publisher or make an untrusted Python executable safe.** This release has no signed publisher catalog. Only install packages from the deployment operator you trust. Installed metadata explicitly reports `publisherTrustVerified: false`.

## Operator packaging

Use an existing, reviewed, relocatable Python distribution with all required dependencies. A machine-bound virtualenv is rejected by the packaging script; it is not automatically converted into a portable runtime. Model paths below are examples, not bundled model weights.

```powershell
powershell -ExecutionPolicy Bypass -File scripts/Package-PreparationComponents.ps1 `
  -Version '2026.10.20-models' -OutputZip 'D:\HocLuc-Deploy\models.zip' `
  -ModelRoot 'D:\AI-Training\models'

powershell -ExecutionPolicy Bypass -File scripts/Package-PreparationComponents.ps1 `
  -Version '2026.10.20-runtime' -OutputZip 'D:\HocLuc-Deploy\runtime.zip' `
  -RuntimeDirectory 'D:\HocLuc-Deploy\reviewed-python' `
  -FfmpegExecutable 'D:\Tools\ffmpeg\bin\ffmpeg.exe'
```

The tool streams files into ZIP64-capable .NET ZIP output and hashes individual files. It refuses links/reparse points and excludes `.git`, `.cache`, `__pycache__`, `.env*`, `*.local.*`, credential/secret files and private-key extensions. These exclusions are a safeguard, not a guarantee that arbitrary folders contain no secrets; the operator must review inputs. Source code, model checkpoints and generated ZIPs are not committed by this tool. Do not include personal configuration or tokens.

## ZIP format, version 1

At ZIP root, `bundle-manifest.json` contains:

```json
{
  "schemaVersion": 1,
  "version": "2026.10.20-models",
  "components": { "modelRoot": "models" },
  "files": [
    { "path": "models/example/config.json", "size": 2,
      "sha256": "44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a" }
  ]
}
```

`components` permits only `modelRoot`, `pythonPath`, `ffmpegPath`, with relative paths inside the package. Executable names must be `python.exe` and `ffmpeg.exe`. `modelRoot` points to a directory preserving the names expected by the configured speech adapters. Each regular file, except the manifest itself, must occur exactly once in `files`, with an exact byte count and SHA256. No undeclared files, Unix symlinks, special files, absolute paths, `..`, backslash paths, Windows reserved names or case-colliding paths are accepted.

ZIP input is limited to 8 GiB, expanded files to 16 GiB, manifest to 8 MB and 100,000 file records. Extraction is streamed with a 128 KiB buffer. Files are staged under the backend data directory; every file is verified before an atomic rename and atomic configuration update. Existing installed directories and configuration survive a rejected/cancelled package. Old installed versions remain available on disk; this release does not remove them automatically. Keep at least expanded bundle size plus 512 MiB free after upload. Multipart bodies are spooled to disk, not held in application RAM.

`HOC_LUC_BUNDLE_MAX_FILE_SIZE` / `HOC_LUC_BUNDLE_MAX_REQUEST_SIZE` override server multipart limits (default 8 GB / 9 GB). The ordinary source endpoint retains its independent 50 MB check, and exam upload retains its own limit. A reverse proxy must permit the intended offline upload size and timeout.

## API

- `POST /api/preparation/components/install`, multipart `file`: returns owned installation job `{id,status,progress}`.
- `GET /api/preparation/components/installations`: array of this teacher's jobs, for resuming after closing the dialog or losing the upload response.
- `GET /api/preparation/components/installations/{id}` and `POST .../{id}/cancel`: poll or cancel that teacher's job.
- Status values: `queued`, `running`, `installed`, `failed`, `cancelled`. `progress` is a ratio from 0 to 1. Cancellation during upload aborts the client transfer; if acceptance is uncertain, inspect the owned job list before uploading again.
- `GET /api/preparation/capabilities` includes `installedComponents` version, manifest hash, relative component paths and integrity/trust flags.

All routes require the app's companion token and teacher bearer session. A different teacher cannot inspect or cancel an installation job. Components/configuration are local machine resources; an accepted install changes subsequent runtime selection for this local HocLuc instance.
