[CmdletBinding()]
param([string]$ModelsRoot='D:\AI-Training\models')
$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$taskConverter=Join-Path $taskRoot 'backend\ai-runtime\.venv\Scripts\ct2-transformers-converter.exe'
if (!(Test-Path -LiteralPath $taskConverter)) {throw 'Cài runtime bằng Setup-AiRuntime.ps1 trước.'}
foreach($taskModel in @('PhoWhisper-small','vinai-translate-vi2en-v2')) {
    $taskOutput=Join-Path $ModelsRoot ($taskModel+'-ct2-int8')
    if (Test-Path -LiteralPath $taskOutput) {throw "Đã có $taskOutput. Giữ export hiện có; không ghi đè tự động."}
    $taskCopies=if ($taskModel -eq 'PhoWhisper-small') {@('tokenizer.json','preprocessor_config.json')} else {@('sentencepiece.bpe.model')}
    & $taskConverter --model (Join-Path $ModelsRoot $taskModel) --output_dir $taskOutput --copy_files $taskCopies --quantization int8
    if ($LASTEXITCODE) {throw "Export $taskModel thất bại."}
}
Write-Host 'Export INT8 riêng đã tạo; checkpoint gốc được giữ nguyên. Chạy baseline để đối chiếu bản dịch và ASR.'
