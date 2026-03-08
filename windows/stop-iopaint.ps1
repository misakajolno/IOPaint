param(
    [int]$Port = 8080
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$stateDir = Join-Path $root ".iopaint-state"
$pidFile = Join-Path $stateDir "backend.pid"

function Remove-StateFiles {
    Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
}

function Get-CommandLineForProcess {
    param(
        [int]$ProcessId
    )

    try {
        return (Get-CimInstance Win32_Process -Filter ("ProcessId = {0}" -f $ProcessId) -ErrorAction Stop).CommandLine
    } catch {
        return $null
    }
}

function Stop-BackendProcess {
    param(
        [int]$ProcessId
    )

    try {
        Stop-Process -Id $ProcessId -Force -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

$stopped = $false

if (Test-Path $pidFile) {
    $rawPid = (Get-Content $pidFile -Raw).Trim()
    if ($rawPid -match '^\d+$') {
        $processId = [int]$rawPid
        $commandLine = Get-CommandLineForProcess -ProcessId $processId
        if ($commandLine -and ($commandLine -match 'iopaint' -or $commandLine -match [regex]::Escape($root))) {
            $stopped = Stop-BackendProcess -ProcessId $processId
        }
    }
}

if (-not $stopped) {
    try {
        $connections = Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction Stop | Select-Object -ExpandProperty OwningProcess -Unique
        foreach ($processId in $connections) {
            $commandLine = Get-CommandLineForProcess -ProcessId $processId
            if ($commandLine -and ($commandLine -match 'iopaint' -or $commandLine -match [regex]::Escape($root))) {
                if (Stop-BackendProcess -ProcessId $processId) {
                    $stopped = $true
                }
            }
        }
    } catch {
    }
}

Remove-StateFiles

if ($stopped) {
    Write-Output "STOPPED=1"
} else {
    Write-Output "STOPPED=0"
}
