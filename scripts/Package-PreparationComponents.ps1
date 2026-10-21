<# Operator tool: create an offline bundle from reviewed local component folders.
   Never downloads components. The teacher installs the ZIP through HocLuc.
   SHA256 verifies integrity; it does not authenticate the bundle publisher. #>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$')][string]$Version,
    [Parameter(Mandatory=$true)][string]$OutputZip,
    [string]$ModelRoot,
    [string]$RuntimeDirectory,
    [string]$FfmpegExecutable
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
$destination = [IO.Path]::GetFullPath($OutputZip)
if (Test-Path -LiteralPath $destination) { throw 'Output already exists; choose a new ZIP path.' }
$sources = [System.Collections.Generic.List[object]]::new()
$components = [ordered]@{}
$blocked = '(?i)(^|/)(\.git|\.cache|__pycache__|\.pytest_cache|\.env[^/]*|[^/]*\.local\.[^/]*|credentials[^/]*|secrets?[^/]*|id_rsa|id_ed25519)(/|$)|(?i)\.(pem|key|pfx|p12)$'
function Add-ComponentDirectory([string]$Path, [string]$Prefix) {
    $directory = (Get-Item -LiteralPath $Path).FullName.TrimEnd('\','/')
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) { throw 'Component must be a directory.' }
    if ($destination.StartsWith($directory + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Output ZIP must be outside all input directories.' }
    foreach ($entry in Get-ChildItem -LiteralPath $directory -Force -Recurse) {
        if (($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Links/reparse points are not allowed: $($entry.FullName)" }
        if ($entry.PSIsContainer) { continue }
        $relative = $entry.FullName.Substring($directory.Length + 1).Replace('\','/')
        if ($relative -match $blocked) { continue }
        $sources.Add([pscustomobject]@{ source=$entry.FullName; path="$Prefix/$relative"; size=[long]$entry.Length })
    }
}
if ($ModelRoot) { Add-ComponentDirectory $ModelRoot 'models'; $components.modelRoot='models' }
if ($RuntimeDirectory) {
    if (-not (Test-Path -LiteralPath (Join-Path $RuntimeDirectory 'python.exe') -PathType Leaf)) { throw 'RuntimeDirectory must contain python.exe.' }
    if (Test-Path -LiteralPath (Join-Path $RuntimeDirectory 'pyvenv.cfg')) { throw 'Use a reviewed relocatable Python distribution, not a machine-bound venv.' }
    Add-ComponentDirectory $RuntimeDirectory 'runtime'; $components.pythonPath='runtime/python.exe'
}
if ($FfmpegExecutable) {
    $file = Get-Item -LiteralPath $FfmpegExecutable
    if ($file.PSIsContainer -or $file.Name -ine 'ffmpeg.exe') { throw 'Select an actual ffmpeg.exe.' }
    $sources.Add([pscustomobject]@{source=$file.FullName;path='ffmpeg/ffmpeg.exe';size=[long]$file.Length});$components.ffmpegPath='ffmpeg/ffmpeg.exe'
}
if ($sources.Count -eq 0) { throw 'Supply at least one nonempty component.' }
$total = ($sources | Measure-Object -Property size -Sum).Sum
if ($total -gt 16GB) { throw 'Expanded bundle exceeds the 16 GiB installer limit.' }
$files = @($sources | ForEach-Object { [ordered]@{path=$_.path;size=$_.size;sha256=(Get-FileHash -LiteralPath $_.source -Algorithm SHA256).Hash.ToLowerInvariant()} })
$manifest = [ordered]@{schemaVersion=1;version=$Version;components=$components;files=$files} | ConvertTo-Json -Depth 8
[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination)) | Out-Null
$stream = [IO.File]::Open($destination,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write)
try {
    $archive = [IO.Compression.ZipArchive]::new($stream,[IO.Compression.ZipArchiveMode]::Create,$true)
    try {
        foreach ($source in $sources) {
            $entry = $archive.CreateEntry($source.path,[IO.Compression.CompressionLevel]::Optimal)
            $inputStream = [IO.File]::OpenRead($source.source);$outputStream=$entry.Open()
            try { $inputStream.CopyTo($outputStream,131072) } finally { $outputStream.Dispose();$inputStream.Dispose() }
        }
        $metadata = $archive.CreateEntry('bundle-manifest.json').Open()
        $writer = [IO.StreamWriter]::new($metadata,[Text.UTF8Encoding]::new($false))
        try { $writer.Write($manifest) } finally { $writer.Dispose() }
    } finally { $archive.Dispose() }
} finally { $stream.Dispose() }
if ((Get-Item -LiteralPath $destination).Length -gt 8GB) { throw 'ZIP exceeds 8 GiB; split model and runtime into separate reviewed bundles.' }
[pscustomobject]@{path=$destination;version=$Version;files=$sources.Count;expandedBytes=$total;sha256=(Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant();publisherTrustVerified=$false}
