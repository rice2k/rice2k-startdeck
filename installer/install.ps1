param(
    [Parameter(Mandatory = $false)]
    [string]$SourceDir
)

$ErrorActionPreference = 'Stop'

# Setup.cmd normally does not pass SourceDir. Using $PSScriptRoot avoids a
# Windows command-line edge case where a quoted path ending in \ can leave a
# literal quote in the argument (for example: C:\Folder\"), which then makes
# Join-Path/Copy-Item fail with "Illegal characters in path."
if ([string]::IsNullOrWhiteSpace($SourceDir)) {
    $SourceDir = $PSScriptRoot
}
$SourceDir = $SourceDir.Trim().Trim('"')
if ([string]::IsNullOrWhiteSpace($SourceDir)) {
    $SourceDir = $PSScriptRoot
}
$SourceDir = [System.IO.Path]::GetFullPath($SourceDir)
$SourceIndex = Join-Path $SourceDir 'index.html'

$InstallDir = 'C:\Startpage'
$StartPagePath = Join-Path $InstallDir 'index.html'
$StartUrl = 'file:///C:/Startpage/index.html'
$Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$BackupRoot = Join-Path $InstallDir ("BrowserBackups\" + $Timestamp)
$StatePath = Join-Path $BackupRoot 'restore-state.json'
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Info([string]$Text) { Write-Host "[INFO] $Text" -ForegroundColor Cyan }
function Write-Ok([string]$Text)   { Write-Host "[ OK ] $Text" -ForegroundColor Green }
function Write-Warn([string]$Text) { Write-Host "[WARN] $Text" -ForegroundColor Yellow }

function Get-PropertyState {
    param($Object, [string]$Name)
    $prop = $Object.PSObject.Properties[$Name]
    if ($null -ne $prop) {
        return [pscustomobject]@{ Exists = $true; Value = $prop.Value }
    }
    return [pscustomobject]@{ Exists = $false; Value = $null }
}

function Set-ObjectProperty {
    param($Object, [string]$Name, $Value)
    $prop = $Object.PSObject.Properties[$Name]
    if ($null -ne $prop) {
        $prop.Value = $Value
    } else {
        $Object | Add-Member -MemberType NoteProperty -Name $Name -Value $Value
    }
}

function Ensure-ChildObject {
    param($Object, [string]$Name)
    $prop = $Object.PSObject.Properties[$Name]
    if (($null -eq $prop) -or ($null -eq $prop.Value) -or (-not ($prop.Value -is [System.Management.Automation.PSCustomObject]))) {
        Set-ObjectProperty -Object $Object -Name $Name -Value ([pscustomobject]@{})
    }
    return $Object.PSObject.Properties[$Name].Value
}

function Get-ChromiumProfiles {
    param([string]$Root)
    if (-not (Test-Path -LiteralPath $Root)) { return @() }
    return @(Get-ChildItem -LiteralPath $Root -Directory -ErrorAction SilentlyContinue | Where-Object {
        ($_.Name -eq 'Default' -or $_.Name -like 'Profile *') -and (Test-Path -LiteralPath (Join-Path $_.FullName 'Preferences'))
    })
}

function Update-ChromiumPreferences {
    param(
        [string]$BrowserName,
        [string]$PreferencesPath,
        [string]$ProfileName,
        [System.Collections.ArrayList]$StateEntries
    )

    Write-Info "$BrowserName - $ProfileName"
    $raw = [System.IO.File]::ReadAllText($PreferencesPath)
    if ([string]::IsNullOrWhiteSpace($raw)) {
        throw "Preferences file is empty: $PreferencesPath"
    }
    $prefs = $raw | ConvertFrom-Json

    $browserState = Get-PropertyState -Object $prefs -Name 'browser'
    $sessionState = Get-PropertyState -Object $prefs -Name 'session'
    $browserObj = Ensure-ChildObject -Object $prefs -Name 'browser'
    $sessionObj = Ensure-ChildObject -Object $prefs -Name 'session'

    $state = [pscustomobject]@{
        Type = 'Chromium'
        Browser = $BrowserName
        Profile = $ProfileName
        PreferencesPath = $PreferencesPath
        Homepage = Get-PropertyState -Object $prefs -Name 'homepage'
        HomepageIsNewTab = Get-PropertyState -Object $prefs -Name 'homepage_is_newtabpage'
        BrowserObjectExisted = $browserState.Exists
        ShowHomeButton = Get-PropertyState -Object $browserObj -Name 'show_home_button'
        SessionObjectExisted = $sessionState.Exists
        RestoreOnStartup = Get-PropertyState -Object $sessionObj -Name 'restore_on_startup'
        StartupUrls = Get-PropertyState -Object $sessionObj -Name 'startup_urls'
    }
    [void]$StateEntries.Add($state)

    $safeBrowser = ($BrowserName -replace '[^A-Za-z0-9_.-]', '_')
    $safeProfile = ($ProfileName -replace '[^A-Za-z0-9_.-]', '_')
    $backupDir = Join-Path $BackupRoot (Join-Path $safeBrowser $safeProfile)
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    Copy-Item -LiteralPath $PreferencesPath -Destination (Join-Path $backupDir 'Preferences.original') -Force

    Set-ObjectProperty -Object $prefs -Name 'homepage' -Value $StartUrl
    Set-ObjectProperty -Object $prefs -Name 'homepage_is_newtabpage' -Value $false
    Set-ObjectProperty -Object $browserObj -Name 'show_home_button' -Value $true
    Set-ObjectProperty -Object $sessionObj -Name 'restore_on_startup' -Value 4
    Set-ObjectProperty -Object $sessionObj -Name 'startup_urls' -Value @($StartUrl)

    $json = $prefs | ConvertTo-Json -Depth 100 -Compress
    [System.IO.File]::WriteAllText($PreferencesPath, $json, $Utf8NoBom)
    Write-Ok "$BrowserName $ProfileName configured"
}

function Update-FirefoxProfile {
    param(
        [string]$ProfilePath,
        [System.Collections.ArrayList]$StateEntries
    )

    $prefsPath = Join-Path $ProfilePath 'prefs.js'
    if (-not (Test-Path -LiteralPath $prefsPath)) { return }
    $profileName = Split-Path $ProfilePath -Leaf
    Write-Info "Mozilla Firefox - $profileName"

    $lines = @(Get-Content -LiteralPath $prefsPath -ErrorAction Stop)
    $keys = @('browser.startup.homepage', 'browser.startup.page')
    $pattern = '^user_pref\("(?:browser\.startup\.homepage|browser\.startup\.page)"\s*,'
    $originalLines = @($lines | Where-Object { $_ -match $pattern })

    [void]$StateEntries.Add([pscustomobject]@{
        Type = 'Firefox'
        Browser = 'Mozilla Firefox'
        Profile = $profileName
        PreferencesPath = $prefsPath
        OriginalLines = $originalLines
    })

    $backupDir = Join-Path $BackupRoot (Join-Path 'Mozilla_Firefox' ($profileName -replace '[^A-Za-z0-9_.-]', '_'))
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    Copy-Item -LiteralPath $prefsPath -Destination (Join-Path $backupDir 'prefs.js.original') -Force

    $newLines = @($lines | Where-Object { $_ -notmatch $pattern })
    $newLines += 'user_pref("browser.startup.homepage", "file:///C:/Startpage/index.html");'
    $newLines += 'user_pref("browser.startup.page", 1);'
    [System.IO.File]::WriteAllLines($prefsPath, [string[]]$newLines, $Utf8NoBom)
    Write-Ok "Firefox $profileName configured"
}

function Update-OperaPreferences {
    param(
        [string]$BrowserName,
        [string]$Root,
        [System.Collections.ArrayList]$StateEntries
    )
    $preferences = Join-Path $Root 'Preferences'
    if (Test-Path -LiteralPath $preferences) {
        Update-ChromiumPreferences -BrowserName $BrowserName -PreferencesPath $preferences -ProfileName (Split-Path $Root -Leaf) -StateEntries $StateEntries
    }
}

Write-Host ''
Write-Host 'Rice2k Startpage Installer' -ForegroundColor White
Write-Host '--------------------------' -ForegroundColor DarkGray
Write-Host ''

# Browsers should be closed so they do not overwrite Preferences/prefs.js at shutdown.
$processNames = @('chrome','msedge','firefox','brave','vivaldi','opera')
$running = @(Get-Process -Name $processNames -ErrorAction SilentlyContinue | Select-Object -ExpandProperty ProcessName -Unique)
if ($running.Count -gt 0) {
    Write-Warn ('These browsers are currently open: ' + ($running -join ', '))
    Write-Warn 'They must be closed before their startup settings are edited.'
    Write-Host ''
    $answer = Read-Host 'Close them automatically now? Unsaved web forms could be lost. Type YES to continue'
    if ($answer -ne 'YES') {
        Write-Warn 'Nothing was changed. Close the browsers and run Setup.cmd again.'
        exit 3
    }
    foreach ($name in $running) {
        Get-Process -Name $name -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Seconds 2
}

try {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
} catch {
    Write-Warn "Windows would not allow creation of $InstallDir"
    Write-Warn 'Right-click Setup.cmd and choose Run as administrator, then try again.'
    exit 2
}

if (-not (Test-Path -LiteralPath $SourceIndex -PathType Leaf)) {
    Write-Warn "index.html was not found at: $SourceIndex"
    Write-Warn 'Extract the entire ZIP to a normal folder, then run Setup.cmd from that extracted folder.'
    exit 4
}

New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
Copy-Item -LiteralPath $SourceIndex -Destination $StartPagePath -Force
foreach ($file in @('Setup.cmd','install.ps1','Restore_Browser_Settings.cmd','restore.ps1','Open_Startpage.cmd','README.txt','VALIDATION.txt')) {
    $src = Join-Path $SourceDir $file
    if (Test-Path -LiteralPath $src) { Copy-Item -LiteralPath $src -Destination (Join-Path $InstallDir $file) -Force }
}
Write-Ok "Start page installed to $StartPagePath"

$states = New-Object System.Collections.ArrayList
$configured = New-Object System.Collections.ArrayList

$chromiumBrowsers = @(
    @{ Name = 'Google Chrome'; Root = (Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data') },
    @{ Name = 'Microsoft Edge'; Root = (Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data') },
    @{ Name = 'Brave'; Root = (Join-Path $env:LOCALAPPDATA 'BraveSoftware\Brave-Browser\User Data') },
    @{ Name = 'Vivaldi'; Root = (Join-Path $env:LOCALAPPDATA 'Vivaldi\User Data') }
)

foreach ($browser in $chromiumBrowsers) {
    $profiles = @(Get-ChromiumProfiles -Root $browser.Root)
    if ($profiles.Count -eq 0) {
        Write-Warn "$($browser.Name): no existing browser profile found; skipped"
        continue
    }
    foreach ($profile in $profiles) {
        try {
            Update-ChromiumPreferences -BrowserName $browser.Name -PreferencesPath (Join-Path $profile.FullName 'Preferences') -ProfileName $profile.Name -StateEntries $states
            [void]$configured.Add("$($browser.Name) - $($profile.Name)")
        } catch {
            Write-Warn "$($browser.Name) $($profile.Name) could not be configured: $($_.Exception.Message)"
        }
    }
}

# Opera stores its Preferences directly in its profile folder.
$operaRoots = @(
    (Join-Path $env:APPDATA 'Opera Software\Opera Stable'),
    (Join-Path $env:APPDATA 'Opera Software\Opera GX Stable')
)
foreach ($operaRoot in $operaRoots) {
    if (Test-Path -LiteralPath (Join-Path $operaRoot 'Preferences')) {
        $operaName = if ($operaRoot -like '*Opera GX Stable') { 'Opera GX' } else { 'Opera' }
        try {
            Update-OperaPreferences -BrowserName $operaName -Root $operaRoot -StateEntries $states
            [void]$configured.Add($operaName)
        } catch {
            Write-Warn "$operaName could not be configured: $($_.Exception.Message)"
        }
    }
}

$firefoxProfilesRoot = Join-Path $env:APPDATA 'Mozilla\Firefox\Profiles'
if (Test-Path -LiteralPath $firefoxProfilesRoot) {
    $firefoxProfiles = @(Get-ChildItem -LiteralPath $firefoxProfilesRoot -Directory -ErrorAction SilentlyContinue | Where-Object {
        Test-Path -LiteralPath (Join-Path $_.FullName 'prefs.js')
    })
    foreach ($profile in $firefoxProfiles) {
        try {
            Update-FirefoxProfile -ProfilePath $profile.FullName -StateEntries $states
            [void]$configured.Add("Mozilla Firefox - $($profile.Name)")
        } catch {
            Write-Warn "Firefox $($profile.Name) could not be configured: $($_.Exception.Message)"
        }
    }
} else {
    Write-Warn 'Mozilla Firefox: no existing profile found; skipped'
}

# Legacy Windows Internet Options (for old embedded/IE-style applications).
$legacyPath = 'HKCU:\Software\Microsoft\Internet Explorer\Main'
try {
    if (Test-Path $legacyPath) {
        $oldLegacy = (Get-ItemProperty -Path $legacyPath -Name 'Start Page' -ErrorAction SilentlyContinue).'Start Page'
        [void]$states.Add([pscustomobject]@{
            Type = 'Registry'
            Browser = 'Windows Internet Options'
            RegistryPath = $legacyPath
            Name = 'Start Page'
            Existed = ($null -ne $oldLegacy)
            Value = $oldLegacy
        })
        Set-ItemProperty -Path $legacyPath -Name 'Start Page' -Value $StartUrl -Force
        [void]$configured.Add('Windows Internet Options')
        Write-Ok 'Windows Internet Options configured'
    }
} catch {
    Write-Warn "Windows Internet Options could not be configured: $($_.Exception.Message)"
}

$stateDocument = [pscustomobject]@{
    Version = 1
    Created = (Get-Date).ToString('o')
    InstallDir = $InstallDir
    StartUrl = $StartUrl
    Entries = @($states)
}
[System.IO.File]::WriteAllText($StatePath, ($stateDocument | ConvertTo-Json -Depth 100), $Utf8NoBom)
Copy-Item -LiteralPath $StatePath -Destination (Join-Path $InstallDir 'latest-restore-state.json') -Force

Write-Host ''
if ($configured.Count -gt 0) {
    Write-Ok ('Configured: ' + ($configured -join '; '))
} else {
    Write-Warn 'No existing browser profiles were found to configure.'
    Write-Warn 'Launch your browser once, close it, then run Setup.cmd again.'
}
Write-Host ''
Write-Info 'Chrome/Edge-family browsers are set to show the Home button and open the Startpage on browser startup.'
Write-Info 'Firefox is set to use the Startpage as its homepage/startup page.'
Write-Info 'Browser New Tab pages are intentionally not forced because doing that reliably requires an extension or managed-browser policy.'
Write-Info "Original browser files were backed up under $BackupRoot"
Write-Info "To restore the old homepage/startup settings later, run $InstallDir\Restore_Browser_Settings.cmd"
Write-Host ''

# Open the installed page once so the user can verify it.
Start-Process $StartPagePath
exit 0
