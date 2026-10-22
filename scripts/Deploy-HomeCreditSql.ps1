[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ServerInstance = "localhost"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$sqlRoot = Join-Path $projectRoot "sql"
$manifestPath = Join-Path $projectRoot "docs\RAW_DATA_SHA256.txt"
$deployPath = Join-Path $sqlRoot "000_deploy_all.sql"

if (-not (Get-Command sqlcmd -ErrorAction SilentlyContinue)) {
    throw "sqlcmd was not found. Install SQL Server command-line tools or run 000_deploy_all.sql in SSMS SQLCMD Mode."
}

if (-not (Test-Path $manifestPath)) {
    throw "Raw-data manifest was not found: $manifestPath"
}

Write-Host "Verifying raw CSV hashes..." -ForegroundColor Cyan
Get-Content $manifestPath | ForEach-Object {
    if ($_ -match '^([0-9a-fA-F]{64})\s+(.+)$') {
        $expectedHash = $Matches[1].ToUpperInvariant()
        $relativePath = $Matches[2]
        $filePath = Join-Path $projectRoot $relativePath

        if (-not (Test-Path $filePath)) {
            throw "Required source file is missing: $relativePath"
        }

        $actualHash = (Get-FileHash -Path $filePath -Algorithm SHA256).Hash
        if ($actualHash -ne $expectedHash) {
            throw "SHA-256 mismatch: $relativePath"
        }

        Write-Host "OK  $relativePath"
    }
}

Write-Host "Deploying SQL objects to $ServerInstance..." -ForegroundColor Cyan
Push-Location $sqlRoot
try {
    & sqlcmd -S $ServerInstance -E -b -i $deployPath
    if ($LASTEXITCODE -ne 0) {
        throw "sqlcmd deployment failed with exit code $LASTEXITCODE."
    }
}
finally {
    Pop-Location
}

Write-Host "SQL deployment and schema smoke test completed successfully." -ForegroundColor Green
