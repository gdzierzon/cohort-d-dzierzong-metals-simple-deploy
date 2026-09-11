#requires -Version 5.1
<#
.SYNOPSIS
Creates PostgreSQL, a container registry, and the API, UI, and tutorials container Web Apps.
.DESCRIPTION
Requires Azure CLI (az login), permission to assign AcrPull roles, and psql
or Python with psycopg. Creates infrastructure only; images must subsequently
be built and pushed as metals-api, metals-ui, and metals-tutorials, each tagged
<ImageTag> (see az_deploy.ps1). Existing database tables are preserved. Use
-SkipProvisioning to resume after the resource group, database server, and
database have already been created.
.EXAMPLE
.\utility_scripts\az_create_resources.ps1 -UserName dzierzon
.EXAMPLE
.\utility_scripts\az_create_resources.ps1 -UserName dzierzon -SkipProvisioning
#>
[CmdletBinding()]
param(
    [ValidatePattern('^[a-z0-9][a-z0-9-]{0,24}$')]
    [string]$UserName = 'dzierzon',
    [string]$Location = 'westus2',
    [ValidatePattern('^[a-zA-Z0-9]{5,50}$')]
    [string]$RegistryName,
    [ValidatePattern('^[a-zA-Z0-9_][a-zA-Z0-9_.-]{0,127}$')]
    [string]$ImageTag = 'latest',
    # For a resumed database, supply its CURRENT administrator password.
    [Security.SecureString]$DatabasePassword,
    [string]$PsqlPath,
    # Supply this explicitly if a VPN/proxy uses a different database egress IP.
    [string]$ClientIp,
    # Resume after the resource group, PostgreSQL server, and database exist.
    [switch]$SkipProvisioning
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
$uiAppName = "expeditors-${UserName}-metals-ui"
$tutorialsAppName = "expeditors-${UserName}-metals-tutorials"
if (-not $RegistryName) {
    $RegistryName = "expeditors$($UserName.Replace('-', ''))metalsacr"
}
# Confirm an authenticated account before starting provisioning.
$null = Invoke-Az account show --query id --output tsv
if (-not $DatabasePassword) {
    $DatabasePassword = Read-Host 'PostgreSQL administrator password (use the existing password when resuming)' -AsSecureString
}
$dbPassword = [System.Net.NetworkCredential]::new('', $DatabasePassword).Password
if ([string]::IsNullOrWhiteSpace($dbPassword)) { throw 'A database password is required.' }

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

if (-not $SkipProvisioning) {
    # Resource group
    Invoke-Az group create --name $resourceGroup --location $Location --output none

    # Database: preserve the development settings from az_create_resources.sh.
    Invoke-Az postgres flexible-server create `
        --resource-group $resourceGroup `
        --name $dbServer `
        --location $Location `
        --admin-user metalsadmin `
        --admin-password $dbPassword `
        --tier Burstable `
        --sku-name Standard_B1ms `
        --storage-size 32 `
        --storage-auto-grow Disabled `
        --backup-retention 7 `
        --geo-redundant-backup Disabled `
        --version 16 `
        --public-access 0.0.0.0 `
        --tags Environment=Development --output none

    Invoke-Az postgres flexible-server db create `
        --resource-group $resourceGroup `
        --server-name $dbServer `
        --name metals --output none
}
else {
    Write-Host "Using existing resource group, PostgreSQL server, and database. Resuming at firewall configuration."
}

# The 0.0.0.0 rule above allows Azure services, not this local computer.
Invoke-Az postgres flexible-server firewall-rule create `
    --resource-group $resourceGroup `
    --server-name $dbServer `
    --name "LocalClient-$($ClientIp.Replace('.', '-'))" `
    --start-ip-address $ClientIp `
    --end-ip-address $ClientIp `
    --output none

# Initialize the database, then restore the caller's environment.
$previousPgPassword = $env:PGPASSWORD
$previousPgSslMode = $env:PGSSLMODE
$previousPgConnectTimeout = $env:PGCONNECT_TIMEOUT
$previousErrorActionPreference = $ErrorActionPreference
try {
    $env:PGPASSWORD = $dbPassword
    $env:PGSSLMODE = 'require'
    $env:PGCONNECT_TIMEOUT = '15'
    $sqlPath = Join-Path $PSScriptRoot '../sql/metals-db.sql'
    # Capture native stderr on Windows PowerShell as well as PowerShell 7.
    $ErrorActionPreference = 'Continue'
    if ($psqlCommand) {
        $existingTables = & $psqlCommand `
            --host="$dbServer.postgres.database.azure.com" --port=5432 `
            --username=metalsadmin --dbname=metals --set=ON_ERROR_STOP=1 `
            --tuples-only --no-align `
            --command="SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE';" 2>&1
        if ($LASTEXITCODE -ne 0) { throw "Could not inspect database tables: $existingTables" }
        if ([int]([string]($existingTables | Select-Object -Last 1)).Trim() -gt 0) {
            Write-Host 'Existing database tables found; preserving schema and data.'
            $initializationOutput = @()
        }
        else {
        $initializationOutput = & $psqlCommand `
        --host="$dbServer.postgres.database.azure.com" `
        --port=5432 `
        --username=metalsadmin `
        --dbname=metals `
        --set=ON_ERROR_STOP=1 `
        --single-transaction `
        --file="$sqlPath" 2>&1
        }
    }
    else {
        $initializeDatabase = @'
import pathlib
import sys
import psycopg

sql = pathlib.Path(sys.argv[2]).read_text(encoding="utf-8-sig")
with psycopg.connect(host=sys.argv[1], port=5432, user="metalsadmin", dbname="metals") as connection:
    count = connection.execute("SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE'").fetchone()[0]
    if count:
        print("Existing database tables found; preserving schema and data.")
    else:
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

# Registry permissions use AcrPull with classic registry RBAC, not ABAC.
Invoke-Az acr create --name $RegistryName --resource-group $resourceGroup `
    --location $Location --sku Basic --admin-enabled false `
    --role-assignment-mode rbac --output none
$registry = Invoke-Az acr show --name $RegistryName --resource-group $resourceGroup --output json | ConvertFrom-Json

Invoke-Az appservice plan create --name $planName --resource-group $resourceGroup `
    --sku B1 --is-linux --location $Location --output none

# JSON files avoid Windows command-line quoting issues. App settings may contain
# secrets; do not print their contents, and always remove the temporary files.
function Set-WebAppSettings {
    param([string]$Name, [hashtable]$Settings)
    $settingsFile = [System.IO.Path]::GetTempFileName()
    try {
        [System.IO.File]::WriteAllText($settingsFile, ($Settings | ConvertTo-Json), [System.Text.UTF8Encoding]::new($false))
        Invoke-Az webapp config appsettings set --resource-group $resourceGroup `
            --name $Name --settings "@$settingsFile" --output none
    }
    finally { Remove-Item -LiteralPath $settingsFile -Force }
}

