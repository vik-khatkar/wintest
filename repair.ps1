# ==========================================
#                REPAIR TOOL (v2.0)
#       Optimized DISM + SFC + Startup
# ==========================================

# Admin Check & Auto-Restart
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Restarting with Admin rights..." -ForegroundColor Yellow
    Start-Process powershell "-ExecutionPolicy Bypass -Command `"irm https://raw.githubusercontent.com/vik-khatkar/winclean/main/repair.ps1 | iex`"" -Verb RunAs
    exit
}

Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "                REPAIR TOOL                " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 1. VOLUME OPTIMIZATION (TRIM/DEFRAG)
Write-Host "`n[1/5] Optimizing storage volumes..." -ForegroundColor Yellow
# Running on all fixed drives simultaneously
Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' -and $_.DriveLetter } | ForEach-Object {
    Write-Host " - Optimizing $($_.DriveLetter): ($($_.FileSystemLabel))..." -ForegroundColor Gray
    Optimize-Volume -DriveLetter $_.DriveLetter -ReTrim -Defrag -Verbose -ErrorAction SilentlyContinue
}

# 2. DISM RESTORE HEALTH (The Heavy Lifter)
Write-Host "`n[2/5] Repairing Windows Image (DISM)..." -ForegroundColor Yellow
Write-Host " This may take a few minutes. Please wait..." -ForegroundColor Gray
# We skip ScanHealth and go straight to RestoreHealth to save time.
Dism.exe /Online /Cleanup-Image /RestoreHealth /NoRestart
Write-Host " DISM Repair completed." -ForegroundColor Green

# 3. SFC SCANNOW
Write-Host "`n[3/5] Verifying System Files (SFC)..." -ForegroundColor Yellow
sfc /scannow
Write-Host " SFC Scan completed." -ForegroundColor Green

# 4. STARTUP CLEANUP (Improved Logic)
Write-Host "`n[4/5] Cleaning unnecessary startup entries..." -ForegroundColor Yellow

$keepKeywords = "windows|system|intel|amd|nvidia|realtek|defender|security|asus|hp|dell|lenovo|msi|acer|ctfmon|explorer"

# Keys to check
$runKeys = @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"
)

foreach ($rk in $runKeys) {
    if (Test-Path $rk) {
        $key = Get-Item $rk
        foreach ($valName in $key.GetValueNames()) {
            $valValue = [string]$key.GetValue($valName)
            
            # Identify path and expand variables
            $cleanPath = $valValue.Split('"').Where({$_})[0].Split(' ')[0]
            $expandedPath = [System.Environment]::ExpandEnvironmentVariables($cleanPath)

            # Logic: Remove if path doesn't exist AND it's not a protected keyword
            if (-not (Test-Path $expandedPath) -and ($valName -notmatch $keepKeywords)) {
                Write-Host " - Removing Orphaned/Unknown: $valName" -ForegroundColor DarkYellow
                Remove-ItemProperty -Path $rk -Name $valName -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

# 5. DISABLE TELEMETRY TASKS
Write-Host "`n[5/5] Disabling Telemetry & Data Collection..." -ForegroundColor Yellow
$tasks = @(
    "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
    "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
    "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector"
)
foreach ($t in $tasks) {
    schtasks /Change /TN $t /DISABLE 2>$null | Out-Null
    Write-Host " - Task Disabled: $t" -ForegroundColor Gray
}

# FINAL: CLEAR HISTORY (Fixed Method)
Write-Host "`nCleaning up session history..." -ForegroundColor Yellow
Clear-History -ErrorAction SilentlyContinue
$hPath = (Get-PSReadlineOption).HistorySavePath
if (Test-Path $hPath) { Remove-Item $hPath -Force -ErrorAction SilentlyContinue }

Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host " REPAIRS FINISHED. REBOOT RECOMMENDED. " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 10 Second countdown before closing
for ($i = 10; $i -gt 0; $i--) {
    Write-Host "`rClosing in $i seconds... " -NoNewline -ForegroundColor Gray
    Start-Sleep -Seconds 1
}
exit
