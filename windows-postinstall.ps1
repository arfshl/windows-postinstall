# Easy post-fresh-install script for Windows 10+, not including device drivers.
[CmdletBinding(SupportsShouldProcess)]
param (
    [Alias("h")]
    [switch]$Help,

    [switch]$CoreApps,
    [switch]$MsvcRedist,
    [switch]$Chrome,
    [switch]$Firefox,
    [switch]$FirefoxESR,
    [switch]$Opera,
    [switch]$Chromium,
    [switch]$Edge,
    [switch]$Vivaldi,
    [switch]$Brave,
    [switch]$FirefoxDev,

    [Alias("add")]
    [string[]]$AddApps
)

$ErrorActionPreference = 'Stop'

# coreapps list
$coreAppsList = @(
    "7zip.7zip",
    "VideoLAN.VLC",
    "Microsoft.EdgeWebView2Runtime",
    "Zoom.Zoom"
)

# func: show help message
function Show-Help {
    $coreAppsFormatted = ($coreAppsList -join ', ')
    $helpText = @"
Usage: .\windows-postinstall.ps1 [options1] [options2] ...
Must be run in an elevated PowerShell Administrator session.

options:
  -h, -Help             Show this help message and exit
  -CoreApps             Install core applications
  -MsvcRedist           Download and install Visual C++ Redistributable AIO from GitHub
  -Chrome               Install Google Chrome browser
  -Firefox              Install Mozilla Firefox browser
  -FirefoxEsr           Install Mozilla Firefox ESR browser
  -Opera                Install Opera browser
  -Chromium             Install Chromium browser
  -Edge                 Install Microsoft Edge browser
  -Vivaldi              Install Vivaldi browser
  -Brave                Install Brave browser
  -FirefoxDev           Install Mozilla Firefox Developer Edition browser
  -AddApps <IDs>        Install additional Winget package IDs (separated by space or comma)
  -WhatIf               Dry-run mode (simulate execution without installing)

Usage example:
  .\windows-postinstall.ps1 -CoreApps -MsvcRedist -Chrome # Recomendded
  .\windows-postinstall.ps1 -CoreApps -MsvcRedist -FirefoxDev -AddApps Microsoft.VisualStudioCode,Git.Git,AOMEI.PartitionAssistant,LocalSend.LocalSend,PowerSoftware.AnyBurn # My setup
"@
    Write-Host $helpText
}

if ($WhatIfPreference) {
    Write-Warning "Running in WhatIf (Dry-run) mode. No changes will be made."
}

# func: winget install parameter
function Install-WingetPackage {
    param(
        [Parameter(Mandatory)]
        [string]$Id
    )

    $process = Start-Process winget `
        -ArgumentList @(
            "install",
            "--id", $Id,
            "-e",
            "--silent",
            "--disable-interactivity",
            "--accept-package-agreements",
            "--accept-source-agreements"
        ) `
        -Wait `
        -PassThru `
        -NoNewWindow

    return $process.ExitCode
}

# func: test winget exit code and display appropriate message
function Test-WingetExitCode {
    param(
        [string]$Name,
        [int]$ExitCode
    )

    switch ($ExitCode) {
        0 {
            Write-Host "INFO: $Name installed successfully." -ForegroundColor Green
            return $true
        }

        -1978335189 {
            Write-Host "INFO: $Name already installed." -ForegroundColor Green
            return $true
        }

        -1978335212 {
            Write-Host "INFO: $Name requires no update." -ForegroundColor Green
            return $true
        }

        3010 {
        Write-Warning "$Name installed successfully. Restart required."
            return $true
        }
        default {
            Write-Warning "Failed to install $Name (Exit Code: $ExitCode)."
            return $false
        }
    }
}

# show help then exit
if ($Help) {
    Show-Help
    exit 0
}

# func: check if at least one parameter/option is provided
$commonParameters = @(
    'WhatIf',
    'Confirm',
    'Verbose',
    'Debug',
    'ErrorAction',
    'WarningAction',
    'InformationAction'
)
$boundParameters = $PSBoundParameters.Keys | Where-Object { $_ -notin $commonParameters }

if (-not $boundParameters) {
    Write-Warning "No options specified.`n"
    Show-Help
    exit 1
}

# func: check for Administrator privileges
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "This script must be executed within an elevated PowerShell Administrator session."
    exit 1
}

# func: check if Winget is installed
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Warning "Winget is not installed or not found in PATH."
    exit 1
}

# preserve original ProgressPreference
$oldProgressPreference = $ProgressPreference
$ProgressPreference = 'SilentlyContinue'

# track failed installations
$failedInstalls = [System.Collections.Generic.List[string]]::new()

