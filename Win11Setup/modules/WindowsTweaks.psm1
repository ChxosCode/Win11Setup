function Set-RegistryValueSafe {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        $Value,

        [ValidateSet("String", "ExpandString", "Binary", "DWord", "MultiString", "QWord")]
        [string]$Type = "DWord",

        [switch]$DryRun
    )

    if ($DryRun) {
        Write-Host "[DRY RUN] Set registry value: $Path\$Name = $Value" -ForegroundColor Yellow
        return
    }

    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }

    New-ItemProperty `
        -Path $Path `
        -Name $Name `
        -Value $Value `
        -PropertyType $Type `
        -Force | Out-Null
}

function Set-ExplorerTweaks {
    param(
        [switch]$RestartExplorer,
        [switch]$DryRun
    )

    $advancedPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"

    # Show file extensions.
    Set-RegistryValueSafe `
        -Path $advancedPath `
        -Name "HideFileExt" `
        -Value 0 `
        -DryRun:$DryRun

    # Show hidden files.
    Set-RegistryValueSafe `
        -Path $advancedPath `
        -Name "Hidden" `
        -Value 1 `
        -DryRun:$DryRun

    # Open File Explorer to "This PC".
    Set-RegistryValueSafe `
        -Path $advancedPath `
        -Name "LaunchTo" `
        -Value 1 `
        -DryRun:$DryRun

    if ($RestartExplorer -and -not $DryRun) {
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    }
}

function Set-TaskbarTweaks {
    param([switch]$DryRun)

    $advancedPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"

    # Left-align taskbar icons.
    Set-RegistryValueSafe `
        -Path $advancedPath `
        -Name "TaskbarAl" `
        -Value 0 `
        -DryRun:$DryRun

    # Hide Task View button.
    Set-RegistryValueSafe `
        -Path $advancedPath `
        -Name "ShowTaskViewButton" `
        -Value 0 `
        -DryRun:$DryRun
}

function Set-DeveloperTweaks {
    param([switch]$DryRun)

    # Enable long paths for developer tooling and deeply nested repos.
    Set-RegistryValueSafe `
        -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" `
        -Name "LongPathsEnabled" `
        -Value 1 `
        -DryRun:$DryRun
}

function Invoke-NativeCommandChecked {
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [string[]]$Arguments,

        [switch]$DryRun
    )

    $command = "$FilePath $($Arguments -join ' ')"

    if ($DryRun) {
        Write-Host "[DRY RUN] $command" -ForegroundColor Yellow
        return
    }

    Write-Host $command -ForegroundColor DarkGray
    & $FilePath @Arguments

    if ($LASTEXITCODE -ne 0) {
        throw "Native command failed with exit code $($LASTEXITCODE): $command"
    }
}

function Enable-WslFeature {
    param([switch]$DryRun)

    Invoke-NativeCommandChecked `
        -FilePath "dism.exe" `
        -Arguments @(
            "/online",
            "/enable-feature",
            "/featurename:Microsoft-Windows-Subsystem-Linux",
            "/all",
            "/norestart"
        ) `
        -DryRun:$DryRun

    Invoke-NativeCommandChecked `
        -FilePath "dism.exe" `
        -Arguments @(
            "/online",
            "/enable-feature",
            "/featurename:VirtualMachinePlatform",
            "/all",
            "/norestart"
        ) `
        -DryRun:$DryRun
}

function Enable-HyperVFeature {
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Host "[DRY RUN] Enable Hyper-V optional feature" -ForegroundColor Yellow
        return
    }

    Write-Host "Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart" -ForegroundColor DarkGray
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart -ErrorAction Stop | Out-Null
    Write-Host "Enabled Hyper-V optional feature" -ForegroundColor Green
}

function Enable-WindowsSandboxFeature {
    param([switch]$DryRun)

    if ($DryRun) {
        Write-Host "[DRY RUN] Enable Windows Sandbox optional feature" -ForegroundColor Yellow
        return
    }

    Write-Host "Enable-WindowsOptionalFeature -Online -FeatureName Containers-DisposableClientVM -All -NoRestart" -ForegroundColor DarkGray
    Enable-WindowsOptionalFeature -Online -FeatureName Containers-DisposableClientVM -All -NoRestart -ErrorAction Stop | Out-Null
    Write-Host "Enabled Windows Sandbox optional feature" -ForegroundColor Green
}

Export-ModuleMember -Function *
