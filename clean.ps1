# ==========================================
#   Temp + Registry + Disk + Browser + More
# ==========================================

# Admin elevation check
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Restarting script with Administrator privileges..." -ForegroundColor Yellow
    Start-Process powershell "-ExecutionPolicy Bypass -Command `"irm https://raw.githubusercontent.com/vik-khatkar/winclean/main/clean.ps1 | iex`"" -Verb RunAs
    exit
}

# Function to show progress
function Show-Progress {
    param([string]$Activity, [string]$Status, [int]$PercentComplete)
    Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete
}

Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "         CLEAN-UP TOOL @IMVSK v2.0        " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

$totalSteps = 12
$currentStep = 0

# ---------------------------------------------------------
# 1. TEMP FILES CLEANUP (Enhanced)
# ---------------------------------------------------------
$currentStep++
Show-Progress -Activity "Cleaning System" -Status "Removing temp files..." -PercentComplete (($currentStep/$totalSteps)*100)
Write-Host "[$currentStep/$totalSteps] Cleaning temporary files..." -ForegroundColor Yellow

$tempPaths = @(
    "$env:TEMP\*",
    "$env:LOCALAPPDATA\Temp\*",
    "C:\Windows\Temp\*",
    "C:\Windows\Prefetch\*",
    "$env:WINDIR\Logs\*",
    "$env:LOCALAPPDATA\Microsoft\Windows\WER\*"
)

Remove-Item -Path $tempPaths -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "  ✓ Temporary files cleaned" -ForegroundColor Green

# ---------------------------------------------------------
# 2. PREFETCH FILES (Explicit cleanup)
# ---------------------------------------------------------
$currentStep++
Show-Progress -Activity "Cleaning System" -Status "Cleaning Prefetch..." -PercentComplete (($currentStep/$totalSteps)*100)
Write-Host "[$currentStep/$totalSteps] Cleaning Prefetch files..." -ForegroundColor Yellow

$prefetchPath = "C:\Windows\Prefetch"
if (Test-Path $prefetchPath) {
    Remove-Item "$prefetchPath\*" -Force -ErrorAction SilentlyContinue
    Write-Host "  ✓ Prefetch files cleared" -ForegroundColor Green
}

# ---------------------------------------------------------
# 3. DISK CLEANUP (Sagerun Optimization)
# ---------------------------------------------------------
$currentStep++
Show-Progress -Activity "Cleaning System" -Status "Running Disk Cleanup..." -PercentComplete (($currentStep/$totalSteps)*100)
Write-Host "[$currentStep/$totalSteps] Running Disk Cleanup (All Options)..." -ForegroundColor Yellow

$cleanMgrKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
$handlers = Get-ChildItem $cleanMgrKey -ErrorAction SilentlyContinue

foreach ($h in $handlers) {
    $null = New-ItemProperty -Path $h.PSPath -Name "StateFlags1337" -Value 2 -PropertyType DWord -Force -ErrorAction SilentlyContinue
}

Start-Process cleanmgr.exe -ArgumentList "/sagerun:1337" -Wait -NoNewWindow
Write-Host "  ✓ Disk Cleanup completed" -ForegroundColor Green

# ---------------------------------------------------------
# 4. WINDOWS UPDATE CLEANUP
# ---------------------------------------------------------
$currentStep++
Show-Progress -Activity "Cleaning System" -Status "Cleaning Windows Updates..." -PercentComplete (($currentStep/$totalSteps)*100)
Write-Host "[$currentStep/$totalSteps] Cleaning Windows Update leftovers..." -ForegroundColor Yellow

try {
    Dism.exe /Online /Cleanup-Image /StartComponentCleanup /ResetBase | Out-Null
    Write-Host "  ✓ Component Store optimized" -ForegroundColor Green
} catch {
    Write-Host "  ✗ DISM cleanup failed (may require elevation)" -ForegroundColor Red
}

# ---------------------------------------------------------
# 5. BROWSER CLEANUP - Chrome
# ---------------------------------------------------------
$currentStep++
Show-Progress -Activity "Cleaning Browsers" -Status "Cleaning Chrome..." -PercentComplete (($currentStep/$totalSteps)*100)
Write-Host "[$currentStep/$totalSteps] Cleaning Chrome browser data..." -ForegroundColor Yellow

