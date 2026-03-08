$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$source = Join-Path $repoRoot 'windows\launcher\Program.cs'
$iconScript = Join-Path $repoRoot 'windows\launcher\generate-icon.ps1'
$icon = Join-Path $repoRoot 'windows\launcher\iopaint-launcher.ico'
$output = Join-Path $repoRoot 'IOPaint Launcher.exe'
$cscCandidates = @(
    "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe",
    "$env:WINDIR\Microsoft.NET\Framework\v4.0.30319\csc.exe"
)
$csc = $cscCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

if (!(Test-Path $source)) {
    throw "Missing launcher source: $source"
}

if (!(Test-Path $iconScript)) {
    throw "Missing icon generator: $iconScript"
}

if (!$csc) {
    throw 'csc.exe not found in .NET Framework directories.'
}

powershell.exe -NoLogo -ExecutionPolicy Bypass -File $iconScript -OutputPath $icon
if ($LASTEXITCODE -ne 0) {
    throw "Launcher icon generation failed with exit code $LASTEXITCODE"
}

& $csc /nologo /target:winexe "/out:$output" "/win32icon:$icon" /r:System.Windows.Forms.dll /r:System.Drawing.dll $source
if ($LASTEXITCODE -ne 0) {
    throw "Launcher build failed with exit code $LASTEXITCODE"
}

Write-Output $output
