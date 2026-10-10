[CmdletBinding()]
param(
    [ValidateSet('Preview','Windows','Service','Status','Stop')][string]$Mode = 'Preview',
    [string]$FlutterPath,
    [switch]$SkipBuild
)
$ErrorActionPreference = 'Stop'
$taskRoot = $PSScriptRoot
$taskRun = Join-Path $taskRoot '.run'
$taskPidFile = Join-Path $taskRun 'service.pid'
$taskJar = Join-Path $taskRoot 'backend\service\target\companion-service-0.1.0.jar'
$taskUrl = 'http://127.0.0.1:47831'

function Get-CompanionProcess {
    if (Test-Path -LiteralPath $taskPidFile) {
        $taskSavedPid = [int](Get-Content -LiteralPath $taskPidFile -Raw)
        $taskProcess = Get-CimInstance Win32_Process -Filter "ProcessId=$taskSavedPid" -ErrorAction SilentlyContinue
        if ($taskProcess -and $taskProcess.Name -eq 'java.exe' -and $taskProcess.CommandLine.Contains($taskJar)) { return $taskProcess }
    }
    return $null
}
if ($Mode -eq 'Stop') {
    $taskProcess = Get-CompanionProcess
    if ($taskProcess) { Stop-Process -Id $taskProcess.ProcessId; Write-Host 'Đã dừng Java service của khung app.' }
    else { Write-Host 'Không có Java service thuộc launcher này đang chạy.' }
    if (Test-Path -LiteralPath $taskPidFile) { Remove-Item -LiteralPath $taskPidFile }
    exit 0
}
if ($Mode -eq 'Status') {
    $taskProcess = Get-CompanionProcess
    if ($taskProcess) { Write-Host "Java đang chạy (PID $($taskProcess.ProcessId)). $taskUrl" }
    else { Write-Host 'Java service chưa chạy.' }
    Write-Host "Logs: $taskRun"; exit 0
}

function Invoke-Checked([scriptblock]$Operation) {
    & $Operation
    if ($LASTEXITCODE -ne 0) { throw "Lệnh build thất bại (exit $LASTEXITCODE)." }
}
if ($Mode -eq 'Windows' -or ($Mode -eq 'Preview' -and !$SkipBuild)) {
    if (!$FlutterPath) {
        $taskCommand = Get-Command flutter -ErrorAction SilentlyContinue
        if ($taskCommand) { $FlutterPath = $taskCommand.Source }
        else { throw 'Cần Flutter SDK. Truyền -FlutterPath C:\duong-dan\flutter\bin\flutter.bat' }
    }
}
if (!$SkipBuild) {
    Invoke-Checked { mvn -q -f (Join-Path $taskRoot 'backend\service\pom.xml') package }
    Push-Location (Join-Path $taskRoot 'backend\whiteboard-host')
    try {
        Invoke-Checked { npm ci --no-audit --no-fund }
        Invoke-Checked { npm run build }
    } finally { Pop-Location }
    if ($Mode -eq 'Preview') {
        Push-Location (Join-Path $taskRoot 'frontend')
        try {
            # Pub resolves before Windows plugin symlink creation. This preview can
            # use a freshly resolved lock/package config even if that last native step fails.
            & $FlutterPath pub get
            if ($LASTEXITCODE -ne 0) {
                if (!(Test-Path -LiteralPath '.dart_tool\package_config.json')) { throw 'Flutter dependencies chưa được resolve.' }
                Write-Host 'Pub get chưa hoàn tất bước native. Thử build web bằng package config đã resolve; lỗi build sẽ dừng launcher.'
            }
            Invoke-Checked { & $FlutterPath build web --no-pub --no-wasm-dry-run }
        } finally { Pop-Location }
    }
}
if (!(Test-Path -LiteralPath $taskJar)) { throw 'Chưa có Java jar; chạy lại không dùng -SkipBuild.' }
if ($Mode -eq 'Preview' -and !(Test-Path -LiteralPath (Join-Path $taskRoot 'frontend\build\web\index.html'))) { throw 'Chưa có Flutter web build.' }

New-Item -ItemType Directory -Force -Path $taskRun | Out-Null
$taskProcess = Get-CompanionProcess
if (!$taskProcess) {
    try {
        $taskExisting = Invoke-RestMethod "$taskUrl/api/bootstrap" -TimeoutSec 1
        throw 'Cổng 47831 đang được dùng bởi tiến trình ngoài launcher. Kiểm tra tiến trình trước khi chạy.'
    } catch {
        if ($_.Exception.Message -like 'Cổng 47831*') { throw }
    }
    $taskJava = (Get-Command java).Source
    $taskArgs = @('-jar', ('"' + $taskJar + '"'), ('"' + $taskRoot + '"'), '47831')
    $taskStarted = Start-Process -FilePath $taskJava -ArgumentList $taskArgs -WindowStyle Hidden -PassThru -WorkingDirectory $taskRoot -RedirectStandardOutput (Join-Path $taskRun 'service.log') -RedirectStandardError (Join-Path $taskRun 'service-error.log')
    $taskStarted.Id | Set-Content -LiteralPath $taskPidFile
    $taskReady = $false
    for ($taskAttempt = 0; $taskAttempt -lt 40; $taskAttempt++) {
        if ($taskStarted.HasExited) { throw "Java service đã thoát. Xem $taskRun\service-error.log" }
        try { $null = Invoke-RestMethod "$taskUrl/api/bootstrap" -TimeoutSec 1; $taskReady = $true; break } catch { Start-Sleep -Milliseconds 150 }
    }
    if (!$taskReady) { throw "Java chưa sẵn sàng. Xem logs tại $taskRun" }
}
Write-Host "Java service / preview: $taskUrl"
Write-Host "Dữ liệu: $taskRoot\backend\service\data. Logs: $taskRun"
Write-Host 'Dừng: .\Start.ps1 -Mode Stop. Trạng thái: .\Start.ps1 -Mode Status'
if ($Mode -eq 'Windows') {
    Push-Location (Join-Path $taskRoot 'frontend')
    try { Invoke-Checked { & $FlutterPath run -d windows } } finally { Pop-Location }
}
