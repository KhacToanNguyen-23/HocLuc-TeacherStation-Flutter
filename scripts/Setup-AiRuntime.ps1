[CmdletBinding()]
param([string]$PythonPath='python', [switch]$SkipTorch, [ValidateSet('cpu','cuda')][string]$TorchDevice='cpu')
$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$taskRuntime=Join-Path $taskRoot 'backend\ai-runtime'
$taskPython=Join-Path $taskRuntime '.venv\Scripts\python.exe'
if (!(Test-Path -LiteralPath $taskPython)) {
    & $PythonPath -m venv (Join-Path $taskRuntime '.venv')
    if ($LASTEXITCODE) { throw 'Không tạo được Python venv.' }
}
$env:PIP_CACHE_DIR=Join-Path $taskRoot '.run\ai-pip-cache'
$env:HF_HOME=Join-Path $taskRoot '.run\ai-hf-cache'
if (!$SkipTorch) {
    $taskIndex=if ($TorchDevice -eq 'cuda') {'https://download.pytorch.org/whl/cu128'} else {'https://download.pytorch.org/whl/cpu'}
    $taskTorch=if ($TorchDevice -eq 'cuda') {'torch==2.8.0+cu128'} else {'torch==2.8.0+cpu'}
    & $taskPython -m pip install --upgrade $taskTorch --index-url $taskIndex
    if ($LASTEXITCODE) { throw 'Không cài được Torch baseline.' }
}
$taskRequirements=Join-Path $taskRuntime 'requirements.resolved.txt'
if (!(Test-Path -LiteralPath $taskRequirements)) {$taskRequirements=Join-Path $taskRuntime 'requirements.lock'}
& $taskPython -m pip install -r $taskRequirements
if ($LASTEXITCODE) { throw 'Không cài được dependency runtime.' }
& $taskPython (Join-Path $taskRuntime 'scripts\preflight.py')
if ($LASTEXITCODE) { throw 'Thiếu model/voice local.' }
Write-Host 'AI runtime đã cài. Mở Soạn bài để chọn nguồn, dịch hoặc tạo giọng tiếng Anh; vào giảng dạy không tự nạp model.'
