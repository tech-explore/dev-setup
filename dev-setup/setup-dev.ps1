# setup-dev.ps1 - idempotent dev environment setup using winget
# Usage:  powershell -ExecutionPolicy Bypass -File .\setup-dev.ps1
#         .\setup-dev.ps1 -NativePostgres     # also install Postgres natively (default: use a container)

param(
    [switch]$NativePostgres
)

$ErrorActionPreference = 'Continue'

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Error "winget not found. Install 'App Installer' from the Microsoft Store first."
    exit 1
}

function Install-IfMissing {
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Name,
        [string]$Command   # optional CLI name to detect installs made outside winget
    )

    # 1) Already on PATH (installed manually or by another tool)?
    if ($Command -and (Get-Command $Command -ErrorAction SilentlyContinue)) {
        Write-Host "[skip]    $Name (found '$Command' on PATH)" -ForegroundColor DarkGray
        return
    }

    # 2) Already known to winget?
    winget list --id $Id --exact --accept-source-agreements 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[skip]    $Name (already installed via winget)" -ForegroundColor DarkGray
        return
    }

    # 3) Install
    Write-Host "[install] $Name ($Id)" -ForegroundColor Cyan
    winget install --id $Id --exact --silent `
        --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Failed to install $Name (exit code $LASTEXITCODE)"
    }
}

# --- Core tools ---
Install-IfMissing -Id 'Microsoft.WindowsTerminal'          -Name 'Windows Terminal'
Install-IfMissing -Id 'Microsoft.PowerShell'               -Name 'PowerShell 7'          -Command 'pwsh'
Install-IfMissing -Id 'Git.Git'                            -Name 'Git'                   -Command 'git'

# --- IDEs ---
Install-IfMissing -Id 'Microsoft.VisualStudioCode'         -Name 'VS Code'               -Command 'code'
Install-IfMissing -Id 'JetBrains.IntelliJIDEA.Community'   -Name 'IntelliJ IDEA (Community)'

# --- Java ---
Install-IfMissing -Id 'EclipseAdoptium.Temurin.21.JDK'     -Name 'Temurin JDK 21'        -Command 'java'

# --- Containers / Kubernetes ---
Install-IfMissing -Id 'SUSE.RancherDesktop'                -Name 'Rancher Desktop'

# --- Optional native Postgres (Redis and Kafka have no good native Windows builds; use containers) ---
if ($NativePostgres) {
    Install-IfMissing -Id 'PostgreSQL.PostgreSQL.17'       -Name 'PostgreSQL 17'         -Command 'psql'
} else {
    Write-Host "[note]    Skipping native Postgres (run it in a container, or re-run with -NativePostgres)" -ForegroundColor Yellow
}

# --- WSL2 ---
wsl --status 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "[skip]    WSL (already set up)" -ForegroundColor DarkGray
} else {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
               ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($isAdmin) {
        Write-Host "[install] WSL2 + Ubuntu" -ForegroundColor Cyan
        wsl --install
    } else {
        Write-Warning "WSL not installed. Re-run this script in an ADMIN PowerShell, or run 'wsl --install' there."
    }
}

Write-Host "`nDone. Reboot if WSL was just installed, and open a new terminal so PATH changes apply." -ForegroundColor Green
