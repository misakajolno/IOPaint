$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$startScript = Join-Path $repoRoot 'windows\start-iopaint.ps1'
$stopScript = Join-Path $repoRoot 'windows\stop-iopaint.ps1'
$port = 18083
$url = "http://127.0.0.1:$port/"

try {
    if (Test-Path $stopScript) {
        & $stopScript -Port $port | Out-Null
    }

    & $startScript -Background -Port $port -StartupTimeoutSeconds 60 | Out-Null

    $response = $null
    $deadline = (Get-Date).AddSeconds(20)
    while ((Get-Date) -lt $deadline) {
        try {
            $response = Invoke-WebRequest -UseBasicParsing $url
            break
        }
        catch {
            Start-Sleep -Milliseconds 500
        }
    }

    if ($null -eq $response) {
        throw "Failed to fetch root page from $url after startup."
    }

    $cacheControl = [string]$response.Headers['Cache-Control']
    $pragma = [string]$response.Headers['Pragma']
    $expires = [string]$response.Headers['Expires']

    if ([string]::IsNullOrWhiteSpace($cacheControl)) {
        throw 'Root page is missing Cache-Control header.'
    }

    if ($cacheControl -notmatch 'no-store' -and $cacheControl -notmatch 'no-cache') {
        throw "Root page Cache-Control does not disable caching: $cacheControl"
    }

    if ($pragma -and $pragma -notmatch 'no-cache') {
        throw "Unexpected Pragma header: $pragma"
    }

    if ($expires -and $expires -notin @('0', '-1')) {
        throw "Unexpected Expires header: $expires"
    }

    Write-Host 'Index cache header verification passed.'
}
finally {
    if (Test-Path $stopScript) {
        & $stopScript -Port $port | Out-Null
    }
}
