$ErrorActionPreference = 'Stop'
$InstallDir = 'C:\Startpage'
$StatePath = Join-Path $InstallDir 'latest-restore-state.json'
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Info([string]$Text) { Write-Host "[INFO] $Text" -ForegroundColor Cyan }
function Write-Ok([string]$Text)   { Write-Host "[ OK ] $Text" -ForegroundColor Green }
function Write-Warn([string]$Text) { Write-Host "[WARN] $Text" -ForegroundColor Yellow }

function Set-ObjectProperty {
    param($Object, [string]$Name, $Value)
    $prop = $Object.PSObject.Properties[$Name]
    if ($null -ne $prop) { $prop.Value = $Value }
    else { $Object | Add-Member -MemberType NoteProperty -Name $Name -Value $Value }
}

function Restore-ObjectProperty {
    param($Object, [string]$Name, $State)
    if ($State.Exists) {
        Set-ObjectProperty -Object $Object -Name $Name -Value $State.Value
    } else {
        $Object.PSObject.Properties.Remove($Name)
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

if (-not (Test-Path -LiteralPath $StatePath)) {
    Write-Warn "No restore state was found at $StatePath"
    Write-Warn 'Run this only after the Rice2k Startpage installer has created a backup.'
    exit 2
}

$processNames = @('chrome','msedge','firefox','brave','vivaldi','opera')
$running = @(Get-Process -Name $processNames -ErrorAction SilentlyContinue | Select-Object -ExpandProperty ProcessName -Unique)
if ($running.Count -gt 0) {
    Write-Warn ('These browsers are currently open: ' + ($running -join ', '))
    $answer = Read-Host 'Close them automatically now? Unsaved web forms could be lost. Type YES to continue'
    if ($answer -ne 'YES') {
        Write-Warn 'Nothing was restored. Close the browsers and run this again.'
        exit 3
    }
    foreach ($name in $running) {
        Get-Process -Name $name -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Seconds 2
}

$state = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
foreach ($entry in @($state.Entries)) {
    try {
        if ($entry.Type -eq 'Chromium') {
            if (-not (Test-Path -LiteralPath $entry.PreferencesPath)) {
                Write-Warn "$($entry.Browser) $($entry.Profile): Preferences file no longer exists"
                continue
            }
            $prefs = ([System.IO.File]::ReadAllText($entry.PreferencesPath)) | ConvertFrom-Json
            Restore-ObjectProperty -Object $prefs -Name 'homepage' -State $entry.Homepage
            Restore-ObjectProperty -Object $prefs -Name 'homepage_is_newtabpage' -State $entry.HomepageIsNewTab

            $browserObj = Ensure-ChildObject -Object $prefs -Name 'browser'
            Restore-ObjectProperty -Object $browserObj -Name 'show_home_button' -State $entry.ShowHomeButton
            if (-not $entry.BrowserObjectExisted -and $browserObj.PSObject.Properties.Count -eq 0) {
                $prefs.PSObject.Properties.Remove('browser')
            }

            $sessionObj = Ensure-ChildObject -Object $prefs -Name 'session'
            Restore-ObjectProperty -Object $sessionObj -Name 'restore_on_startup' -State $entry.RestoreOnStartup
            Restore-ObjectProperty -Object $sessionObj -Name 'startup_urls' -State $entry.StartupUrls
            if (-not $entry.SessionObjectExisted -and $sessionObj.PSObject.Properties.Count -eq 0) {
                $prefs.PSObject.Properties.Remove('session')
            }

            [System.IO.File]::WriteAllText($entry.PreferencesPath, ($prefs | ConvertTo-Json -Depth 100 -Compress), $Utf8NoBom)
            Write-Ok "$($entry.Browser) $($entry.Profile) restored"
        }
        elseif ($entry.Type -eq 'Firefox') {
            if (-not (Test-Path -LiteralPath $entry.PreferencesPath)) {
                Write-Warn "Firefox $($entry.Profile): prefs.js no longer exists"
                continue
            }
            $pattern = '^user_pref\("(?:browser\.startup\.homepage|browser\.startup\.page)"\s*,'
            $lines = @(Get-Content -LiteralPath $entry.PreferencesPath | Where-Object { $_ -notmatch $pattern })
            foreach ($line in @($entry.OriginalLines)) {
                if (-not [string]::IsNullOrWhiteSpace([string]$line)) { $lines += [string]$line }
            }
            [System.IO.File]::WriteAllLines($entry.PreferencesPath, [string[]]$lines, $Utf8NoBom)
            Write-Ok "Firefox $($entry.Profile) restored"
        }
        elseif ($entry.Type -eq 'Registry') {
            if ($entry.Existed) {
                Set-ItemProperty -Path $entry.RegistryPath -Name $entry.Name -Value $entry.Value -Force
            } else {
                Remove-ItemProperty -Path $entry.RegistryPath -Name $entry.Name -ErrorAction SilentlyContinue
            }
            Write-Ok 'Windows Internet Options restored'
        }
    } catch {
        Write-Warn "$($entry.Browser) $($entry.Profile) restore failed: $($_.Exception.Message)"
    }
}

Write-Host ''
Write-Info 'Original homepage/startup settings have been restored where possible.'
Write-Info "The Startpage files remain in $InstallDir. You can delete that folder manually after closing this window if you no longer want it."
exit 0
