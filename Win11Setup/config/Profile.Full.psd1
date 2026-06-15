@{
    Settings = @{
        Name = "Full"
        RestartExplorerAfterTweaks = $true
    }

    Safety = @{
        CreateRestorePoint = $true
    }

    Features = @{
        # Winget/package tasks
        UpdateWingetSources = $true
        UpgradeExistingWingetApps = $true
        InstallWingetApps = $true

        # Appx removal tasks
        # These still require -AllowDestructive at runtime.
        RemoveConservativeAppxJunk = $true
        RemoveAggressiveAppxJunk = $false
        RemoveProvisionedAppxPackages = $false

        # Windows preference tasks
        ApplyExplorerTweaks = $true
        ApplyTaskbarTweaks = $true
        ApplyDeveloperTweaks = $true

        # Optional Windows features
        EnableWSL = $false
        EnableHyperV = $false
        EnableWindowsSandbox = $false
    }

    Lists = @{
        WingetApps = ".\lists\winget-full.json"
        ConservativeAppx = ".\lists\appx-remove-conservative.txt"
        AggressiveAppx = ".\lists\appx-remove-aggressive.txt"
    }
}
