# windows-postinstall

Windows equivalent of linux-postinstall, Easy post-fresh-install script for Windows 10+, not including device drivers.

### Downloads

1. [Direct Link](https://github.com/arfshl/windows-postinstall/archive/refs/heads/main.zip) 

- Unzip, go to `windows-postinstall-main` folder and run the script and/or apply registry tweaks

2. Directly from PowerShell (Must be run in an elevated PowerShell Administrator session.)

```powershell
cd ~\Downloads

Invoke-WebRequest -Uri "https://github.com/arfshl/windows-postinstall/archive/refs/heads/main.zip" -OutFile "windows-postinstall-main.zip"

Expand-Archive -Path "main.zip" -DestinationPath "." -Force

cd "windows-postinstall-main"

ls
```

### Features

1. Including useful tools and app depedency like
- 7zip
- VLC Media Player
- AOMEI Partition Assistant
- Microsoft Edge WebView2 Runtime
- LocalSend
- AnyBurn
- Microsoft Visual C++ Redistributable (All-Version)

2. Choose your browser easily from the available list under `-Help` section

```powershell
Usage: .\windows-postinstall.ps1 [options1] [options2] ...
Must be run in an elevated PowerShell Administrator session.

options:
  -h, -Help             Show this help message and exit
  -CoreApps             Install core applications ($coreAppsFormatted)
  -MsvcRedist           Download and install Visual C++ Redistributable AIO from GitHub
  -Chrome               Install Google Chrome browser
  -Firefox              Install Mozilla Firefox browser
  -FirefoxESR           Install Mozilla Firefox ESR browser
  -Opera                Install Opera browser
  -Chromium             Install Chromium browser
  -Edge                 Install Microsoft Edge browser
  -Vivaldi              Install Vivaldi browser
  -Brave                Install Brave browser
  -FirefoxDev           Install Mozilla Firefox Developer Edition browser
  -AddApps <IDs>        Install additional Winget package IDs (separated by space or comma)
  -WhatIf               Dry-run mode (simulate execution without installing)

Usage example:
  .\windows-postinstall.ps1 -CoreApps -MsvcRedist -FirefoxDev -AddApps Microsoft.VisualStudioCode,Git.Git
```

### Registry Tweaks

- disable-autoupdate.reg - Disable Windows AutoUpdate

- enable-autoupdate.reg - Re-enable Windows AutoUpdate

- explorer-disable-new-context-menu.reg - Disable Windows 11 new Explorer context menu

- explorer-enable-new-context-menu.reg - Re-Enable Windows 11 new Explorer context menu