try {
    # func: coreapps installation
    if ($CoreApps) {
        Write-Host "`nINFO: Installing core applications..." -ForegroundColor Green

        foreach ($id in $coreAppsList) {
            if ($PSCmdlet.ShouldProcess("App-ID: $id", "Installing via Winget")) {
                $exitCode = Install-WingetPackage -Id $id
                if (-not (Test-WingetExitCode -Name $id -ExitCode $exitCode)) {
                    $failedInstalls.Add($id)
                }
            }
        }
    }

    # func: msvcredist installation
    if ($MsvcRedist) {
        Write-Host "`nINFO: Installing Visual C++ Redistributable..." -ForegroundColor Green

        if ($PSCmdlet.ShouldProcess("Visual C++ AIO (abbodi1406)", "Downloading & Installing latest release from GitHub")) {
            $exePath = $null
            try {
                $repoUrl = "https://api.github.com/repos/abbodi1406/vcredist/releases/latest"
                $headers = @{ "User-Agent" = "curl" }
                
                $release = Invoke-RestMethod -Uri $repoUrl -Headers $headers -ErrorAction Stop

                $asset = $release.assets | Where-Object { $_.name -match 'VisualCppRedist_AIO_x86_x64.exe$' } | Select-Object -First 1

                if ($asset) {
                    $exePath = Join-Path $env:TEMP $asset.name

                    Write-Host "INFO: Downloading $($asset.name) version $($release.tag_name)..." -ForegroundColor Green
                    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $exePath -ErrorAction Stop

                    if (-not (Test-Path $exePath)) {
                        throw "Download failed: File not found at target path $exePath"
                    }
                    if ((Get-Item $exePath).Length -eq 0) {
                        throw "Downloaded file is empty."
                    }

                    Write-Host "INFO: Running silent installation..." -ForegroundColor Green
                    $process = Start-Process -FilePath $exePath -ArgumentList "/y" -Wait -PassThru
                    $exitCode = $process.ExitCode

                    if ($exitCode -ne 0) {
                        throw "Installer exited with non-zero exit code: $exitCode"
                    }

                    Write-Host "INFO: Visual C++ AIO $($release.tag_name) installed successfully." -ForegroundColor Green
                } else {
                    Write-Warning "Target executable asset not found in GitHub release."
                    $failedInstalls.Add("Visual C++ Redistributable AIO")
                }
            }
            catch {
                Write-Warning "Failed to install Visual C++ AIO: $_"
                $failedInstalls.Add("Visual C++ Redistributable AIO")
            }
            finally {
                if ($exePath -and (Test-Path $exePath)) {
                    Remove-Item $exePath -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }

    # func: browser installation choices
    $browserMap = [ordered]@{
        "Google.Chrome"                     = $Chrome
        "Mozilla.Firefox"                   = $Firefox
        "Mozilla.Firefox.ESR"               = $FirefoxESR
        "Opera.Opera"                       = $Opera
        "Hibbiki.Chromium"                  = $Chromium
        "Microsoft.Edge"                    = $Edge
        "Vivaldi.Vivaldi"                   = $Vivaldi
        "Brave.Brave"                       = $Brave
        "Mozilla.Firefox.DeveloperEdition"  = $FirefoxDev
    }

    $selectedBrowsers = $browserMap.Keys | Where-Object { $browserMap[$_] }

    if ($selectedBrowsers) {
        Write-Host "`nINFO: Installing selected browsers..." -ForegroundColor Green

        foreach ($id in $selectedBrowsers) {
            if ($PSCmdlet.ShouldProcess("Browser: $id", "Installing via Winget")) {
                $exitCode = Install-WingetPackage -Id $id
                if (-not (Test-WingetExitCode -Name $id -ExitCode $exitCode)) {
                    $failedInstalls.Add($id)
                }
            }
        }
    }

    # func: custom additional applications installation
    if ($AddApps) {
        Write-Host "`nINFO: Installing additional custom applications..." -ForegroundColor Green

        $cleanAddApps = $AddApps | ForEach-Object { $_ -split ',' } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

        foreach ($rawId in $cleanAddApps) {
            $cleanId = $rawId.Trim()

            if ($PSCmdlet.ShouldProcess("Custom App-ID: $cleanId", "Installing with winget...")) {
                $exitCode = Install-WingetPackage -Id $cleanId
                if (-not (Test-WingetExitCode -Name $cleanId -ExitCode $exitCode)) {
                    if (-not $failedInstalls.Contains($cleanId)) {
                        $failedInstalls.Add($cleanId)
                    }
                }
            }
        }
    }

    # summary output
    Write-Host "`nSummary:"
    if ($failedInstalls.Count -gt 0) {
        Write-Warning "Installation process completed with errors."
        Write-Warning "The following applications failed to install:"
        foreach ($failedApp in $failedInstalls) {
            Write-Warning "  - $failedApp"
        }
    } else {
        Write-Host "INFO: All selected operations completed successfully!" -ForegroundColor Green
    }

} finally {
    # restore original ProgressPreference
    $ProgressPreference = $oldProgressPreference
}

if ($failedInstalls.Count -gt 0) {
    exit 1
}

exit 0