$chromePaths = @(
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache\*",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache\*",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Media Cache\*",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\History",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\History-journal",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cookies",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cookies-journal"
)

Remove-Item -Path $chromePaths -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "  ✓ Chrome cache and history cleaned" -ForegroundColor Green

# ---------------------------------------------------------
# 6. BROWSER CLEANUP - Edge
# ---------------------------------------------------------
$currentStep++
Show-Progress -Activity "Cleaning Browsers" -Status "Cleaning Edge..." -PercentComplete (($currentStep/$totalSteps)*100)
Write-Host "[$currentStep/$totalSteps] Cleaning Edge browser data..." -ForegroundColor Yellow

$edgePaths = @(
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache\*",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache\*",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Media Cache\*",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\History",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\History-journal",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cookies",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cookies-journal"
)

Remove-Item -Path $edgePaths -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "  ✓ Edge cache and history cleaned" -ForegroundColor Green

# ---------------------------------------------------------
# 7. BROWSER CLEANUP - Firefox
# ---------------------------------------------------------
$currentStep++
Show-Progress -Activity "Cleaning Browsers" -Status "Cleaning Firefox..." -PercentComplete (($currentStep/$totalSteps)*100)
Write-Host "[$currentStep/$totalSteps] Cleaning Firefox browser data..." -ForegroundColor Yellow

$firefoxProfiles = Get-ChildItem "$env:APPDATA\Mozilla\Firefox\Profiles\*.default*" -ErrorAction SilentlyContinue
foreach ($profile in $firefoxProfiles) {
    $firefoxPaths = @(
        "$profile\cache2\*",
        "$profile\thumbnails\*",
        "$profile\places.sqlite",
        "$profile\places.sqlite-wal",
        "$profile\cookies.sqlite",
        "$profile\cookies.sqlite-wal"
    )
    Remove-Item -Path $firefoxPaths -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host "  ✓ Firefox cache and history cleaned" -ForegroundColor Green

# ---------------------------------------------------------
# 8. RECENT DOCUMENTS CLEANUP
# ---------------------------------------------------------
$currentStep++
Show-Progress -Activity "Cleaning System" -Status "Cleaning Recent Documents..." -PercentComplete (($currentStep/$totalSteps)*100)
Write-Host "[$currentStep/$totalSteps] Cleaning Recent Documents..." -ForegroundColor Yellow

$recentPaths = @(
    "$env:APPDATA\Microsoft\Windows\Recent\*",
    "$env:APPDATA\Microsoft\Windows\Recent\AutomaticDestinations\*",
    "$env:APPDATA\Microsoft\Windows\Recent\CustomDestinations\*"
)

Remove-Item -Path $recentPaths -Recurse -Force -ErrorAction SilentlyContinue

# Clear Windows 10/11 "Quick Access" recent files
if (Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs") {
    Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs" -Name "*" -ErrorAction SilentlyContinue
}

Write-Host "  ✓ Recent documents cleared" -ForegroundColor Green

# ---------------------------------------------------------
# 9. CLIPBOARD HISTORY CLEAR
# ---------------------------------------------------------
$currentStep++
Show-Progress -Activity "Cleaning System" -Status "Clearing Clipboard..." -PercentComplete (($currentStep/$totalSteps)*100)
Write-Host "[$currentStep/$totalSteps] Clearing Clipboard History..." -ForegroundColor Yellow

# Clear current clipboard
Set-Clipboard -Value $null

# Clear Windows 10/11 clipboard history
if (Test-Path "HKCU:\Software\Microsoft\Clipboard") {
    Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Clipboard" -Name "*" -ErrorAction SilentlyContinue
}

# Stop and restart clipboard service to clear history
Stop-Process -Name "ClipboardUserServer*" -Force -ErrorAction SilentlyContinue
Stop-Process -Name "Microsoft.Windows.CloudExperienceHost*" -Force -ErrorAction SilentlyContinue

Write-Host "  ✓ Clipboard history cleared" -ForegroundColor Green

# ---------------------------------------------------------
# 10. REGISTRY CLEANUP (Run/RunOnce entries)
# ---------------------------------------------------------
$currentStep++
Show-Progress -Activity "Cleaning System" -Status "Cleaning Registry..." -PercentComplete (($currentStep/$totalSteps)*100)
Write-Host "[$currentStep/$totalSteps] Performing safe registry cleanup..." -ForegroundColor Yellow

$runPaths = @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
)