foreach ($webApp in @(
    @{ Name = $appName; Image = 'metals-api'; Port = '5000' },
    @{ Name = $uiAppName; Image = 'metals-ui'; Port = '8080' },
    @{ Name = $tutorialsAppName; Image = 'metals-tutorials'; Port = '8080' }
)) {
    $name = $webApp.Name
    $image = "$($registry.loginServer)/$($webApp.Image):$ImageTag"
    $existingApps = @(Invoke-Az webapp list --resource-group $resourceGroup --query '[].name' --output tsv)
    if ($name -notin $existingApps) {
        # Images can be pushed later. The app will not serve traffic until then.
        Invoke-Az webapp create --name $name --resource-group $resourceGroup `
            --plan $planName --container-image-name $image `
            --assign-identity '[system]' --acr-use-identity --acr-identity '[system]' --output none
    }
    $principalId = Invoke-Az webapp identity assign --name $name `
        --resource-group $resourceGroup --query principalId --output tsv
    Invoke-Az role assignment create --assignee-object-id $principalId `
        --assignee-principal-type ServicePrincipal --scope $registry.id `
        --role AcrPull --output none

    # Also converts an existing source-code Web App to a container Web App.
    Invoke-Az webapp config container set --name $name --resource-group $resourceGroup `
        --container-image-name $image `
        --container-registry-url "https://$($registry.loginServer)" --output none

    $configFile = [System.IO.Path]::GetTempFileName()
    try {
        $config = @{
            acrUseManagedIdentityCreds = $true
            acrUserManagedIdentityID = ''
            appCommandLine = '' # Use the image's CMD, removing the old Gunicorn override.
            alwaysOn = $true
            healthCheckPath = '/health'
        }
        [System.IO.File]::WriteAllText($configFile, ($config | ConvertTo-Json), [System.Text.UTF8Encoding]::new($false))
        Invoke-Az webapp config set --name $name --resource-group $resourceGroup `
            --generic-configurations "@$configFile" --output none
    }
    finally { Remove-Item -LiteralPath $configFile -Force }

    Invoke-Az webapp update --name $name --resource-group $resourceGroup --https-only true --output none
    Set-WebAppSettings -Name $name -Settings @{
        WEBSITES_PORT = $webApp.Port
        WEBSITES_ENABLE_APP_SERVICE_STORAGE = 'false'
        SCM_DO_BUILD_DURING_DEPLOYMENT = 'false'
    }
    Invoke-Az webapp log config --name $name --resource-group $resourceGroup `
        --docker-container-logging filesystem --output none
}

# Preserve an existing signing key so a provisioning rerun does not revoke JWTs.
$jwtSecret = Invoke-Az webapp config appsettings list --name $appName `
    --resource-group $resourceGroup --query "[?name=='JWT_SECRET_KEY'].value | [0]" --output tsv
