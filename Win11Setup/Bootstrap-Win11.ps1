#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Modular Windows 11 fresh-install setup script.

.DESCRIPTION
    This script acts as the orchestrator. It imports a selected profile, loads helper modules,
    and runs only the tasks enabled by that profile and command-line switches.

    Conservative defaults:
    - Destructive tasks require -AllowDestructive.
    - -DryRun previews commands where practical.
    - App removals use allowlists.
    - Most logic lives in modules instead of this script.

.EXAMPLE
    .\Bootstrap-Win11.ps1 -Profile Dev -DryRun

.EXAMPLE
    .\Bootstrap-Win11.ps1 -Profile Dev

.EXAMPLE
    .\Bootstrap-Win11.ps1 -Profile Dev -AllowDestructive
#>

[CmdletBinding()]
param(
    # Selects config/Profile.<Name>.psd1
    [Alias("Profile")]
    [ValidateSet("Minimal", "Dev", "Full")]
    [string]$ProfileName = "Dev",

    # Preview actions without intentionally changing the machine.
    [switch]$DryRun,

    # Required for destructive tasks such as Appx removal.
    [switch]$AllowDestructive,

    # Skips destructive task confirmation prompts.
    [switch]$NoConfirm,

    # Coarse skip switches are useful when testing one part of the script.
    [switch]$SkipWinget,
    [switch]$SkipDebloat,
    [switch]$SkipTweaks,

    # Overrides restore point creation even when enabled in the profile.
    [switch]$NoRestorePoint
)

# =============================================================================
# BOOTSTRAP
# =============================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptRoot = $PSScriptRoot
$ConfigPath = Join-Path $ScriptRoot "config\Profile.$ProfileName.psd1"

if (-not (Test-Path $ConfigPath)) {
    throw "Profile config not found: $ConfigPath"
}

$Config = Import-PowerShellDataFile -Path $ConfigPath

$ModulePaths = @(
    "modules\SystemHelpers.psm1",
    "modules\WingetHelpers.psm1",
    "modules\AppInstall.psm1",
    "modules\AppxRemoval.psm1",
    "modules\WindowsTweaks.psm1"
)

foreach ($modulePath in $ModulePaths) {
    $fullPath = Join-Path $ScriptRoot $modulePath

    if (-not (Test-Path $fullPath)) {
        throw "Required module missing: $fullPath"
    }

    Import-Module $fullPath -Force -DisableNameChecking
}

$LogDir = Join-Path $ScriptRoot "logs"
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null

$LogPath = Join-Path $LogDir ("bootstrap-{0}-{1}.log" -f $ProfileName, (Get-Date -Format "yyyyMMdd-HHmmss"))

$transcriptStarted = $false

