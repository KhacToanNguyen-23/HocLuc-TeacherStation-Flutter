param(
    [int]$Port = 47831,
    [string]$AdminEmail = 'admin@hocluc.local',
    [SecureString]$AdminPassword,
    [string]$FlutterPath,
    [switch]$SkipBuild,
    [switch]$ShowAdminCredential
)
$ErrorActionPreference = 'Stop'
$taskRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$taskApi = Join-Path $taskRoot 'backend\api'
$taskCredentialPath = Join-Path $taskRoot '.run\exam-admin.credential.xml'
if ($ShowAdminCredential) {
    if (-not (Test-Path -LiteralPath $taskCredentialPath)) { throw 'Chưa có tài khoản admin local. Chạy script không có -ShowAdminCredential trước.' }
    $taskCredential = Import-Clixml -LiteralPath $taskCredentialPath
    Write-Host ('Admin email: ' + $taskCredential.UserName)
    Write-Host ('Admin password: ' + $taskCredential.GetNetworkCredential().Password)
    return
}
if ($AdminPassword) {
    $taskCredential = [PSCredential]::new($AdminEmail, $AdminPassword)
} elseif (Test-Path -LiteralPath $taskCredentialPath) {
    $taskCredential = Import-Clixml -LiteralPath $taskCredentialPath
} else {
    $taskRandom = New-Object byte[] 24
    $taskRng = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $taskRng.GetBytes($taskRandom) } finally { $taskRng.Dispose() }
    $taskSecret = [Convert]::ToBase64String($taskRandom)
    $taskCredential = [PSCredential]::new($AdminEmail, (ConvertTo-SecureString $taskSecret -AsPlainText -Force))
}
New-Item -ItemType Directory -Path (Split-Path $taskCredentialPath) -Force | Out-Null
# Windows DPAPI encrypts the credential for the current Windows account.
$taskCredential | Export-Clixml -LiteralPath $taskCredentialPath
if (Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue) { throw "Port $Port đang được sử dụng. Chọn -Port khác." }
$taskJar = Join-Path $taskApi 'target\companion-service-0.1.0.jar'
Push-Location $taskApi
$taskOldEmail = $env:EXAM_ADMIN_EMAIL
$taskOldPassword = $env:EXAM_ADMIN_PASSWORD
try {
    if (-not $SkipBuild) {
        & mvn -q -DskipTests package
        if ($LASTEXITCODE -ne 0) { throw 'Maven build không thành công.' }
        if (-not $FlutterPath) {
            $taskFlutter = Get-Command flutter -ErrorAction SilentlyContinue
            if ($taskFlutter) { $FlutterPath = $taskFlutter.Source }
            elseif (Test-Path -LiteralPath 'D:\Tools\teaching-companion\flutter\bin\flutter.bat') {
                $FlutterPath = 'D:\Tools\teaching-companion\flutter\bin\flutter.bat'
            } else { throw 'Cần Flutter SDK. Truyền -FlutterPath đến flutter.bat.' }
        }
        Push-Location (Join-Path $taskRoot 'frontend')
        try {
            & $FlutterPath build web --no-pub --no-wasm-dry-run "--dart-define=COMPANION_SERVICE=http://127.0.0.1:$Port"
            if ($LASTEXITCODE -ne 0) { throw 'Flutter web build không thành công.' }
        } finally { Pop-Location }
    }
    if (-not (Test-Path -LiteralPath $taskJar)) { throw 'Chưa có JAR. Chạy lại không có -SkipBuild.' }
    if (-not (Test-Path -LiteralPath (Join-Path $taskRoot 'frontend\build\web\index.html'))) {
        throw 'Chưa có Flutter web build. Chạy lại không có -SkipBuild.'
    }
    $env:EXAM_ADMIN_EMAIL = $taskCredential.UserName
    $env:EXAM_ADMIN_PASSWORD = $taskCredential.GetNetworkCredential().Password
    Write-Host "App Mộc: http://127.0.0.1:$Port/"
    Write-Host 'Dùng màn hình đăng nhập hiện có; mở Đề thi & năng lực trên thanh trên cùng.'
    Write-Host ('Local admin: ' + $taskCredential.UserName)
    Write-Host 'Xem thông tin đăng nhập bằng: .\scripts\Start-ExamPlatform.ps1 -ShowAdminCredential'
    & java -jar $taskJar "--server.port=$Port"
} finally {
    $env:EXAM_ADMIN_EMAIL = $taskOldEmail
    $env:EXAM_ADMIN_PASSWORD = $taskOldPassword
    Pop-Location
}
