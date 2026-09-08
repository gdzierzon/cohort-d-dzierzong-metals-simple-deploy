#requires -Version 5.1
# Requires Azure CLI (az login), plus psql or Python with psycopg installed.
[CmdletBinding()]
param(
    [string]$UserName = 'dzierzon',
    [string]$PsqlPath,
    # Supply this explicitly if a VPN/proxy uses a different database egress IP.
    [string]$ClientIp
)

$ErrorActionPreference = 'Stop'

function Invoke-Az {
    & az @args
    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI failed with exit code $LASTEXITCODE."
    }
}

$null = Get-Command az -ErrorAction Stop
$psqlCommand = $null
$pythonCommand = $null
if ($PsqlPath) {
    $psqlCommand = (Get-Command $PsqlPath -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
}
else {
    $psqlCommand = (Get-Command psql -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1).Source
    if (-not $psqlCommand) {
        foreach ($programDirectory in @($env:ProgramFiles, ${env:ProgramFiles(x86)})) {
            if (-not $programDirectory) { continue }
            $postgresDirectory = Join-Path $programDirectory 'PostgreSQL'
            $candidate = Get-ChildItem "$postgresDirectory/*/bin/psql.exe" -ErrorAction SilentlyContinue |
                Sort-Object FullName -Descending | Select-Object -First 1
            if ($candidate) {
                $psqlCommand = $candidate.FullName
                break
            }
        }
    }
}
if (-not $psqlCommand) {
    $projectRoot = Split-Path -Parent $PSScriptRoot
    $pythonCandidates = @(
        (Join-Path $projectRoot '.venv/Scripts/python.exe'),
        'python',
        'python3'
    )
    foreach ($candidate in $pythonCandidates) {
        $command = Get-Command $candidate -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $command) { continue }
        & $command.Source -c 'import psycopg' 2>$null
        if ($LASTEXITCODE -eq 0) {
            $pythonCommand = $command.Source
            break
        }
    }
    if (-not $pythonCommand) {
        throw 'Database initialization requires psql or Python with psycopg. Run: python -m pip install "psycopg[binary]>=3.0,<4.0", or pass -PsqlPath with the full path to psql.exe.'
    }
    Write-Host 'psql was not found; using Python with psycopg to initialize the database.'
}
$resourceGroup = "expeditors-${UserName}-metals-rg"
$dbServer = "expeditors-${UserName}-metals-pg"
$appName = "expeditors-${UserName}-metals-api"
$planName = "expeditors-${UserName}-metals-appservice-plan"

# Resolve the local client's public IPv4 address before provisioning resources.
if (-not $ClientIp) {
    try {
        $ClientIp = ([string](Invoke-RestMethod -Uri 'https://api4.ipify.org' -TimeoutSec 15)).Trim()
    }
    catch {
        throw 'Could not detect your public IPv4 address. Rerun with -ClientIp <your-public-IPv4-address>.'
    }
}
$parsedClientIp = $null
if (-not [System.Net.IPAddress]::TryParse($ClientIp, [ref]$parsedClientIp) -or
    $parsedClientIp.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork -or
    $ClientIp -eq '0.0.0.0') {
    throw '-ClientIp must be a nonzero IPv4 address for this computer.'
}

# Resource group
Invoke-Az group create --name $resourceGroup --location westus2

# Database: preserve the development settings from az_create_resources.sh.
Invoke-Az postgres flexible-server create `
    --resource-group $resourceGroup `
    --name $dbServer `
    --location westus2 `
    --admin-user metalsadmin `
    --admin-password 'P@ssw0rd' `
    --tier Burstable `
    --sku-name Standard_B1ms `
    --storage-size 32 `
    --storage-auto-grow Disabled `
    --backup-retention 7 `
    --geo-redundant-backup Disabled `
    --version 16 `
    --public-access 0.0.0.0 `
    --tags Environment=Development

