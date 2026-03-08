$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$startScript = Join-Path $repoRoot 'windows\start-iopaint.ps1'
$stopScript = Join-Path $repoRoot 'windows\stop-iopaint.ps1'
$stopBatch = Join-Path $repoRoot 'Stop IOPaint.bat'

if (!(Test-Path $startScript)) {
    throw "Missing start script: $startScript"
}

if (!(Test-Path $stopScript)) {
    throw "Missing stop script: $stopScript"
}

if (!(Test-Path $stopBatch)) {
    throw "Missing stop batch file: $stopBatch"
}

$startContent = Get-Content $startScript -Raw
$stopContent = Get-Content $stopScript -Raw
$batchContent = Get-Content $stopBatch -Raw

foreach ($pattern in @(
    '\[switch\]\$Background',
    '\.iopaint-state',
    'Start-Process',
    'Get-NetTCPConnection\s+-State Listen\s+-LocalPort',
    'PID=',
    'URL='
)) {
    if ($startContent -notmatch $pattern) {
        throw "Start script missing expected pattern: $pattern"
    }
}

foreach ($pattern in @(
    'Stop-Process',
    '\.iopaint-state'
)) {
    if ($stopContent -notmatch $pattern) {
        throw "Stop script missing expected pattern: $pattern"
    }
}

if ($batchContent -notmatch 'IOPaint Launcher\.exe"\s+--stop') {
    throw 'Stop batch file does not route through the launcher stop command.'
}

Write-Host 'Background runtime verification passed.'
