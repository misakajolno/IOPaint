param(
    [string]$BindHost = "127.0.0.1",
    [int]$Port = 8080,
    [string]$Model = "lama",
    [ValidateSet("cpu", "cuda", "mps")]
    [string]$Device = "cpu",
    [switch]$InBrowser,
    [switch]$Background,
    [int]$StartupTimeoutSeconds = 30
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$python = Join-Path $root ".venv-iopaint\\Scripts\\python.exe"
$modelDir = Join-Path $root ".iopaint-models"
$cacheDir = Join-Path $root ".iopaint-cache"
$outputDir = Join-Path $root ".iopaint-output"
$stateDir = Join-Path $root ".iopaint-state"
$pidFile = Join-Path $stateDir "backend.pid"
$stdoutLog = Join-Path $stateDir "backend.stdout.log"
$stderrLog = Join-Path $stateDir "backend.stderr.log"

if (!(Test-Path $python)) {
    throw "IOPaint venv not found at $python"
}

foreach ($dir in @($modelDir, $cacheDir, $outputDir, $stateDir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
}

$env:XDG_CACHE_HOME = $cacheDir
$env:HF_HOME = $cacheDir

function Test-BackendReady {
    param(
        [string]$BindAddress,
        [int]$BackendPort,
        [int]$ProcessId,
        [int]$TimeoutSeconds
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        $client = New-Object System.Net.Sockets.TcpClient
        $asyncResult = $null
        try {
            $asyncResult = $client.BeginConnect($BindAddress, $BackendPort, $null, $null)
            if ($asyncResult.AsyncWaitHandle.WaitOne(500, $false)) {
                $client.EndConnect($asyncResult)
                return $true
            }
        } catch {
        } finally {
            if ($asyncResult) {
                $asyncResult.AsyncWaitHandle.Close()
            }
            $client.Close()
        }

        try {
            $process = Get-Process -Id $ProcessId -ErrorAction Stop
            if ($process.HasExited) {
                return $false
            }
        } catch {
            return $false
        }

        Start-Sleep -Milliseconds 500
    }

    return $false
}

function Get-BackendProcessId {
    if (!(Test-Path $pidFile)) {
        return $null
    }

    $content = (Get-Content $pidFile -Raw).Trim()
    if ($content -notmatch '^\d+$') {
        Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
        return $null
    }

    $processId = [int]$content
    try {
        $null = Get-Process -Id $processId -ErrorAction Stop
        return $processId
    } catch {
        Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
        return $null
    }
}

function Get-ListeningProcessId {
    param(
        [int]$BackendPort
    )

    try {
        return Get-NetTCPConnection -State Listen -LocalPort $BackendPort -ErrorAction Stop |
            Select-Object -ExpandProperty OwningProcess -Unique |
            Select-Object -First 1
    } catch {
        return $null
    }
}

$args = @(
    "-m", "iopaint", "start",
    "--host", $BindHost,
    "--port", $Port,
    "--model", $Model,
    "--device", $Device,
    "--model-dir", $modelDir
)

if ($InBrowser -and -not $Background) {
    $args += "--inbrowser"
} else {
    $args += "--no-inbrowser"
}

if ($Background) {
    $url = "http://{0}:{1}/" -f $BindHost, $Port
    $existingProcessId = Get-BackendProcessId
    if ($existingProcessId) {
        Write-Output "ALREADY_RUNNING=1"
        Write-Output "PID=$existingProcessId"
        Write-Output "URL=$url"
        if ($InBrowser) {
            Start-Process $url | Out-Null
        }
        exit 0
    }

    Remove-Item $stdoutLog -Force -ErrorAction SilentlyContinue
    Remove-Item $stderrLog -Force -ErrorAction SilentlyContinue

    $process = Start-Process -FilePath $python `
        -ArgumentList $args `
        -WorkingDirectory $root `
        -WindowStyle Hidden `
        -PassThru `
        -RedirectStandardOutput $stdoutLog `
        -RedirectStandardError $stderrLog

    Set-Content -Path $pidFile -Value $process.Id -NoNewline

    if (!(Test-BackendReady -BindAddress $BindHost -BackendPort $Port -ProcessId $process.Id -TimeoutSeconds $StartupTimeoutSeconds)) {
        Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
        $stderrTail = if (Test-Path $stderrLog) {
            (Get-Content $stderrLog -Tail 20) -join [Environment]::NewLine
        } else {
            ""
        }
        throw ("IOPaint backend did not become ready in {0} seconds.`n{1}" -f $StartupTimeoutSeconds, $stderrTail)
    }

    $listeningProcessId = Get-ListeningProcessId -BackendPort $Port
    if ($listeningProcessId) {
        Set-Content -Path $pidFile -Value $listeningProcessId -NoNewline
    } else {
        $listeningProcessId = $process.Id
    }

    Write-Output "PID=$listeningProcessId"
    Write-Output "URL=$url"
    if ($InBrowser) {
        Start-Process $url | Out-Null
    }
    exit 0
}

& $python @args