$orphanedCount = 0
foreach ($rp in $runPaths) {
    if (Test-Path $rp) {
        $key = Get-Item $rp
        foreach ($valName in $key.GetValueNames()) {
            $rawPath = $key.GetValue($valName)
            $cleanPath = if ($rawPath -match '"([^"]+)"') { $matches[1] } else { ($rawPath -split ' ')[0] }
            $expandedPath = [System.Environment]::ExpandEnvironmentVariables($cleanPath)

            if ($expandedPath -and -not (Test-Path $expandedPath)) {
                Remove-ItemProperty -Path $rp -Name $valName -Force -ErrorAction SilentlyContinue
                $orphanedCount++
            }
        }
    }
}
Write-Host "  ✓ Registry cleaned ($orphanedCount orphaned entries removed)" -ForegroundColor Green

# ---------------------------------------------------------
# 11. SCHEDULE CHKDSK
# ---------------------------------------------------------
$currentStep++
Show-Progress -Activity "Finalizing" -Status "Scheduling CHKDSK..." -PercentComplete (($currentStep/$totalSteps)*100)
Write-Host "[$currentStep/$totalSteps] Scheduling CHKDSK for next reboot..." -ForegroundColor Yellow

try {
    cmd.exe /c "echo Y|chkdsk C: /F" 2>&1 | Out-Null
    Write-Host "  ✓ CHKDSK scheduled" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Failed to schedule CHKDSK" -ForegroundColor Red
}

# ---------------------------------------------------------
# 12. CLEAR POWERSHELL HISTORY
# ---------------------------------------------------------
$currentStep++
Show-Progress -Activity "Finalizing" -Status "Clearing History..." -PercentComplete (($currentStep/$totalSteps)*100)
Write-Host "[$currentStep/$totalSteps] Clearing PowerShell history..." -ForegroundColor Yellow

try {
    # Clear current session history
    Clear-History -ErrorAction SilentlyContinue

    # Clear PSReadLine history file
    $historyPath = (Get-PSReadlineOption).HistorySavePath
    if (Test-Path $historyPath) {
        Remove-Item $historyPath -Force -ErrorAction SilentlyContinue
        New-Item -Path $historyPath -ItemType File -Force | Out-Null
    }

    # Clear internal history
    if (Get-Module PSReadLine) {
        [Microsoft.PowerShell.PSConsoleReadLine]::ClearHistory()
    }

    Write-Host "  ✓ PowerShell history cleared" -ForegroundColor Green
} catch {
    Write-Host "  ✓ History cleared (with minor warnings)" -ForegroundColor Gray
}

# ---------------------------------------------------------
# SUMMARY & EXIT
# ---------------------------------------------------------
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "           CLEANUP COMPLETE!             " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Cleaned:" -ForegroundColor Green
Write-Host "  • Temporary files" -ForegroundColor Gray
Write-Host "  • Prefetch files" -ForegroundColor Gray
Write-Host "  • Browser cache/history (Chrome, Edge, Firefox)" -ForegroundColor Gray
Write-Host "  • Recent documents" -ForegroundColor Gray
Write-Host "  • Clipboard history" -ForegroundColor Gray
Write-Host "  • Orphaned registry entries" -ForegroundColor Gray
Write-Host "  • Windows update cache" -ForegroundColor Gray
Write-Host "  • PowerShell history" -ForegroundColor Gray
Write-Host ""
Write-Host "CHKDSK scheduled for next reboot." -ForegroundColor Yellow
Write-Host ""

# Countdown to exit
for ($i = 10; $i -gt 0; $i--) {
    Write-Host "`rClosing terminal in $i seconds... " -NoNewline -ForegroundColor Gray
    Start-Sleep -Seconds 1
}

Write-Host "`n`nGoodbye! System is cleaner." -ForegroundColor Green
exit
