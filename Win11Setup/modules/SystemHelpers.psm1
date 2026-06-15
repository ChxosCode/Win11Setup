function Write-SetupBanner {
    param(
        [Parameter(Mandatory)]
        [string]$Title,

        [string]$Subtitle
    )

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor Cyan

    if ($Subtitle) {
        Write-Host " $Subtitle" -ForegroundColor Cyan
    }

    Write-Host "============================================================" -ForegroundColor Cyan
}

function Write-SetupSuccess {
    param([Parameter(Mandatory)][string]$Message)

    Write-Host ""
    Write-Host $Message -ForegroundColor Green
}

function Write-SetupError {
    param([Parameter(Mandatory)][string]$Message)

    Write-Host ""
    Write-Host "ERROR: $Message" -ForegroundColor Red
}

function Resolve-SetupPath {
    param(
        [Parameter(Mandatory)]
        [string]$ScriptRoot,

        [Parameter(Mandatory)]
        [string]$RelativePath
    )

    $cleanPath = $RelativePath.Trim()

    if ([System.IO.Path]::IsPathRooted($cleanPath)) {
        return [System.IO.Path]::GetFullPath($cleanPath)
    }

    if ($cleanPath.StartsWith(".\") -or $cleanPath.StartsWith("./")) {
        $cleanPath = $cleanPath.Substring(2)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $ScriptRoot $cleanPath))
}

function Assert-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        throw "This script must be run from an elevated PowerShell session."
    }
}

function Confirm-DestructiveTask {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [switch]$NoConfirm
    )

    if ($NoConfirm) {
        return $true
    }

    Write-Host ""
    Write-Host "Destructive task requested: $Name" -ForegroundColor Yellow
    $answer = Read-Host "Type YES to continue"

    return $answer -eq "YES"
}

function Invoke-SetupTask {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [bool]$Enabled,

        [switch]$Destructive,

        [switch]$AllowDestructive,

        [switch]$NoConfirm,

        [switch]$DryRun,

        [Parameter(Mandatory)]
        [scriptblock]$Action
    )

    if (-not $Enabled) {
        Write-Host "SKIP: $Name" -ForegroundColor DarkGray
        return
    }

    if ($Destructive -and -not $AllowDestructive) {
        Write-Host "SKIP: $Name requires -AllowDestructive" -ForegroundColor Yellow
        return
    }

    if ($Destructive) {
        $confirmed = Confirm-DestructiveTask -Name $Name -NoConfirm:$NoConfirm

        if (-not $confirmed) {
            Write-Host "SKIP: $Name was not confirmed" -ForegroundColor Yellow
            return
        }
    }

    Write-Host ""
    Write-Host "=== $Name ===" -ForegroundColor Cyan

    if ($DryRun) {
        Write-Host "[DRY RUN] Task enabled: $Name" -ForegroundColor Yellow
    }

    & $Action
}

function New-SystemRestorePointSafe {
    param(
        [Parameter(Mandatory)]
        [string]$Description,

        [switch]$DryRun
    )

    if ($DryRun) {
        Write-Host "[DRY RUN] Create restore point: $Description" -ForegroundColor Yellow
        return
    }

    try {
        Checkpoint-Computer -Description $Description -RestorePointType "MODIFY_SETTINGS"
        Write-Host "Restore point requested: $Description" -ForegroundColor Green
    }
    catch {
        Write-Host "Restore point could not be created. Continuing. Details: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Export-ModuleMember -Function *
