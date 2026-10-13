[CmdletBinding()]
param([string]$ModelRoot='D:\AI-Training\models', [string]$OutputPath)
$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (!$OutputPath) {$OutputPath=Join-Path $taskRoot '.run\ai-model-manifest.json'}
$taskModels=@(
    @{folder='PhoWhisper-small';weights='pytorch_model.bin';source='https://huggingface.co/vinai/PhoWhisper-small';license='BSD-3-Clause'},
    @{folder='vinai-translate-vi2en-v2';weights='pytorch_model.bin';source='https://huggingface.co/vinai/vinai-translate-vi2en-v2';license='AGPL-3.0'},
    @{folder='Kokoro-82M';weights='kokoro-v1_0.pth';source='https://huggingface.co/hexgrad/Kokoro-82M';license='Apache-2.0'}
)
foreach ($taskModel in $taskModels) {
    $taskWeight=Join-Path (Join-Path $ModelRoot $taskModel.folder) $taskModel.weights
    $taskModel['sha256']=(Get-FileHash -LiteralPath $taskWeight -Algorithm SHA256).Hash.ToLowerInvariant()
    $taskModel['bytes']=(Get-Item -LiteralPath $taskWeight).Length
    $taskExport=Join-Path $ModelRoot ($taskModel.folder+'-ct2-int8\model.bin')
    if (Test-Path -LiteralPath $taskExport) {
        $taskModel['int8ExportSha256']=(Get-FileHash -LiteralPath $taskExport -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}
$taskManifest=@{generatedAt=(Get-Date -Format o);models=$taskModels;modelRoot=$ModelRoot;
    runtimeLockSha256=(Get-FileHash -LiteralPath (Join-Path $taskRoot 'backend\ai-runtime\requirements.resolved.txt')).Hash.ToLowerInvariant();
    note='Declared model licenses from local model cards. Original download revision not recorded; hashes identify installed weights. Driver and models are not bundled.'}
New-Item -ItemType Directory -Path (Split-Path -Parent $OutputPath) -Force | Out-Null
$taskManifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $OutputPath -Encoding utf8
Write-Host "Model manifest: $OutputPath"
