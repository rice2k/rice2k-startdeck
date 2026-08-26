Rice2k Startpage - Windows Setup
================================

FIXED INSTALLER BUILD
---------------------
This build fixes the Windows path-quoting error that could produce:
  Copy-Item : Illegal characters in path.
The installer now resolves its source folder internally with PowerShell
$PSScriptRoot instead of passing a trailing-backslash folder argument.

WHAT SETUP DOES
---------------
1. Creates: C:\Startpage
2. Copies index.html to: C:\Startpage\index.html
3. Detects existing browser profiles.
4. Sets the local Startpage as the homepage and browser startup page for:
   - Microsoft Edge
   - Google Chrome
   - Mozilla Firefox
   - Brave (if installed)
   - Vivaldi (if installed)
   - Opera / Opera GX (if installed)
5. Turns on the Home button in Chromium-based browsers.
6. Also updates the old Windows Internet Options homepage when that setting exists.
7. Saves original browser preference files and a restore-state file under:
   C:\Startpage\BrowserBackups\<date_time>\
8. Copies a restore utility into C:\Startpage.

INSTALL
-------
1. Extract the ENTIRE ZIP to a normal folder.
2. Close your web browsers.
3. Double-click Setup.cmd.
4. If Windows blocks creation of C:\Startpage, right-click Setup.cmd and choose
   "Run as administrator".
5. Setup opens C:\Startpage\index.html when finished so you can verify it.

If a supported browser has never been launched, it may not have a profile to
edit yet. Launch that browser once, close it, and run Setup.cmd again.

IMPORTANT: NEW TAB VS. HOMEPAGE
-------------------------------
Setup configures the browser HOMEPAGE and ON-STARTUP page. Chrome/Edge-family
New Tab pages are not forcibly replaced. Doing that reliably requires a browser
extension or enterprise/managed-browser policy, which this package intentionally
avoids so your personal browser is not marked "Managed by your organization".

RESTORE OLD BROWSER SETTINGS
----------------------------
Close all browsers, then run:
C:\Startpage\Restore_Browser_Settings.cmd

The restore utility changes only the homepage/startup settings recorded during
installation. Full original Preferences/prefs.js copies are also retained in the
BrowserBackups folder for emergency manual recovery.

NOTES
-----
- Internet access is still required for live weather, favicons, and anime release data.
- The local page itself is stored on your PC at C:\Startpage\index.html.
- Browser settings are changed only for profiles that already exist on this Windows account.
- Re-running Setup.cmd is supported and creates a new timestamped backup first.

LINK BEHAVIOR
-------------
Website links on the start page open in a new browser tab so the start page stays available in its original tab.
