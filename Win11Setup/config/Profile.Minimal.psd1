@{
    Settings = @{
        Name = "Minimal"
        RestartExplorerAfterTweaks = $true
    }

    Safety = @{
        CreateRestorePoint = $true
    }

    Features = @{
        # Winget/package tasks
        UpdateWingetSources = $true
        UpgradeExistingWingetApps = $false
        InstallWingetApps = $true

        # Appx removal tasks
        RemoveConservativeAppxJunk = $false
        RemoveAggressiveAppxJunk = $false
        RemoveProvisionedAppxPackages = $false

        # Windows preference tasks
        ApplyExplorerTweaks = $true
        ApplyTaskbarTweaks = $false
        ApplyDeveloperTweaks = $false

        # Optional Windows features
        EnableWSL = $false
        EnableHyperV = $false
        EnableWindowsSandbox = $false
    }

    Lists = @{
        WingetApps = ".\lists\winget-minimal.json"
        ConservativeAppx = ".\lists\appx-remove-conservative.txt"
        AggressiveAppx = ".\lists\appx-remove-aggressive.txt"
    }
}
