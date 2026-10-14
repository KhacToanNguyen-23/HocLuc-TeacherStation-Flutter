[CmdletBinding()]
param([switch]$OpenInstaller)
$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$taskFolder=Join-Path $taskRoot '.run\vb-cable'
$taskInstaller=Join-Path $taskFolder 'package\VBCABLE_Setup_x64.exe'
if (!(Test-Path -LiteralPath $taskInstaller)) {
    New-Item -ItemType Directory -Path $taskFolder -Force | Out-Null
    Invoke-WebRequest 'https://download.vb-audio.com/Download_CABLE/VBCABLE_Driver_Pack45.zip' -OutFile (Join-Path $taskFolder 'driver.zip')
    Expand-Archive -LiteralPath (Join-Path $taskFolder 'driver.zip') -DestinationPath (Join-Path $taskFolder 'package')
}
$taskSignature=Get-AuthenticodeSignature -LiteralPath $taskInstaller
if ($taskSignature.Status -ne 'Valid' -or $taskSignature.SignerCertificate.Subject -notlike '*BUREL VINCENT*') {throw 'Chữ ký bộ cài không đúng publisher.'}
Write-Host "Bộ cài đã kiểm tra chữ ký: $taskInstaller"
Write-Host 'App phát vào CABLE Input (Playback); Meet chọn CABLE Output (Recording). Nhà phát triển yêu cầu quyền Admin và khởi động lại sau cài.'
if ($OpenInstaller) {
    # This installer is interactive: the teacher must handle UAC / Install Driver.
    Start-Process -FilePath $taskInstaller -Verb RunAs
}
