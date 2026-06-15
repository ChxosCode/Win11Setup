function Remove-AppxPackageByName {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [switch]$RemoveProvisioned,

        [switch]$DryRun
    )

    Write-Host "Checking Appx package: $Name"

    $packages = Get-AppxPackage -Name $Name -ErrorAction SilentlyContinue

    foreach ($package in $packages) {
        if ($DryRun) {
            Write-Host "[DRY RUN] Remove-AppxPackage $($package.PackageFullName)" -ForegroundColor Yellow
        }
        else {
            Write-Host "Removing current-user Appx package: $($package.PackageFullName)"
            try {
                Remove-AppxPackage -Package $package.PackageFullName -ErrorAction Stop
                Write-Host "Removed current-user Appx package: $($package.PackageFullName)" -ForegroundColor Green
            }
            catch {
                Write-Host "WARNING: Failed to remove current-user Appx package $($package.PackageFullName): $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
    }

    if ($RemoveProvisioned) {
        $provisionedPackages = Get-AppxProvisionedPackage -Online |
            Where-Object { $_.DisplayName -eq $Name }

        foreach ($package in $provisionedPackages) {
            if ($DryRun) {
                Write-Host "[DRY RUN] Remove-AppxProvisionedPackage $($package.PackageName)" -ForegroundColor Yellow
            }
            else {
                Write-Host "Removing provisioned Appx package: $($package.PackageName)"
                try {
                    Remove-AppxProvisionedPackage -Online -PackageName $package.PackageName -ErrorAction Stop | Out-Null
                    Write-Host "Removed provisioned Appx package: $($package.PackageName)" -ForegroundColor Green
                }
                catch {
                    Write-Host "WARNING: Failed to remove provisioned Appx package $($package.PackageName): $($_.Exception.Message)" -ForegroundColor Yellow
                }
            }
        }
    }
}

function Remove-AppxPackagesFromList {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [switch]$RemoveProvisioned,

        [switch]$DryRun
    )

    if (-not (Test-Path $Path)) {
        throw "Appx removal list not found: $Path"
    }

    $apps = Get-Content $Path |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne "" } |
        Where-Object { -not $_.StartsWith("#") }

    foreach ($app in $apps) {
        Remove-AppxPackageByName `
            -Name $app `
            -RemoveProvisioned:$RemoveProvisioned `
            -DryRun:$DryRun
    }
}

Export-ModuleMember -Function *
