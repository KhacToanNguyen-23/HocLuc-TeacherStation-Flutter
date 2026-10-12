param([Parameter(Mandatory=$true)][string]$WebRoot)
$ErrorActionPreference = 'Stop'
$taskAssets = Join-Path $WebRoot 'assets'
$taskManifest = Join-Path $taskAssets 'FontManifest.json'
if (!(Test-Path -LiteralPath $taskManifest)) {
    throw "Flutter font manifest is missing: $taskManifest. Rebuild the frontend before packaging."
}
$taskFonts = @(Get-Content -LiteralPath $taskManifest -Raw | ConvertFrom-Json)
foreach ($taskFamily in @('MaterialIcons', 'Manrope', 'Literata')) {
    if (!($taskFonts | Where-Object family -eq $taskFamily)) {
        throw "Required Flutter font family is missing: $taskFamily"
    }
}
foreach ($taskFamily in $taskFonts) {
    foreach ($taskFont in $taskFamily.fonts) {
        $taskPath = Join-Path $taskAssets $taskFont.asset
        if (!(Test-Path -LiteralPath $taskPath -PathType Leaf) -or (Get-Item -LiteralPath $taskPath).Length -eq 0) {
            throw "Flutter font asset is missing or empty: $taskPath"
        }
    }
}