if ([string]::IsNullOrWhiteSpace([string]$jwtSecret)) {
    $randomBytes = New-Object byte[] 48
    $randomGenerator = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try { $randomGenerator.GetBytes($randomBytes) }
    finally { $randomGenerator.Dispose() }
    $jwtSecret = [Convert]::ToBase64String($randomBytes)
}
try {
    Set-WebAppSettings -Name $appName -Settings @{
        DB_HOST = "$dbServer.postgres.database.azure.com"
        DB_PORT = '5432'
        DB_NAME = 'metals'
        DB_USER = 'metalsadmin'
        DB_PASSWORD = $dbPassword
        PGSSLMODE = 'require'
        JWT_SECRET_KEY = [string]$jwtSecret
        JWT_EXPIRATION_MINUTES = '60'
        FLASK_DEBUG = '0'
    }
}
finally { Remove-Variable dbPassword, jwtSecret -ErrorAction SilentlyContinue }

# Use Azure's actual hostname (which may include a region/unique suffix).
$apiHost = Invoke-Az webapp show --name $appName --resource-group $resourceGroup --query defaultHostName --output tsv
$uiHost = Invoke-Az webapp show --name $uiAppName --resource-group $resourceGroup --query defaultHostName --output tsv
$tutorialsHost = Invoke-Az webapp show --name $tutorialsAppName --resource-group $resourceGroup --query defaultHostName --output tsv
Set-WebAppSettings -Name $uiAppName -Settings @{
    API_UPSTREAM = "https://$apiHost"
    # Docker's embedded DNS (127.0.0.11, the image default) does not exist on
    # Azure Web Apps; 168.63.129.16 is Azure's platform DNS address instead.
    NGINX_RESOLVER = '168.63.129.16'
}
# The tutorial site is fully static and needs no settings beyond the container
# defaults applied in the loop above.

Write-Host "Resource group: $resourceGroup"
Write-Host "Container registry: $($registry.loginServer)"
Write-Host "API image: $($registry.loginServer)/metals-api:$ImageTag"
Write-Host "UI image: $($registry.loginServer)/metals-ui:$ImageTag"
Write-Host "Tutorials image: $($registry.loginServer)/metals-tutorials:$ImageTag"
Write-Host "API URL: https://$apiHost"
Write-Host "UI URL: https://$uiHost"
Write-Host "Tutorials URL: https://$tutorialsHost"
Write-Host 'Infrastructure configured. Build and push the images, then restart the Web Apps.'
Write-Host 'Run az_deploy.ps1 to build and deploy all three images.'
