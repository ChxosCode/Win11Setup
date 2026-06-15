# Win11Setup

A conservative, modular Windows 11 setup toolkit for fresh installs.

This repo-style package helps you:

- Remove obvious preinstalled Appx junk from an allowlist.
- Install apps with `winget`.
- Apply small Windows Explorer/developer preferences.
- Keep destructive work behind explicit opt-in switches.
- Use profiles so you can run a minimal setup, developer setup, or fuller setup.

The default posture is intentionally cautious. Nothing aggressive should happen unless you enable it in a profile and unlock destructive tasks at runtime.

---

## Folder layout

```text
Win11Setup/
  Bootstrap-Win11.ps1
  Test-Win11Setup.ps1
  config/
    Profile.Minimal.psd1
    Profile.Dev.psd1
    Profile.Full.psd1
  lists/
    winget-minimal.json
    winget-dev.json
    winget-full.json
    appx-remove-conservative.txt
    appx-remove-aggressive.txt
  modules/
    SystemHelpers.psm1
    WingetHelpers.psm1
    AppInstall.psm1
    AppxRemoval.psm1
    WindowsTweaks.psm1
  logs/
```

---

## Recommended first run

Open **PowerShell as Administrator**, then run:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\Bootstrap-Win11.ps1 -Profile Dev -DryRun
```

Review the output. Then run:

```powershell
.\Bootstrap-Win11.ps1 -Profile Dev
```

This runs non-destructive/default-safe tasks.

To validate the toolkit files without running setup tasks:

```powershell
.\Test-Win11Setup.ps1
```

This validation script does not require Administrator. It checks PowerShell parsing,
module imports, profile loading, winget JSON shape, manifest hashes, and enabled
winget package IDs when `winget` is available.

To allow app removals and other destructive operations:

```powershell
.\Bootstrap-Win11.ps1 -Profile Dev -AllowDestructive
```

If a destructive task also requires confirmation, you will be prompted unless you use:

```powershell
.\Bootstrap-Win11.ps1 -Profile Dev -AllowDestructive -NoConfirm
```

---

## Profiles

Profiles are in the `config/` folder.

Available profiles:

```powershell
.\Bootstrap-Win11.ps1 -Profile Minimal
.\Bootstrap-Win11.ps1 -Profile Dev
.\Bootstrap-Win11.ps1 -Profile Full
```

### `Minimal`

Installs a small set of essentials and applies basic Explorer tweaks.

### `Dev`

Installs developer-focused apps and applies developer-friendly tweaks.

### `Full`

Adds more optional apps and optionally runs a broader setup. This profile still keeps destructive actions locked behind `-AllowDestructive`.

---

## Important safety model

There are two layers of control:

1. The profile must enable a feature.
2. Destructive tasks require `-AllowDestructive`.

For example, this profile setting enables Appx removal as a possible task:

```powershell
RemoveConservativeAppxJunk = $true
```

But it will still be skipped unless you run:

```powershell
.\Bootstrap-Win11.ps1 -Profile Dev -AllowDestructive
```

This protects you from accidentally removing things while testing.

---

## Common switches

```powershell
-DryRun
```

Prints what would happen without making changes.

```powershell
-AllowDestructive
```

Allows destructive tasks such as removing Appx packages.

```powershell
-NoConfirm
```

Skips confirmation prompts for destructive tasks.

```powershell
-SkipWinget
```

Skips winget source updates, upgrades, and app installs.

```powershell
-SkipDebloat
```

Skips Appx removal tasks.

```powershell
-SkipTweaks
```

Skips Windows/Explorer/developer preference changes.

```powershell
-NoRestorePoint
```

Skips restore point creation even if enabled in the profile.

---

## Validation and maintenance

Run validation after editing scripts, profiles, package lists, or the manifest:

```powershell
.\Test-Win11Setup.ps1
```

If you are offline or do not want to query winget package IDs:

```powershell
.\Test-Win11Setup.ps1 -SkipWingetIdCheck
```

The manifest in `MANIFEST.md` stores SHA256 hashes for toolkit files. If you
intentionally edit tracked files, update the matching manifest hashes before
committing.

---

## Editing installed apps

App lists are JSON files in `lists/`.

Example:

```json
{
  "apps": [
    {
      "id": "Microsoft.PowerToys",
      "enabled": true,
      "category": "utility",
      "notes": "Useful Windows power-user tools."
    }
  ]
}
```

Set `"enabled": false` to keep the item in the list but skip installation.

To find package IDs:

```powershell
winget search vscode
winget search postgres
winget search powertoys
```

Then use the exact package ID in the JSON list.

---

## Editing Appx removals

Appx removal lists are plain text files:

```text
Clipchamp.Clipchamp
Microsoft.BingNews
Microsoft.BingWeather
```

Blank lines and lines starting with `#` are ignored.

Recommended approach:

- Keep `appx-remove-conservative.txt` small and boring.
- Put questionable removals in `appx-remove-aggressive.txt`.
- Do not remove Store, App Installer, Edge, WebView2, Windows Security, Photos, Terminal, Calculator, Notepad, or media extensions unless you know exactly why.

---

## What the script intentionally does not do

This package does not attempt to:

- Disable Windows Security.
- Remove Microsoft Store.
- Remove Edge/WebView2.
- Disable Windows Update.
- Apply broad privacy/telemetry registry changes.
- Run random third-party debloat scripts.
- Install apps from arbitrary URLs.

Those actions are more likely to cause maintenance problems later.

---

## Logs

Each run writes a transcript to:

```text
logs/
```

Example:

```text
bootstrap-Dev-20260615-143000.log
```

Use this when something fails or when you want to see exactly what happened.
Appx removal failures are written as warnings instead of being hidden, and
optional Windows feature commands fail the task if the underlying Windows command
returns an error.

---

## Suggested workflow for a fresh machine

1. Copy this folder to the new machine.
2. Open PowerShell as Administrator.
3. Run `-DryRun`.
4. Edit the profile or app list if needed.
5. Run without `-AllowDestructive`.
6. Reboot.
7. Run again with `-AllowDestructive` only after reviewing the Appx removal list.
8. Reboot again if optional Windows features were enabled.

---

## Notes

This toolkit is meant to be personal and boring. The safest long-term setup script is one you understand, can edit quickly, and can rerun without fear.
