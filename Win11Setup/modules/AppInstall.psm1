function Test-WingetAppInstalled {
    param(
        [Parameter(Mandatory)]
        [string]$Id
    )

    $output = & winget list --id $Id -e --accept-source-agreements 2>$null

    if ($LASTEXITCODE -eq 0 -and ($output -join "`n") -match [regex]::Escape($Id)) {
        return $true
    }

    return $false
}

function Install-WingetApp {
    param(
        [Parameter(Mandatory)]
        [string]$Id,

        [string]$Name,

        [string]$Source = "winget",

        [switch]$DryRun
    )

    $displayName = if ($Name) { $Name } else { $Id }

    Write-Host "Checking app: $displayName"

    if (-not $DryRun) {
        if (Test-WingetAppInstalled -Id $Id) {
            Write-Host "Already installed: $Id" -ForegroundColor Green
            return
        }
    }

    $wingetArguments = @(
        "install",
        "--id", $Id,
        "-e",
        "--silent",
        "--accept-package-agreements",
        "--accept-source-agreements"
    )

    if ($Source) {
        $wingetArguments += @("--source", $Source)
    }

    if ($DryRun) {
        Write-Host "[DRY RUN] winget $($wingetArguments -join ' ')" -ForegroundColor Yellow
        return
    }

    & winget @wingetArguments

    if ($LASTEXITCODE -ne 0) {
        throw "Failed installing $Id"
    }
}

function Install-WingetAppsFromJson {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [switch]$DryRun
    )

    if (-not (Test-Path $Path)) {
        throw "Winget app list not found: $Path"
    }

    $config = Get-Content $Path -Raw | ConvertFrom-Json

    $appsProperty = $config.PSObject.Properties["apps"]

    if (-not $appsProperty) {
        throw "No apps array found in $Path"
    }

    $apps = @($appsProperty.Value | Where-Object { $null -ne $_ })

    if ($apps.Count -eq 0) {
        throw "No apps found in $Path"
    }

    for ($i = 0; $i -lt $apps.Count; $i++) {
        $app = $apps[$i]
        $entryNumber = $i + 1
        $idProperty = $app.PSObject.Properties["id"]

        if (-not $idProperty -or [string]::IsNullOrWhiteSpace([string]$idProperty.Value)) {
            throw "App entry $entryNumber in $Path is missing a non-empty id."
        }

        $id = [string]$idProperty.Value
        $enabledProperty = $app.PSObject.Properties["enabled"]

        if ($enabledProperty -and $enabledProperty.Value -eq $false) {
            Write-Host "SKIP app: $id" -ForegroundColor DarkGray
            continue
        }

        $nameProperty = $app.PSObject.Properties["name"]
        $name = if ($nameProperty) { [string]$nameProperty.Value } else { $null }

        $sourceProperty = $app.PSObject.Properties["source"]
        $source = if ($sourceProperty -and -not [string]::IsNullOrWhiteSpace([string]$sourceProperty.Value)) {
            [string]$sourceProperty.Value
        }
        else {
            "winget"
        }

        Install-WingetApp `
            -Id $id `
            -Name $name `
            -Source $source `
            -DryRun:$DryRun
    }
}

Export-ModuleMember -Function *
