function Assert-WingetAvailable {
    $winget = Get-Command winget -ErrorAction SilentlyContinue

    if (-not $winget) {
        throw "winget was not found. Install or update App Installer from Microsoft Store, then rerun this script."
    }

    Write-Host "winget found: $($winget.Source)" -ForegroundColor Green
}

function Invoke-Winget {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments,

        [switch]$DryRun,

        [switch]$IgnoreExitCode
    )

    $command = "winget $($Arguments -join ' ')"

    if ($DryRun) {
        Write-Host "[DRY RUN] $command" -ForegroundColor Yellow
        return
    }

    Write-Host $command -ForegroundColor DarkGray
    & winget @Arguments

    if (-not $IgnoreExitCode -and $LASTEXITCODE -ne 0) {
        throw "winget failed with exit code $($LASTEXITCODE): $command"
    }
}

function Update-WingetSources {
    param([switch]$DryRun)

    Invoke-Winget -Arguments @("source", "update") -DryRun:$DryRun
}

function Update-WingetApps {
    param([switch]$DryRun)

    Invoke-Winget `
        -Arguments @(
            "upgrade",
            "--all",
            "--silent",
            "--accept-package-agreements",
            "--accept-source-agreements"
        ) `
        -DryRun:$DryRun
}

Export-ModuleMember -Function *
