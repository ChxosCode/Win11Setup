#Requires -Version 5.1

<#
.SYNOPSIS
    Runs non-admin validation checks for the Win11Setup toolkit.

.DESCRIPTION
    This script validates parser health, module imports, profile/list parsing,
    manifest hashes, and winget package IDs when winget is available.
#>

[CmdletBinding()]
param(
    [switch]$SkipWingetIdCheck
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptRoot = $PSScriptRoot
$script:FailureCount = 0

function Invoke-ValidationStep {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [scriptblock]$Action
    )

    Write-Host ""
    Write-Host "=== $Name ===" -ForegroundColor Cyan

    try {
        & $Action
        Write-Host "OK: $Name" -ForegroundColor Green
    }
    catch {
        $script:FailureCount++
        Write-Host "FAIL: $Name" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}

Invoke-ValidationStep -Name "PowerShell parser" -Action {
    $files = Get-ChildItem -Path $ScriptRoot -Recurse -Include *.ps1, *.psm1, *.psd1 -File
    $parseErrors = @()

    foreach ($file in $files) {
        $tokens = $null
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors) | Out-Null

        foreach ($errorRecord in $errors) {
            $parseErrors += "{0}:{1}:{2}: {3}" -f $file.FullName, $errorRecord.Extent.StartLineNumber, $errorRecord.Extent.StartColumnNumber, $errorRecord.Message
        }
    }

    if ($parseErrors.Count -gt 0) {
        throw ($parseErrors -join [Environment]::NewLine)
    }

    Write-Host "Parsed $($files.Count) PowerShell files."
}

Invoke-ValidationStep -Name "Module imports" -Action {
    Set-ExecutionPolicy -Scope Process Bypass -Force

    $modules = Get-ChildItem -Path (Join-Path $ScriptRoot "modules") -Filter *.psm1 -File

    foreach ($module in $modules) {
        Import-Module $module.FullName -Force -DisableNameChecking -ErrorAction Stop
        Write-Host "Imported $($module.Name)"
    }
}

Invoke-ValidationStep -Name "Profile configs" -Action {
    $profiles = Get-ChildItem -Path (Join-Path $ScriptRoot "config") -Filter *.psd1 -File

    foreach ($profile in $profiles) {
        $config = Import-PowerShellDataFile -Path $profile.FullName

        foreach ($section in @("Settings", "Safety", "Features", "Lists")) {
            if (-not $config.ContainsKey($section)) {
                throw "$($profile.Name) is missing required section: $section"
            }
        }

        Write-Host "Loaded $($profile.Name)"
    }
}

Invoke-ValidationStep -Name "Winget JSON lists" -Action {
    $lists = Get-ChildItem -Path (Join-Path $ScriptRoot "lists") -Filter winget-*.json -File

    foreach ($list in $lists) {
        $config = Get-Content -Path $list.FullName -Raw | ConvertFrom-Json
        $appsProperty = $config.PSObject.Properties["apps"]

        if (-not $appsProperty) {
            throw "$($list.Name) is missing an apps array."
        }

        $apps = @($appsProperty.Value | Where-Object { $null -ne $_ })

        if ($apps.Count -eq 0) {
            throw "$($list.Name) has no app entries."
        }

        foreach ($app in $apps) {
            $idProperty = $app.PSObject.Properties["id"]

            if (-not $idProperty -or [string]::IsNullOrWhiteSpace([string]$idProperty.Value)) {
                throw "$($list.Name) contains an app entry without a non-empty id."
            }
        }

        Write-Host "Parsed $($list.Name): $($apps.Count) apps"
    }
}

Invoke-ValidationStep -Name "Manifest hashes" -Action {
    $manifestPath = Join-Path $ScriptRoot "MANIFEST.md"
    $manifest = Get-Content -Path $manifestPath
    $checked = 0
    $failures = @()

    foreach ($line in $manifest) {
        if ($line -match '^- `([^`]+)` .+ `([0-9a-f]{64})`') {
            $relativePath = $Matches[1]
            $expectedHash = $Matches[2]
            $filePath = Join-Path $ScriptRoot $relativePath

            if (-not (Test-Path -LiteralPath $filePath)) {
                $failures += "Manifest entry missing on disk: $relativePath"
                continue
            }

            $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $filePath).Hash.ToLowerInvariant()
            $checked++

            if ($actualHash -ne $expectedHash) {
                $failures += "$relativePath expected $expectedHash actual $actualHash"
            }
        }
    }

    if ($failures.Count -gt 0) {
        throw ($failures -join [Environment]::NewLine)
    }

    Write-Host "Checked $checked manifest entries."
}

Invoke-ValidationStep -Name "Winget package IDs" -Action {
    if ($SkipWingetIdCheck) {
        Write-Host "Skipped by -SkipWingetIdCheck."
        return
    }

    $winget = Get-Command winget -ErrorAction SilentlyContinue

    if (-not $winget) {
        Write-Host "winget not found; skipping package ID verification."
        return
    }

    $ids = Get-ChildItem -Path (Join-Path $ScriptRoot "lists") -Filter winget-*.json -File |
        ForEach-Object { (Get-Content -Path $_.FullName -Raw | ConvertFrom-Json).apps } |
        Where-Object { $_.enabled -ne $false } |
        ForEach-Object { $_.id } |
        Sort-Object -Unique

    foreach ($id in $ids) {
        $output = & winget search --id $id --exact --source winget --accept-source-agreements 2>&1

        if (-not ($LASTEXITCODE -eq 0 -and (($output -join "`n") -match [regex]::Escape($id)))) {
            throw "winget package ID did not resolve exactly: $id"
        }

        Write-Host "Resolved $id"
    }
}

if ($script:FailureCount -gt 0) {
    throw "$script:FailureCount validation step(s) failed."
}

Write-Host ""
Write-Host "All validation checks passed." -ForegroundColor Green