Invoke-Az postgres flexible-server db create `
    --resource-group $resourceGroup `
    --server-name $dbServer `
    --name metals

# The 0.0.0.0 rule above allows Azure services, not this local computer.
Invoke-Az postgres flexible-server firewall-rule create `
    --resource-group $resourceGroup `
    --server-name $dbServer `
    --rule-name "LocalClient-$($ClientIp.Replace('.', '-'))" `
    --start-ip-address $ClientIp `
    --end-ip-address $ClientIp `
    --output none

# Initialize the database, then restore the caller's environment.
$previousPgPassword = $env:PGPASSWORD
$previousPgSslMode = $env:PGSSLMODE
$previousPgConnectTimeout = $env:PGCONNECT_TIMEOUT
$previousErrorActionPreference = $ErrorActionPreference
try {
    $env:PGPASSWORD = 'P@ssw0rd'
    $env:PGSSLMODE = 'require'
    $env:PGCONNECT_TIMEOUT = '15'
    $sqlPath = Join-Path $PSScriptRoot '../sql/metals-db.sql'
    # Capture native stderr on Windows PowerShell as well as PowerShell 7.
    $ErrorActionPreference = 'Continue'
    if ($psqlCommand) {
        $initializationOutput = & $psqlCommand `
        --host="$dbServer.postgres.database.azure.com" `
        --port=5432 `
        --username=metalsadmin `
        --dbname=metals `
        --set=ON_ERROR_STOP=1 `
        --file="$sqlPath" 2>&1
    }
    else {
        $initializeDatabase = @'
import pathlib
import sys
import psycopg

sql = pathlib.Path(sys.argv[2]).read_text(encoding="utf-8-sig")
with psycopg.connect(host=sys.argv[1], port=5432, user="metalsadmin", dbname="metals") as connection:
    connection.execute(sql)
'@
        $initializationOutput = $initializeDatabase | & $pythonCommand - "$dbServer.postgres.database.azure.com" $sqlPath 2>&1
    }
    $initializationExitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorActionPreference
    if ($initializationExitCode -ne 0) {
        $details = ($initializationOutput | Out-String).Trim()
        throw "Database initialization failed with exit code ${initializationExitCode}:`n$details`nIf the connection timed out, allow up to five minutes for the firewall rule to propagate and verify your network permits outbound TCP 5432. If using a VPN/proxy, supply -ClientIp with the database connection's public egress IPv4 address."
    }
    $initializationOutput | Write-Output
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
    $env:PGPASSWORD = $previousPgPassword
    $env:PGSSLMODE = $previousPgSslMode
    $env:PGCONNECT_TIMEOUT = $previousPgConnectTimeout
}

# App Service
Invoke-Az appservice plan create `
    --name $planName `
    --resource-group $resourceGroup `
    --sku B1 `
    --is-linux `
    --location westus2

Invoke-Az webapp create `
    --name $appName `
    --resource-group $resourceGroup `
    --plan $planName `
    --runtime 'PYTHON:3.11'

Invoke-Az webapp config set `
    --resource-group $resourceGroup `
    --name $appName `
    --startup-file 'gunicorn --bind=0.0.0.0 --timeout 600 app:app'

Invoke-Az webapp config appsettings set `
    --resource-group $resourceGroup `
    --name $appName `
    --settings "DB_HOST=$dbServer.postgres.database.azure.com" `
        'DB_NAME=metals' `
        'DB_USER=metalsadmin' `
        'DB_PASSWORD=P@ssw0rd' `
        'SCM_DO_BUILD_DURING_DEPLOYMENT=true'

$dbUser = 'metalsadmin'
$dbUserInput = Read-Host "Enter the PostgreSQL username [$dbUser]"
if (-not [string]::IsNullOrEmpty($dbUserInput)) {
    $dbUser = $dbUserInput
}

$securePassword = Read-Host 'Enter the PostgreSQL password' -AsSecureString
$passwordPointer = [IntPtr]::Zero
try {
    $passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    $dbPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPointer)
    $encodedPassword = [Uri]::EscapeDataString($dbPassword)
    $dbUrl = "postgresql://${dbUser}:${encodedPassword}@${dbServer}.postgres.database.azure.com:5432/metals?sslmode=require"

    Invoke-Az webapp config appsettings set `
        --resource-group $resourceGroup `
        --name $appName `
        --settings "DB_URL=$dbUrl" 'FLASK_DEBUG=0' `
        --output none
}
finally {
    if ($passwordPointer -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer)
    }
    $securePassword.Dispose()
    Remove-Variable dbPassword, encodedPassword, dbUrl -ErrorAction SilentlyContinue
}

# As in the Bash script, stop the database when provisioning is complete.
Invoke-Az postgres flexible-server stop `
    --resource-group $resourceGroup `
    --name $dbServer
