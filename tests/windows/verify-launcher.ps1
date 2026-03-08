$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$exePath = Join-Path $repoRoot 'IOPaint Launcher.exe'
$sourcePath = Join-Path $repoRoot 'windows\launcher\Program.cs'
$iconScriptPath = Join-Path $repoRoot 'windows\launcher\generate-icon.ps1'
$iconPath = Join-Path $repoRoot 'windows\launcher\iopaint-launcher.ico'

if (!(Test-Path $sourcePath)) {
    throw "Missing launcher source: $sourcePath"
}

if (!(Test-Path $iconScriptPath)) {
    throw "Missing icon generator: $iconScriptPath"
}

$source = Get-Content $sourcePath -Raw

foreach ($pattern in @(
    'NotifyIcon',
    'ThreadPool\.QueueUserWorkItem',
    'BeginInvoke',
    'Stop IOPaint and Exit',
    '--stop',
    'CreateNoWindow\s*=\s*true',
    'FindExecutable\("pwsh\.exe"\)',
    'FindExecutable\("powershell\.exe"\)',
    'Path\.Combine\(root,\s*"windows",\s*"start-iopaint\.ps1"\)',
    'Path\.Combine\(root,\s*"windows",\s*"stop-iopaint\.ps1"\)'
)) {
    if ($source -notmatch $pattern) {
        throw "Launcher source missing expected pattern: $pattern"
    }
}

if (!(Test-Path $exePath)) {
    throw "Missing launcher EXE: $exePath"
}

$null = Add-Type -AssemblyName System.Drawing

if (!(Test-Path $iconPath)) {
    throw "Missing launcher icon: $iconPath"
}

function Get-ImageHash {
    param(
        [System.Drawing.Image]$Image
    )

    $bitmap = New-Object System.Drawing.Bitmap 64, 64
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $graphics.DrawImage($Image, 0, 0, 64, 64)

    $stream = New-Object System.IO.MemoryStream
    $bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
    $hash = [System.BitConverter]::ToString(
        [System.Security.Cryptography.SHA256]::Create().ComputeHash($stream.ToArray())
    )

    $graphics.Dispose()
    $bitmap.Dispose()
    $stream.Dispose()
    $Image.Dispose()

    return $hash
}

$process = Start-Process -FilePath $exePath -ArgumentList '--launcher-self-test' -PassThru -Wait
if ($process.ExitCode -ne 0) {
    throw "Launcher self-test failed with exit code $($process.ExitCode)"
}

$expectedHash = Get-ImageHash -Image (([System.Drawing.Icon]::ExtractAssociatedIcon($iconPath)).ToBitmap())
$actualHash = Get-ImageHash -Image (([System.Drawing.Icon]::ExtractAssociatedIcon($exePath)).ToBitmap())
if ($expectedHash -ne $actualHash) {
    throw 'Launcher icon mismatch.'
}

Write-Host 'Launcher verification passed.'
