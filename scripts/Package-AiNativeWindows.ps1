[CmdletBinding()]
param([string]$FlutterPath, [switch]$SkipBuild, [string]$OutputDirectory)
$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$taskRuntime=Join-Path $taskRoot 'backend\ai-runtime'
$taskPython=Join-Path $taskRuntime '.venv\Scripts\python.exe'
if (!(Test-Path -LiteralPath $taskPython)) {throw 'Chạy Setup-AiRuntime.ps1 trước.'}
if (!$SkipBuild) {
    if (!$FlutterPath) {$FlutterPath=(Get-Command flutter -ErrorAction Stop).Source}
    Push-Location (Join-Path $taskRoot 'frontend')
    try {& $FlutterPath build windows; if($LASTEXITCODE){throw 'Flutter build thất bại.'}} finally {Pop-Location}
    Push-Location (Join-Path $taskRoot 'backend\api')
    try {& mvn -q -DskipTests package; if($LASTEXITCODE){throw 'Maven package thất bại.'}} finally {Pop-Location}
}
$taskOutput=if ($OutputDirectory) {[IO.Path]::GetFullPath($OutputDirectory)} else {Join-Path $taskRoot ('dist\HocLuc-AI-Native-Windows-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))}
New-Item -ItemType Directory -Path $taskOutput -Force | Out-Null
& robocopy (Join-Path $taskRoot 'frontend\build\windows\x64\runner\Release') (Join-Path $taskOutput 'frontend') /E /R:1 /W:1 /NFL /NDL /NJH /NJS /NP
if ($LASTEXITCODE -ge 8) {throw 'Không sao chép được Flutter native.'}
New-Item -ItemType Directory -Path (Join-Path $taskOutput 'backend\api\target') -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $taskRoot 'backend\api\target\companion-service-0.1.0.jar') -Destination (Join-Path $taskOutput 'backend\api\target')
$taskEngine=Join-Path $taskOutput 'backend\ai-runtime'
New-Item -ItemType Directory -Path $taskEngine -Force | Out-Null
foreach($taskName in @('server.py','models.py','streaming.py','requirements.lock','requirements.resolved.txt','scripts')) {
    Copy-Item -LiteralPath (Join-Path $taskRuntime $taskName) -Destination $taskEngine -Recurse -Force
}
Get-ChildItem -LiteralPath $taskRuntime -Filter 'preparation_*.py' -File | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $taskEngine -Force
}
$taskConfigOutput=Join-Path $taskEngine 'config'
New-Item -ItemType Directory -Path $taskConfigOutput -Force | Out-Null
Get-ChildItem -LiteralPath (Join-Path $taskRuntime 'config') -Filter '*.example.json' -File | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $taskConfigOutput -Force
}
if (Test-Path -LiteralPath (Join-Path $taskRuntime 'PREPARATION.md')) {
    Copy-Item -LiteralPath (Join-Path $taskRuntime 'PREPARATION.md') -Destination $taskEngine -Force
}
$taskEmbedded=Join-Path $taskRoot '.run\python-3.12.10-embed-amd64.zip'
if (!(Test-Path -LiteralPath $taskEmbedded)) {Invoke-WebRequest 'https://www.python.org/ftp/python/3.12.10/python-3.12.10-embed-amd64.zip' -OutFile $taskEmbedded}
$taskPortable=Join-Path $taskEngine 'python'
Expand-Archive -LiteralPath $taskEmbedded -DestinationPath $taskPortable -Force
New-Item -ItemType Directory -Path (Join-Path $taskPortable 'Lib') -Force | Out-Null
& robocopy (Join-Path $taskRuntime '.venv\Lib\site-packages') (Join-Path $taskPortable 'Lib\site-packages') /E /MT:8 /R:1 /W:1 /NFL /NDL /NJH /NJS /NP /XD __pycache__ .pytest_cache
if ($LASTEXITCODE -ge 8) {throw 'Không sao chép được dependency Python.'}
@('python312.zip','.','..','Lib\site-packages','import site') | Set-Content -LiteralPath (Join-Path $taskPortable 'python312._pth') -Encoding ascii
if (!(Test-Path -LiteralPath (Join-Path $taskOutput 'java\bin\java.exe'))) {
    & jlink --add-modules java.se,jdk.unsupported,jdk.crypto.ec --output (Join-Path $taskOutput 'java')
    if ($LASTEXITCODE) {throw 'Không đóng gói được Java runtime.'}
}
& (Join-Path $PSScriptRoot 'Export-AiManifest.ps1') -OutputPath (Join-Path $taskOutput 'ai-model-manifest.json')
New-Item -ItemType Directory -Path (Join-Path $taskOutput 'docs') -Force | Out-Null
foreach ($taskDoc in @('ai-speech-setup.md','ai-speech-acceptance.md')) {
    Copy-Item -LiteralPath (Join-Path $taskRoot ('docs\'+$taskDoc)) -Destination (Join-Path $taskOutput 'docs') -Force
}
@'
$ErrorActionPreference='Stop'
$taskRoot=$PSScriptRoot
$env:HOC_LUC_AI_PYTHON=Join-Path $taskRoot 'backend\ai-runtime\python\python.exe'
if (Get-NetTCPConnection -LocalPort 47831 -State Listen -ErrorAction SilentlyContinue) {throw 'Cổng 47831 đang được dùng. Dừng backend hiện tại trước khi chạy gói này.'}
$env:HOC_LUC_PARENT_PID=$PID
$taskBackend=Start-Process -FilePath (Join-Path $taskRoot 'java\bin\java.exe') -ArgumentList @('-jar',('"'+(Join-Path $taskRoot 'backend\api\target\companion-service-0.1.0.jar')+'"')) -WorkingDirectory (Join-Path $taskRoot 'backend\api') -WindowStyle Hidden -PassThru
try {
    $taskReady=$false
    for($taskAttempt=0;$taskAttempt -lt 45;$taskAttempt++) {
        if ($taskBackend.HasExited) {throw 'Backend đã dừng trước khi sẵn sàng.'}
        try {$null=Invoke-RestMethod 'http://127.0.0.1:47831/api/bootstrap';$taskReady=$true;break} catch {Start-Sleep -Milliseconds 500}
    }
    if (!$taskReady) {throw 'Backend chưa sẵn sàng sau 22 giây.'}
    $taskClient=Start-Process -FilePath (Join-Path $taskRoot 'frontend\teaching_companion.exe') -PassThru
    $taskClient.WaitForExit()
} finally {if (!$taskBackend.HasExited) {Stop-Process -Id $taskBackend.Id}}
'@ | Set-Content -LiteralPath (Join-Path $taskOutput 'Start.ps1') -Encoding utf8
@'
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start.ps1"
'@ | Set-Content -LiteralPath (Join-Path $taskOutput 'RUN.bat') -Encoding ascii
Write-Host "Gói native: $taskOutput"
Write-Host 'Models nằm ngoài gói; cấu hình HOC_LUC_AI_MODELS hoặc backend/ai-runtime/config/models.local.json. Driver audio ảo được cài riêng.'
