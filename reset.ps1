# ==========================================
#                RESET TOOL @IMVSK
#       Network + Bluetooth + Input + Audio
# ==========================================

# Admin Check & Auto-Restart
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Restarting with Admin rights..." -ForegroundColor Yellow
    Start-Process powershell "-ExecutionPolicy Bypass -Command `"irm https://raw.githubusercontent.com/vik-khatkar/winclean/main/reset.ps1 | iex`"" -Verb RunAs
    exit
}

Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "                RESET TOOL    @IMVSK        " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 1. NETWORK & STACK RESET
Write-Host "`n[1/6] Resetting Network Stack..." -ForegroundColor Yellow
$commands = @(
    "netsh winsock reset",
    "netsh int ip reset",
    "netsh advfirewall reset",
    "ipconfig /flushdns",
    "netsh int tcp set global autotuninglevel=normal"
)
foreach ($cmd in $commands) {
    Write-Host " - Executing: $cmd" -ForegroundColor Gray
    Invoke-Expression $cmd | Out-Null
}

# Reset DNS to Auto for all adapters
Get-NetAdapter | ForEach-Object {
    Set-DnsClientServerAddress -InterfaceAlias $_.Name -ResetServerAddresses -ErrorAction SilentlyContinue
}
Write-Host " Network stack returned to defaults." -ForegroundColor Green

# 2. WI-FI PROFILE PURGE
Write-Host "`n[2/6] Purging saved Wi-Fi networks..." -ForegroundColor Yellow
# Fast wipe of all profiles
netsh wlan delete profile name=* i=* | Out-Null
Write-Host " All Wi-Fi profiles removed." -ForegroundColor Green

# 3. BLUETOOTH DEVICE REMOVAL
Write-Host "`n[3/6] Removing paired Bluetooth devices..." -ForegroundColor Yellow
# We target 'Bluetooth' class but exclude the controller itself to avoid hardware "disappearing"
$btDevices = Get-PnpDevice -Class 'Bluetooth' -Status 'OK' | Where-Object { $_.FriendlyName -notmatch "Radio|Adapter|Controller|Enumerator" }
foreach ($dev in $btDevices) {
    Write-Host " - Unpairing: $($dev.FriendlyName)" -ForegroundColor Gray
    pnputil /remove-device $dev.InstanceId | Out-Null
}
Write-Host " Bluetooth peripherals cleared." -ForegroundColor Green

# 4. INPUT RESET (Touchpad/Touch/Camera)
Write-Host "`n[4/6] Resetting Input & Camera..." -ForegroundColor Yellow
$inputKeys = @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\PrecisionTouchPad",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Touchpad",
    "HKCU:\Software\Microsoft\Wisp"
)
foreach ($key in $inputKeys) {
    if (Test-Path $key) {
        Remove-Item $key -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host " - Reset: $($key.Split('\')[-1])" -ForegroundColor Gray
    }
}

# 5. AUDIO & MULTIMEDIA RESET
Write-Host "`n[5/6] Resetting Audio Engine..." -ForegroundColor Yellow
$audioKeys = @(
    "HKCU:\Software\Microsoft\Multimedia\Audio",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\MMDevices"
)
foreach ($ak in $audioKeys) {
    Remove-Item $ak -Recurse -Force -ErrorAction SilentlyContinue
}
# Restart Audio Services to apply changes
Restart-Service AudioEndpointBuilder, AudioSrv -Force -ErrorAction SilentlyContinue
Write-Host " Audio settings and services reset." -ForegroundColor Green

# 6. CLEAR HISTORY
Write-Host "`n[6/6] Cleaning session history..." -ForegroundColor Yellow
Clear-History -ErrorAction SilentlyContinue
$hPath = (Get-PSReadlineOption).HistorySavePath
if (Test-Path $hPath) { Remove-Item $hPath -Force -ErrorAction SilentlyContinue }

Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host " RESET COMPLETE. SYSTEM REBOOT REQUIRED. " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# Final 10-second countdown
for ($i = 10; $i -gt 0; $i--) {
    Write-Host "`rClosing in $i seconds... " -NoNewline -ForegroundColor Gray
    Start-Sleep -Seconds 1
}
exit
