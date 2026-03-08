$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$gitignorePath = Join-Path $repoRoot '.gitignore'
$windowsDir = Join-Path $repoRoot 'windows'
$launcherDir = Join-Path $windowsDir 'launcher'
$startScript = Join-Path $windowsDir 'start-iopaint.ps1'
$stopScript = Join-Path $windowsDir 'stop-iopaint.ps1'
$buildScript = Join-Path $windowsDir 'build-launcher.ps1'
$shortcutScript = Join-Path $windowsDir 'create-startmenu-shortcut.ps1'
$rootBatch = Join-Path $repoRoot 'IOPaint.bat'
$rootStopBatch = Join-Path $repoRoot 'Stop IOPaint.bat'

if (!(Test-Path $gitignorePath)) {
    throw "Missing .gitignore: $gitignorePath"
}

$gitignore = Get-Content $gitignorePath -Raw
foreach ($pattern in @(
    '.venv-iopaint/',
    '.iopaint-cache/',
    '.iopaint-models/',
    '.iopaint-output/',
    '.iopaint-state/',
    'IOPaint Launcher.exe',
    'windows/launcher/iopaint-launcher.ico'
)) {
    if ($gitignore -notmatch [Regex]::Escape($pattern)) {
        throw "Missing ignore rule: $pattern"
    }
}

foreach ($path in @($windowsDir, $launcherDir, $startScript, $stopScript, $buildScript, $shortcutScript, $rootBatch, $rootStopBatch)) {
    if (!(Test-Path $path)) {
        throw "Missing migrated path: $path"
    }
}

Write-Host 'Layout verification passed.'
