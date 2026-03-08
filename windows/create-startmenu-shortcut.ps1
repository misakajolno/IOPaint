param(
    [string]$ShortcutName = "IOPaint",
    [switch]$Overwrite
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$exeFile = Join-Path $root "IOPaint Launcher.exe"
$batchFile = Join-Path $root "IOPaint.bat"
$targetFile = if (Test-Path $exeFile) { $exeFile } else { $batchFile }
$startMenuDir = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs"
$shortcutPath = Join-Path $startMenuDir ("{0}.lnk" -f $ShortcutName)

if (!(Test-Path $targetFile)) {
    throw "Missing launcher target: $targetFile"
}

if ((Test-Path $shortcutPath) -and -not $Overwrite) {
    throw "Shortcut already exists: $shortcutPath"
}

$wsh = New-Object -ComObject WScript.Shell
$shortcut = $wsh.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $targetFile
$shortcut.WorkingDirectory = $root
$shortcut.Description = "Launch IOPaint local web UI"
$shortcut.IconLocation = if (Test-Path $exeFile) { "$exeFile,0" } else { "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe,0" }
$shortcut.Save()

Write-Output $shortcutPath
