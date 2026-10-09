[CmdletBinding()]
param([string]$FlutterPath, [switch]$SkipFrontendBuild, [switch]$CreateZip)
$ErrorActionPreference = 'Stop'
$taskRoot = $PSScriptRoot
$taskCache = Join-Path $taskRoot '.packaging\cache'
$taskSdk = Join-Path $taskCache 'webview2-sdk'
$taskVersion = '154.0.4258.62'
$taskSdkVersion = '1.0.4258.31'
$taskOutput = Join-Path $taskRoot ('dist\HocLuc-Teacher-Windows-x64-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
foreach ($taskTool in @('mvn', 'jlink', 'curl.exe')) {
    if (!(Get-Command $taskTool -ErrorAction SilentlyContinue)) { throw "Required build tool not found in PATH: $taskTool" }
}
if (!$SkipFrontendBuild) {
    if (!(Get-Command npm -ErrorAction SilentlyContinue)) { throw 'Install Node.js/npm and add them to PATH.' }
    if (!$FlutterPath) {
        $taskFlutter = Get-Command flutter -ErrorAction SilentlyContinue
        if ($taskFlutter) { $FlutterPath = $taskFlutter.Source }
        else { throw 'Add Flutter to PATH or pass -FlutterPath C:\path\flutter\bin\flutter.bat.' }
    }
    if (!(Test-Path -LiteralPath $FlutterPath)) { throw "Flutter executable not found: $FlutterPath" }
}
New-Item -ItemType Directory -Force $taskCache | Out-Null
function Invoke-Checked([scriptblock]$Operation) { & $Operation; if ($LASTEXITCODE -ne 0) { throw "Build failed: exit $LASTEXITCODE" } }
function Download-File([string]$Url, [string]$Path) {
    Invoke-Checked { & curl.exe -L --fail --silent --show-error --max-time 300 $Url --output $Path }
}
if (!(Test-Path -LiteralPath (Join-Path $taskSdk 'lib\net462\Microsoft.Web.WebView2.Core.dll'))) {
    $taskSdkZip = Join-Path $taskCache 'webview2-sdk.zip'
    Download-File "https://api.nuget.org/v3-flatcontainer/microsoft.web.webview2/$taskSdkVersion/microsoft.web.webview2.$taskSdkVersion.nupkg" $taskSdkZip
    Expand-Archive -LiteralPath $taskSdkZip -DestinationPath $taskSdk -Force
}
$taskExtracted = Join-Path $taskCache 'webview2-runtime-extracted'
$taskBrowser = Join-Path $taskExtracted "Microsoft.WebView2.FixedVersionRuntime.$taskVersion.x64"
if (!(Test-Path -LiteralPath (Join-Path $taskBrowser 'msedgewebview2.exe'))) {
    $taskMetadata = Invoke-RestMethod 'https://developer.microsoft.com/microsoft-edge/api/webview2'
    $taskRuntimeUrl = (($taskMetadata | Where-Object version -eq $taskVersion).builds | Where-Object architecture -eq 'x64').url
    if (!$taskRuntimeUrl) { throw "Microsoft no longer lists fixed runtime $taskVersion; choose and verify a new pinned version." }
    $taskCab = Join-Path $taskCache 'webview2-runtime.cab'
    if (!(Test-Path -LiteralPath $taskCab)) { Download-File $taskRuntimeUrl $taskCab }
    New-Item -ItemType Directory -Force $taskExtracted | Out-Null
    Invoke-Checked { & expand.exe $taskCab '-F:*' $taskExtracted > (Join-Path $taskCache 'extract.log') }
}
if (!(Test-Path -LiteralPath (Join-Path $taskBrowser 'msedgewebview2.exe'))) { throw 'Fixed WebView2 runtime is missing after extraction.' }
Invoke-Checked { mvn -q -f (Join-Path $taskRoot 'service\pom.xml') package }
if (!$SkipFrontendBuild) {
    Push-Location (Join-Path $taskRoot 'whiteboard-host')
    try { Invoke-Checked { npm ci --no-audit --no-fund }; Invoke-Checked { npm run build } }
    finally { Pop-Location }
    Push-Location (Join-Path $taskRoot 'app')
    try {
        & $FlutterPath pub get
        if ($LASTEXITCODE -ne 0 -and !(Test-Path -LiteralPath '.dart_tool\package_config.json')) { throw 'Flutter package resolution failed.' }
        Invoke-Checked { & $FlutterPath build web --no-pub --no-web-resources-cdn --no-wasm-dry-run }
    } finally { Pop-Location }
}
if (!(Test-Path -LiteralPath (Join-Path $taskRoot 'app\build\web\canvaskit\canvaskit.wasm'))) { throw 'Build the offline Flutter web bundle first.' }
New-Item -ItemType Directory -Force $taskOutput | Out-Null
$taskResources = Join-Path $taskOutput 'resources'
New-Item -ItemType Directory -Force (Join-Path $taskResources 'app\build'), (Join-Path $taskResources 'whiteboard-host'), (Join-Path $taskResources 'service') | Out-Null
Copy-Item -LiteralPath (Join-Path $taskRoot 'app\build\web') -Destination (Join-Path $taskResources 'app\build') -Recurse
Copy-Item -LiteralPath (Join-Path $taskRoot 'whiteboard-host\dist') -Destination (Join-Path $taskResources 'whiteboard-host') -Recurse
Copy-Item -LiteralPath (Join-Path $taskRoot 'service\target\companion-service-0.1.0.jar') -Destination (Join-Path $taskResources 'service\companion-service.jar')
Copy-Item -LiteralPath $taskBrowser -Destination (Join-Path $taskOutput 'webview2-runtime') -Recurse
$taskJlink = (Get-Command jlink).Source
Invoke-Checked { & $taskJlink --add-modules java.base,java.desktop,jdk.httpserver,java.logging,java.net.http,jdk.crypto.ec,jdk.unsupported --strip-debug --no-header-files --no-man-pages --compress=2 --output (Join-Path $taskOutput 'runtime') }
Copy-Item -LiteralPath (Join-Path $taskSdk 'lib\net462\Microsoft.Web.WebView2.Core.dll') -Destination $taskOutput
Copy-Item -LiteralPath (Join-Path $taskSdk 'lib\net462\Microsoft.Web.WebView2.WinForms.dll') -Destination $taskOutput
Copy-Item -LiteralPath (Join-Path $taskSdk 'runtimes\win-x64\native\WebView2Loader.dll') -Destination $taskOutput
$taskCompiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
Invoke-Checked { & $taskCompiler /nologo /target:winexe /platform:x64 /optimize+ /codepage:65001 "/out:$taskOutput\HocLuc-Teacher.exe" /reference:System.Windows.Forms.dll /reference:System.Drawing.dll /reference:System.Web.Extensions.dll "/reference:$taskOutput\Microsoft.Web.WebView2.Core.dll" "/reference:$taskOutput\Microsoft.Web.WebView2.WinForms.dll" (Join-Path $taskRoot 'packaging\windows\Program.cs') }
Copy-Item -LiteralPath (Join-Path $taskRoot 'packaging\windows\HocLuc-Teacher.exe.config') -Destination $taskOutput
Copy-Item -LiteralPath (Join-Path $taskRoot 'packaging\windows\README-Portable.txt') -Destination $taskOutput
Copy-Item -LiteralPath (Join-Path $taskRoot 'packaging\windows\THIRD-PARTY-NOTICES.txt') -Destination $taskOutput
$taskManifest = [ordered]@{ version='0.1.0'; platform='Windows x64'; host='WinForms + WebView2'; flutter='3.47.7 web'; java='17'; webview2=$taskVersion; sdk=$taskSdkVersion; builtAt=(Get-Date).ToString('o') }
$taskManifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $taskOutput 'build-info.json') -Encoding UTF8
$taskOutput | Set-Content -LiteralPath (Join-Path $taskRoot '.packaging\latest-output.txt') -Encoding UTF8
if ($CreateZip) { Compress-Archive -LiteralPath $taskOutput -DestinationPath ($taskOutput + '.zip') -CompressionLevel Optimal }
Write-Host "Ready: $taskOutput\HocLuc-Teacher.exe"
