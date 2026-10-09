[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Bundle)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskBundle = (Resolve-Path -LiteralPath $Bundle).Path
$taskTestRoot = Join-Path $taskRoot ('.packaging\package-check-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force $taskTestRoot | Out-Null
$taskPortable = Join-Path $taskTestRoot 'moved portable app'
Copy-Item -LiteralPath $taskBundle -Destination $taskPortable -Recurse
$taskExe = Join-Path $taskPortable 'HocLuc-Teacher.exe'

function Start-Smoke([string]$Destination, [switch]$Hold) {
    New-Item -ItemType Directory -Force $Destination | Out-Null
    $taskArgs = @('--smoke-test', ('"' + $Destination + '"'))
    if ($Hold) { $taskArgs += '--hold-for-parent-exit-test' }
    $taskInfo = [Diagnostics.ProcessStartInfo]::new($taskExe, ($taskArgs -join ' '))
    $taskInfo.WorkingDirectory = $env:WINDIR
    $taskInfo.UseShellExecute = $false
    $taskInfo.CreateNoWindow = $true
    $taskInfo.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $taskInfo.EnvironmentVariables['PATH'] = "$env:WINDIR\System32;$env:WINDIR"
    $taskProcess = [Diagnostics.Process]::Start($taskInfo)
    return $taskProcess
}
function Wait-Report([string]$Destination, [Diagnostics.Process]$App) {
    for ($taskAttempt = 0; $taskAttempt -lt 220; $taskAttempt++) {
        $taskFailure = Join-Path $Destination 'failure.txt'
        $taskPassed = Join-Path $Destination 'passed.json'
        if (Test-Path -LiteralPath $taskFailure) { throw (Get-Content -LiteralPath $taskFailure -Raw) }
        if (Test-Path -LiteralPath $taskPassed) { return (Get-Content -LiteralPath $taskPassed -Raw | ConvertFrom-Json) }
        if ($App.HasExited) { throw "Packaged app exited without a report (exit $($App.ExitCode))" }
        Start-Sleep -Milliseconds 250
    }
    throw 'Packaged app did not render before timeout.'
}
function Assert-ServiceStopped([int]$ServiceId) {
    for ($taskAttempt = 0; $taskAttempt -lt 24; $taskAttempt++) {
        if (!(Get-Process -Id $ServiceId -ErrorAction SilentlyContinue)) { return }
        Start-Sleep -Milliseconds 250
    }
    throw "Java sidecar $ServiceId remains alive."
}
$taskCurrent = $null
try {
    $taskNormalDir = Join-Path $taskTestRoot 'normal-close'
    $taskCurrent = Start-Smoke $taskNormalDir
    $taskNormal = Wait-Report $taskNormalDir $taskCurrent
    if (!$taskCurrent.WaitForExit(10000) -or $taskCurrent.ExitCode -ne 0) { throw 'Normal app close failed.' }
    Assert-ServiceStopped $taskNormal.servicePid
    if (!$taskNormal.ready -or !$taskNormal.saveRead -or !$taskNormal.externalResourcesDenied) { throw 'Normal report incomplete.' }
    if (!(Test-Path -LiteralPath (Join-Path $taskNormalDir 'user-data\data\lesson.json'))) { throw 'Lesson not written to user data.' }
    if (Test-Path -LiteralPath (Join-Path $taskPortable 'resources\service\data')) { throw 'Runtime bundle unexpectedly contains lesson data.' }

    $taskKilledDir = Join-Path $taskTestRoot 'parent-exit'
    $taskCurrent = Start-Smoke $taskKilledDir -Hold
    $taskKilled = Wait-Report $taskKilledDir $taskCurrent
    $taskCurrent.Kill(); $taskCurrent.WaitForExit()
    Assert-ServiceStopped $taskKilled.servicePid
    [pscustomobject]@{PortablePathWithSpaces=$taskPortable; NoSystemJavaOrFlutter=$true; OfflineUi=$true; SaveRead=$true; NormalClose=$true; ForcedParentExit=$true; Screenshot=(Join-Path $taskNormalDir 'desktop-preview.png')} | Format-List
    Write-Host 'PASS: packaged exe, moved path, restricted PATH, offline Flutter UI, persistence and sidecar cleanup.'
    $taskTestRoot | Set-Content -LiteralPath (Join-Path $taskRoot '.packaging\latest-package-check.txt') -Encoding UTF8
} finally {
    if ($taskCurrent -and !$taskCurrent.HasExited) { $taskCurrent.Kill(); $taskCurrent.WaitForExit() }
}