try {
    Start-Transcript -Path $LogPath | Out-Null
    $transcriptStarted = $true

    Write-SetupBanner -Title "Win11Setup" -Subtitle "Profile: $ProfileName"

    Assert-Admin

    Invoke-SetupTask `
        -Name "Create system restore point" `
        -Enabled:($Config.Safety.CreateRestorePoint -and -not $NoRestorePoint) `
        -DryRun:$DryRun `
        -Action {
            New-SystemRestorePointSafe `
                -Description "Before Win11Setup bootstrap ($ProfileName)" `
                -DryRun:$DryRun
        }

    Invoke-SetupTask `
        -Name "Check winget availability" `
        -Enabled:(-not $SkipWinget) `
        -DryRun:$DryRun `
        -Action {
            Assert-WingetAvailable
        }

    Invoke-SetupTask `
        -Name "Update winget sources" `
        -Enabled:($Config.Features.UpdateWingetSources -and -not $SkipWinget) `
        -DryRun:$DryRun `
        -Action {
            Update-WingetSources -DryRun:$DryRun
        }

    Invoke-SetupTask `
        -Name "Upgrade existing winget apps" `
        -Enabled:($Config.Features.UpgradeExistingWingetApps -and -not $SkipWinget) `
        -DryRun:$DryRun `
        -Action {
            Update-WingetApps -DryRun:$DryRun
        }

    Invoke-SetupTask `
        -Name "Remove conservative Appx junk" `
        -Enabled:($Config.Features.RemoveConservativeAppxJunk -and -not $SkipDebloat) `
        -Destructive `
        -AllowDestructive:$AllowDestructive `
        -NoConfirm:$NoConfirm `
        -DryRun:$DryRun `
        -Action {
            $listPath = Resolve-SetupPath -ScriptRoot $ScriptRoot -RelativePath $Config.Lists.ConservativeAppx

            Remove-AppxPackagesFromList `
                -Path $listPath `
                -RemoveProvisioned:$Config.Features.RemoveProvisionedAppxPackages `
                -DryRun:$DryRun
        }

    Invoke-SetupTask `
        -Name "Remove aggressive Appx junk" `
        -Enabled:($Config.Features.RemoveAggressiveAppxJunk -and -not $SkipDebloat) `
        -Destructive `
        -AllowDestructive:$AllowDestructive `
        -NoConfirm:$NoConfirm `
        -DryRun:$DryRun `
        -Action {
            $listPath = Resolve-SetupPath -ScriptRoot $ScriptRoot -RelativePath $Config.Lists.AggressiveAppx

            Remove-AppxPackagesFromList `
                -Path $listPath `
                -RemoveProvisioned:$Config.Features.RemoveProvisionedAppxPackages `
                -DryRun:$DryRun
        }

    Invoke-SetupTask `
        -Name "Install winget apps" `
        -Enabled:($Config.Features.InstallWingetApps -and -not $SkipWinget) `
        -DryRun:$DryRun `
        -Action {
            $appsPath = Resolve-SetupPath -ScriptRoot $ScriptRoot -RelativePath $Config.Lists.WingetApps

            Install-WingetAppsFromJson `
                -Path $appsPath `
                -DryRun:$DryRun
        }

    Invoke-SetupTask `
        -Name "Apply Explorer tweaks" `
        -Enabled:($Config.Features.ApplyExplorerTweaks -and -not $SkipTweaks) `
        -DryRun:$DryRun `
        -Action {
            Set-ExplorerTweaks `
                -RestartExplorer:$Config.Settings.RestartExplorerAfterTweaks `
                -DryRun:$DryRun
        }

    Invoke-SetupTask `
        -Name "Apply taskbar tweaks" `
        -Enabled:($Config.Features.ApplyTaskbarTweaks -and -not $SkipTweaks) `
        -DryRun:$DryRun `
        -Action {
            Set-TaskbarTweaks -DryRun:$DryRun
        }

    Invoke-SetupTask `
        -Name "Apply developer tweaks" `
        -Enabled:($Config.Features.ApplyDeveloperTweaks -and -not $SkipTweaks) `
        -DryRun:$DryRun `
        -Action {
            Set-DeveloperTweaks -DryRun:$DryRun
        }

    Invoke-SetupTask `
        -Name "Enable WSL optional features" `
        -Enabled:($Config.Features.EnableWSL -and -not $SkipTweaks) `
        -DryRun:$DryRun `
        -Action {
            Enable-WslFeature -DryRun:$DryRun
        }

    Invoke-SetupTask `
        -Name "Enable Hyper-V optional feature" `
        -Enabled:($Config.Features.EnableHyperV -and -not $SkipTweaks) `
        -DryRun:$DryRun `
        -Action {
            Enable-HyperVFeature -DryRun:$DryRun
        }

    Invoke-SetupTask `
        -Name "Enable Windows Sandbox optional feature" `
        -Enabled:($Config.Features.EnableWindowsSandbox -and -not $SkipTweaks) `
        -DryRun:$DryRun `
        -Action {
            Enable-WindowsSandboxFeature -DryRun:$DryRun
        }

    Write-SetupSuccess -Message "Bootstrap complete. Log saved to: $LogPath"
}
catch {
    Write-SetupError -Message $_.Exception.Message
    throw
}
finally {
    if ($transcriptStarted) {
        Stop-Transcript | Out-Null
    }
}
