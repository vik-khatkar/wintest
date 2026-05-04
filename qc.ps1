# QC Script Version 2026.5.5-IEX
# Written by Vik

$script:TempDir = "$env:TEMP\QC"
$script:CleanupDone = $false
$script:BaseUrl = "https://github.com"

function Invoke-Cleanup {
    param([bool]$exit = $false)

    if ($script:CleanupDone) { return }
    $script:CleanupDone = $true

    # Clear PowerShell history
    $historyFile = "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
    if (Test-Path $historyFile) {
        Remove-Item $historyFile -Force -ErrorAction SilentlyContinue
    }

    # Remove temp directory
    if (Test-Path $script:TempDir) {
        Remove-Item $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    if ($exit) {
        # Exit PowerShell immediately
        [System.Environment]::Exit(0)
    }
}

# Set up cleanup on script exit
$script:ExitHandler = Register-EngineEvent -SupportEvent PowerShell.Exiting -Action { Invoke-Cleanup -exit $true }

# Trap any unhandled errors
trap {
    Invoke-Cleanup
    Write-Host "`nError: $_" -ForegroundColor Red
    Write-Host "Press any key to exit..."
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Invoke-Cleanup -exit $true
}

# Function to download tools silently
function Get-Tool {
    param([string]$ToolName)

    $toolPath = Join-Path $script:TempDir $ToolName
    $toolUrl = "$script:BaseUrl/vik-khatkar/wintest/releases/download/pc-test-apps/$ToolName"

    if (-not (Test-Path $toolPath)) {
        try {
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($toolUrl, $toolPath)
        } catch {
            throw "Failed to download $ToolName"
        }
    }
    return $toolPath
}

# Function to download and execute sysinfo.ps1 with bypass
function Show-SystemInfo {
    try {
        $sysinfoPath = Join-Path $script:TempDir "sysinfo.ps1"
        $sysinfoUrl = "https://raw.githubusercontent.com/vik-khatkar/winclean/main/sysinfo.ps1"

        if (-not (Test-Path $sysinfoPath)) {
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($sysinfoUrl, $sysinfoPath)
        }

        Clear-Host
        # Execute sysinfo.ps1 with bypass execution policy
        powershell -ExecutionPolicy Bypass -File $sysinfoPath

        Write-Host ""
        Write-Host (Center-Text "Press any key to return to QC menu...") -ForegroundColor Gray
        $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    } catch {
        Write-Host (Center-Text "Error loading system info: $_") -ForegroundColor Red
        Write-Host ""
        Write-Host (Center-Text "Press any key to continue...") -ForegroundColor Gray
        $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}

# Create temp directory
if (-not (Test-Path $script:TempDir)) {
    New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null
}

# Original functions
function Center-Text {
    param ([string]$text)
    $width = $host.UI.RawUI.WindowSize.Width
    $pad = [math]::Max(0, [math]::Floor(($width - $text.Length) / 2))
    return ' ' * $pad + $text
}

function Get-SanitizedSerialNumber {
    param ([string]$SerialNumber)
    return $SerialNumber -replace '[<>\:"/\\|?*]', '_'
}

function Write-ToLog {
    param ([string]$Message, [string]$LogPath)
    $timestamp = Get-Date -Format "ddd MM/dd/yyyy HH:mm:ss.ff"
    if ($Message) {
        "$Message $timestamp" | Out-File -FilePath $LogPath -Append -ErrorAction SilentlyContinue
    }
}

function Get-WindowsVersionInfo {
    $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $osName = $osInfo.Caption
    $osBuild = $osInfo.BuildNumber
    $reg = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
    $osDisplayVersion = (Get-ItemProperty -Path $reg -ErrorAction Stop).DisplayVersion
    $osUbr = (Get-ItemProperty -Path $reg -ErrorAction Stop).UBR
    return "$osName, Version $osDisplayVersion (OS Build $osBuild.$osUbr)"
}

function Get-ActivationInfo {
    try {
        $license = Get-CimInstance -ClassName SoftwareLicensingProduct -Filter "PartialProductKey IS NOT NULL AND ApplicationID = '55c92734-d682-4d71-983e-d6ec3f16059f'" -ErrorAction SilentlyContinue |
            Where-Object { $_.LicenseStatus -ne $null } |
            Select-Object -First 1
        if ($license) {
            $status = switch ($license.LicenseStatus) {
                0 { "Unlicensed" }
                1 { "Licensed" }
                2 { "OOB Grace" }
                3 { "OOT Grace" }
                4 { "Non-Genuine Grace" }
                5 { "Notification" }
                6 { "Extended Grace" }
                default { "Unknown" }
            }
            $partialKey = if ($license.PartialProductKey) { $license.PartialProductKey } else { "Unavailable" }
        } else {
            $status = "Unknown"
            $partialKey = "Unavailable"
        }
        return @{
            Status = $status
            ProductKey = if ($partialKey -ne "Unavailable") { "***-***-$partialKey" } else { "Unavailable" }
        }
    } catch {
        return @{
            Status = "Unknown"
            ProductKey = "Unavailable"
        }
    }
}

function Get-MSDMInfo {
    try {
        $sls = Get-CimInstance -ClassName SoftwareLicensingService -ErrorAction Stop
        $msdmKey = $sls.OA3xOriginalProductKey
        if ($msdmKey -and $msdmKey.Trim() -ne "") {
            return @{
                Injected = "Yes"
                Key = $msdmKey.Trim()
            }
        } else {
            return @{
                Injected = "No"
                Key = "N/A"
            }
        }
    } catch {
        return @{
            Injected = "No"
            Key = "N/A"
        }
    }
}

function Clear-KeyBuffer {
    while ($host.UI.RawUI.KeyAvailable) {
        $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}

function Show-SystemInfoHeader {
    $headerText = "SN#: $script:serialNumber  Make: $script:make  Model: $script:model  RAM: $script:ramGB GB  CPU: $script:cpuName"
    Write-Host ""
    Write-Host ""
    Write-Host (Center-Text $headerText) -ForegroundColor Green
    Write-Host ""
}

# Function to show startup menu
function Show-StartupMenu {
    Clear-Host
    Write-Host ""
    Write-Host (Center-Text "STARTUP OPTIONS @IMVSK") -ForegroundColor Cyan
    Write-Host (Center-Text "==========================") -ForegroundColor Cyan
    Write-Host ""
    Write-Host (Center-Text "Run QC Test: Press Any Key") -ForegroundColor Green
    Write-Host (Center-Text "Advanced Menu: Press 1") -ForegroundColor Green
    Write-Host ""

    $key = $host.UI.RawUI.ReadKey("IncludeKeyDown,NoEcho")

    if ($key.Character -eq '1') {
        $runFullQCFromMenu = Show-TestMenu
        return $runFullQCFromMenu
    }
    return $true  # Return true to run full QC when any other key is pressed
}

# Function to show test selection menu
function Show-TestMenu {
    do {
        Clear-Host
        Write-Host ""
        Write-Host (Center-Text "SELECT TEST TO RUN") -ForegroundColor Cyan
        Write-Host (Center-Text "==================") -ForegroundColor Cyan
        Write-Host ""
        Write-Host (Center-Text "1. BATTERY TEST") -ForegroundColor Green
        Write-Host (Center-Text "2. LCD DEAD PIXEL TEST") -ForegroundColor Green
        Write-Host (Center-Text "3. TOUCH SCREEN TEST") -ForegroundColor Green
        Write-Host (Center-Text "4. KEYBOARD TEST") -ForegroundColor Green
        Write-Host (Center-Text "5. NETWORK TEST (WiFi/LAN/Bluetooth)") -ForegroundColor Green
        Write-Host (Center-Text "6. SYSTEM INFO") -ForegroundColor Green
        Write-Host (Center-Text "7. RUN QC TEST BROWSER BASED") -ForegroundColor Green
        Write-Host (Center-Text "8. FOR ADVANCED MENU") -ForegroundColor Green
        Write-Host (Center-Text "0. EXIT") -ForegroundColor Red
        Write-Host ""
        Write-Host (Center-Text "Enter your choice : ") -ForegroundColor Yellow -NoNewline

        $choice = $host.UI.RawUI.ReadKey("IncludeKeyDown,NoEcho").Character

        switch ($choice) {
            '1' {
                Run-BatteryTest
                Write-Host (Center-Text "Press any key to return to menu...") -ForegroundColor Gray
                $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            '2' {
                Run-LCDTest
                Write-Host (Center-Text "Press any key to return to menu...") -ForegroundColor Gray
                $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            '3' {
                Run-TouchScreenTest
                Write-Host (Center-Text "Press any key to return to menu...") -ForegroundColor Gray
                $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            '4' {
                Run-KeyboardTest
                Write-Host (Center-Text "Press any key to return to menu...") -ForegroundColor Gray
                $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            '5' {
                Run-NetworkTest
                Write-Host (Center-Text "Press any key to return to menu...") -ForegroundColor Gray
                $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            '6' {
                Show-SystemInfo
                Write-Host (Center-Text "Press any key to return to menu...") -ForegroundColor Gray
                $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            '7' {
                Run-BrowserQCTest
                Write-Host (Center-Text "Press any key to return to menu...") -ForegroundColor Gray
                $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            '8' {
                irm https://raw.githubusercontent.com/vik-khatkar/winclean/main/menu.ps1 | iex
#	        Start-Process powershell -ArgumentList "-NoLogo -NoProfile -ExecutionPolicy Bypass -Command `"irm https://raw.githubusercontent.com/vik-khatkar/winclean/main/menu.ps1 | iex`""
                Write-Host (Center-Text "Press any key to return to menu...") -ForegroundColor Gray
                $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            '0' {
                Invoke-Cleanup -exit $true # Exit immediately
            }
            default {
                Write-Host "Invalid choice, please try again..."
                Start-Sleep -Seconds 2
            }
        }
    } while ($choice -ne '0')

}

# Individual test functions
function Run-BatteryTest {
    Clear-Host
    Show-SystemInfoHeader
    Write-Host ""
    Write-Host (Center-Text "BATTERY TEST") -ForegroundColor Cyan
    Write-Host ""
    try {
        $batteryAppPath = Get-Tool -ToolName "BatteryApplication.exe"
        Write-Host (Center-Text "Launching Battery Test...") -ForegroundColor Gray
        $process = Start-Process -FilePath $batteryAppPath -PassThru -ErrorAction Stop
        $process.WaitForExit()
    } catch {
        Write-Host (Center-Text "Error launching Battery Test: $_") -ForegroundColor Red
        Write-Host ""
    }
}

function Run-LCDTest {
    Clear-Host
    Show-SystemInfoHeader
    Write-Host ""
    Write-Host (Center-Text "LCD DEAD PIXEL TEST") -ForegroundColor Cyan
    Write-Host ""
    try {
        $deadPixelPath = Get-Tool -ToolName "DeadPixelFinder.exe"
        Write-Host (Center-Text "Launching LCD Test...") -ForegroundColor Gray
        $process = Start-Process -FilePath $deadPixelPath -PassThru -ErrorAction Stop
        $process.WaitForExit()
    } catch {
        Write-Host (Center-Text "Error launching LCD Test: $_") -ForegroundColor Red
        Write-Host ""
    }
}

function Run-TouchScreenTest {
    Clear-Host
    Show-SystemInfoHeader
    Write-Host ""
    Write-Host (Center-Text "TOUCH SCREEN TEST") -ForegroundColor Cyan
    Write-Host ""
        try {
            $touchScreenPath = Get-Tool -ToolName "TouchScreenTester.exe"
            Write-Host (Center-Text "Launching Touch Screen Test...") -ForegroundColor Gray
            $process = Start-Process -FilePath $touchScreenPath -PassThru -ErrorAction Stop
            $process.WaitForExit()
        } catch {
            Write-Host (Center-Text "Error launching Touch Screen Test: $_") -ForegroundColor Red
            Write-Host ""
        }
}

function Run-KeyboardTest {
    Clear-Host
    Show-SystemInfoHeader
    Write-Host ""
    Write-Host (Center-Text "KEYBOARD TEST") -ForegroundColor Cyan
    Write-Host ""
    try {
        $keyboardPath = Get-Tool -ToolName "keyboardtest.exe"
        Write-Host (Center-Text "Launching Keyboard Test...") -ForegroundColor Gray
        $process = Start-Process -FilePath $keyboardPath -PassThru -ErrorAction Stop
        $process.WaitForExit()
    } catch {
        Write-Host (Center-Text "Error launching Keyboard Test: $_") -ForegroundColor Red
        Write-Host ""
    }
}

function Run-BrowserQCTest {
    Clear-Host
    Show-SystemInfoHeader
    Write-Host ""
    Write-Host (Center-Text "QC BROWSER TEST") -ForegroundColor Cyan
    Write-Host ""

    try {
        Write-Host (Center-Text "Launching QC Test In Edge...") -ForegroundColor Gray

        $edgePath = "msedge.exe"
        $url = "https://pctest.imvsk.ca/"

        Start-Process $edgePath -ArgumentList "--inprivate", $url -ErrorAction Stop
    }
    catch {
        Write-Host (Center-Text "Error launching QC Browser Test: $_") -ForegroundColor Red
        Write-Host ""
    }
}

function Run-NetworkTest {
    Clear-Host
    Show-SystemInfoHeader
    Write-Host ""
    Write-Host (Center-Text "NETWORK TEST") -ForegroundColor Cyan
    Write-Host ""
    try {
        $processes = @()

        # Launch Bluetooth Scanner
        $bluetoothPath = Get-Tool -ToolName "BluetoothScanner.exe"
        Write-Host (Center-Text "Launching Bluetooth Scanner...") -ForegroundColor Gray
        $processes += Start-Process -FilePath $bluetoothPath -PassThru -ErrorAction Stop

        # Launch Ping View
        $pingPath = Get-Tool -ToolName "PingView.exe"
        Write-Host (Center-Text "Launching Ping View...") -ForegroundColor Gray
        $processes += Start-Process -FilePath $pingPath -PassThru -ErrorAction Stop

        # Launch Edge for video test
        Write-Host (Center-Text "Launching Edge Browser...") -ForegroundColor Gray
        $processes += Start-Process -FilePath "msedge.exe" -ArgumentList "-inPrivate", "https://www.youtube.com/watch?v=vCbYim764zQ" -PassThru -ErrorAction Stop

        Write-Host ""
        Write-Host (Center-Text "Network tools launched. Close them when done testing.") -ForegroundColor Yellow
        Write-Host (Center-Text "Press any key to continue after closing...") -ForegroundColor Gray
        $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

        foreach ($process in $processes) {
            if (-not $process.HasExited) {
                $process.Kill()
            }
        }
    } catch {
        Write-Host (Center-Text "Error launching Network Test: $_") -ForegroundColor Red
        Write-Host ""
    }
}

# Main script execution
try {
    # Set console colors
    $host.UI.RawUI.BackgroundColor = "DarkGray"
    Clear-Host
    $host.UI.RawUI.WindowTitle = "QC Check Tool @IMVSK"

    # Get system info
    $script:serialNumber = (Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue).SerialNumber
    if (-not $script:serialNumber) {
        $script:serialNumber = "UNKNOWN"
    }

    $sanitizedSerial = Get-SanitizedSerialNumber -SerialNumber $script:serialNumber
    $logFilePath = "C:\Users\Public\Documents\$sanitizedSerial.log"

    # Ensure log file exists
    if (-not (Test-Path $logFilePath)) {
        New-Item -Path $logFilePath -ItemType File -Force -ErrorAction SilentlyContinue | Out-Null
    }

    "" | Out-File -FilePath $logFilePath -Append -ErrorAction SilentlyContinue
    Write-ToLog -Message "START:" -LogPath $logFilePath

    $cs = Get-CimInstance Win32_ComputerSystem
    $script:make = $cs.Manufacturer
    $script:model = $cs.Model
    $ramModules = Get-CimInstance -ClassName Win32_PhysicalMemory -ErrorAction SilentlyContinue
    $script:ramGB = [math]::Round(($ramModules | Measure-Object -Property Capacity -Sum).Sum / 1GB, 0)
    $cpuInfo = Get-CimInstance -ClassName Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
    $script:cpuName = if ($cpuInfo) { $cpuInfo.Name.Trim() } else { "N/A" }

    # Show startup menu
    $runFullQC = Show-StartupMenu

    if ($runFullQC) {
        # Block 1: Client Complaint
        Clear-Host
        Show-SystemInfoHeader
        Write-Host ""
        Write-Host (Center-Text "!!! IMPORTANT: READ THE CLIENT'S COMPLAINT CAREFULLY !!!") -ForegroundColor Yellow
        Write-Host (Center-Text "!!! VERIFY THAT ALL REPORTED ISSUES HAVE BEEN FULLY RESOLVED !!!") -ForegroundColor Yellow
        Write-Host ""
        Write-Host (Center-Text "If any issues persist, document them and escalate before proceeding.") -ForegroundColor Yellow
        Write-Host ""
        Write-Host (Center-Text "Press any key to continue...") -ForegroundColor Gray
        $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Clear-KeyBuffer

        # Block 2: Verify Make, Model, Serial
        Clear-Host
        Show-SystemInfoHeader
        Write-Host ""
        Write-Host (Center-Text "Verify that the Make, Model, and Serial Number match those listed in SMARTS and on the unit's bottom case label.") -ForegroundColor Cyan
        Write-Host (Center-Text "Mismatch could indicate incorrect unit or labeling error - double-check now.") -ForegroundColor Cyan
        Write-Host ""
        Write-Host (Center-Text "Make: $script:make") -ForegroundColor Yellow
        Write-Host (Center-Text "Model: $script:model") -ForegroundColor Yellow
        Write-Host (Center-Text "Serial Number: $script:serialNumber") -ForegroundColor Yellow
        Write-Host ""
        Write-Host (Center-Text "Press any key to continue...") -ForegroundColor Gray
        $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Clear-KeyBuffer

        # Block 3: Assembly and Screws
        Clear-Host
        Show-SystemInfoHeader
        Write-Host ""
        Write-Host (Center-Text "*** INSPECT ASSEMBLY AND CHECK FOR MISSING SCREWS ***") -ForegroundColor Yellow
        Write-Host (Center-Text "Ensure all components are securely assembled. Look for loose parts, gaps, or missing hardware.") -ForegroundColor Yellow
        Write-Host ""
        Write-Host (Center-Text "Press any key to continue...") -ForegroundColor Gray
        $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Clear-KeyBuffer

        # Block 4: Activation / MSDM
        Clear-Host
        Show-SystemInfoHeader
        Write-Host ""
        $windowsVersion = Get-WindowsVersionInfo
        $osName = ($windowsVersion -split ",")[0].Trim()
        $activation = Get-ActivationInfo
        $msdm = Get-MSDMInfo
        $statusColor = if ($activation.Status -eq "Licensed") { "Green" } else { "Red" }

        Write-Host (Center-Text "Windows Activation Information") -ForegroundColor Cyan
        Write-Host ""
        Write-Host (Center-Text "License Status: $($activation.Status)") -ForegroundColor $statusColor
        Write-Host (Center-Text "Product Key: $($activation.ProductKey)") -ForegroundColor Green
        Write-Host ""
        Write-Host (Center-Text "MSDM Injected: $($msdm.Injected)") -ForegroundColor Cyan
        Write-Host (Center-Text "MSDM Key: $($msdm.Key)") -ForegroundColor Cyan
        Write-Host ""
        Write-Host (Center-Text "If status is not 'Licensed', investigate activation issues.") -ForegroundColor Cyan
        Write-Host (Center-Text "Windows Version: $windowsVersion") -ForegroundColor Green
        Write-Host ""

        if ($osName -match "Windows 10") {
            Write-Host (Center-Text "Please inform the client that Microsoft will no longer support Windows 10 after October 14, 2025.") -ForegroundColor Red
            Write-Host (Center-Text "Recommend upgrading to Windows 11 if the hardware supports it.") -ForegroundColor Red
            Write-Host ""
        }

        try {
            Write-Host (Center-Text "Launching Activation Settings... Please wait.") -ForegroundColor Gray
            Start-Process "ms-settings:activation"
            Write-Host ""
            Write-Host (Center-Text "Review activation status in the settings window, then close it when done.") -ForegroundColor Yellow
        } catch {
            Write-Host (Center-Text "Error launching Activation Settings: $_") -ForegroundColor Red
        }

        Write-Host ""
        Write-Host (Center-Text "Press any key to continue...") -ForegroundColor Gray
        $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Clear-KeyBuffer

        Write-ToLog -Message "Activation: Status=$($activation.Status); ProductKey=$($activation.ProductKey)" -LogPath $logFilePath
        Write-ToLog -Message "WindowsVersion: $windowsVersion" -LogPath $logFilePath

        # Block 5: Disk Management
        Clear-Host
        Show-SystemInfoHeader
        Write-Host ""
        Write-Host (Center-Text "DISK MANAGEMENT") -ForegroundColor Cyan
        Write-Host (Center-Text "---------------") -ForegroundColor Cyan
        Write-Host ""
        Write-Host (Center-Text "- Ensure all partitions are fully expanded and healthy.") -ForegroundColor Yellow
        Write-Host (Center-Text "- Verify all disks are visible and no errors are present.") -ForegroundColor Yellow
        Write-Host (Center-Text "If issues found, resize or repair as needed.") -ForegroundColor Yellow
        Write-Host ""
        Write-Host (Center-Text "Press any key to continue...") -ForegroundColor Gray
        $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Clear-KeyBuffer

        try {
            Write-Host (Center-Text "Launching Disk Management... Please wait.") -ForegroundColor Gray
            $process = Start-Process -FilePath "diskmgmt.msc" -PassThru -ErrorAction Stop
            Write-ToLog -Message "Disk Management: Launched" -LogPath $logFilePath
            $process.WaitForExit()
            Write-ToLog -Message "Disk Management: Closed" -LogPath $logFilePath
        } catch {
            Write-ToLog -Message "Failed to launch Disk Management: $_" -LogPath $logFilePath
            Write-Host (Center-Text "Error launching Disk Management: $_") -ForegroundColor Red
            Write-Host ""
            Write-Host (Center-Text "Press any key to continue...") -ForegroundColor Gray
            $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            Clear-KeyBuffer
        }

        # Block 6: USB and SD Ports
        Clear-Host
        Show-SystemInfoHeader
        Write-Host ""
        Write-Host (Center-Text "TEST ALL USB AND SD CARD PORTS") -ForegroundColor Cyan
        Write-Host (Center-Text "------------------------------") -ForegroundColor Cyan
        Write-Host ""
        Write-Host (Center-Text "- Ensure USB devices remain connected without disconnecting.") -ForegroundColor Yellow
        Write-Host (Center-Text "- Check that ports are not loose or damaged.") -ForegroundColor Yellow
        Write-Host (Center-Text "Test with multiple devices if possible.") -ForegroundColor Yellow
        Write-Host ""
        Write-Host (Center-Text "Press any key to continue...") -ForegroundColor Gray
        $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Clear-KeyBuffer

        try {
            $usbTreeViewPath = Get-Tool -ToolName "UsbTreeView.exe"
            Write-Host (Center-Text "Launching USBTreeView... Please wait.") -ForegroundColor Gray
            $process = Start-Process -FilePath $usbTreeViewPath -PassThru -ErrorAction Stop
            Write-ToLog -Message "USB: Launched UsbTreeView" -LogPath $logFilePath
            $process.WaitForExit()
            Write-ToLog -Message "USB: UsbTreeView Closed" -LogPath $logFilePath
        } catch {
            Write-ToLog -Message "Failed to launch USBTreeView: $_" -LogPath $logFilePath
            Write-Host (Center-Text "Error launching USBTreeView: $_") -ForegroundColor Red
            Write-Host ""
            Write-Host (Center-Text "Press any key to continue...") -ForegroundColor Gray
            $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            Clear-KeyBuffer
        }

        # Block 7: Device Manager
        Clear-Host
        Show-SystemInfoHeader
        Write-Host ""
        Write-Host (Center-Text "DEVICE MANAGER") -ForegroundColor Cyan
        Write-Host (Center-Text "--------------") -ForegroundColor Cyan
        Write-Host ""
        Write-Host (Center-Text "- Scan for any missing or faulty drivers (look for yellow exclamation marks).") -ForegroundColor Yellow
        Write-Host (Center-Text "Update or install drivers if necessary.") -ForegroundColor Yellow
        Write-Host ""
        Write-Host (Center-Text "Press any key to continue...") -ForegroundColor Gray
        $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Clear-KeyBuffer

        try {
            Write-Host (Center-Text "Launching Device Manager... Please wait.") -ForegroundColor Gray
            $process = Start-Process -FilePath "devmgmt.msc" -PassThru -ErrorAction Stop
            Write-ToLog -Message "Drivers: Launched Device Manager" -LogPath $logFilePath
            $process.WaitForExit()
            Write-ToLog -Message "Drivers: Device Manager Closed" -LogPath $logFilePath
        } catch {
            Write-ToLog -Message "Failed to launch Device Manager: $_" -LogPath $logFilePath
            Write-Host (Center-Text "Error launching Device Manager: $_") -ForegroundColor Red
            Write-Host ""
            Write-Host (Center-Text "Press any key to continue...") -ForegroundColor Gray
            $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            Clear-KeyBuffer
        }

        # Block 8: LED Test
        Clear-Host
        Show-SystemInfoHeader
        Write-Host ""
        Write-Host (Center-Text "LED TEST") -ForegroundColor Cyan
        Write-Host (Center-Text "--------") -ForegroundColor Cyan
        Write-Host ""
        Write-Host (Center-Text "- Verify all LEDs function correctly (e.g., power, charging, battery, touchpad).") -ForegroundColor Yellow
        Write-Host (Center-Text "Toggle states to test (e.g., plug/unplug charger).") -ForegroundColor Yellow
        Write-Host ""
        Write-Host (Center-Text "Press any key to continue...") -ForegroundColor Gray
        $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Clear-KeyBuffer
        Write-ToLog -Message "LEDs:" -LogPath $logFilePath

        # Block 9: AC Adapter and Battery Test
        Clear-Host
        Show-SystemInfoHeader
        Write-Host ""
        Write-Host (Center-Text "TEST AC ADAPTER AND BATTERY") -ForegroundColor Cyan
        Write-Host (Center-Text "---------------------------") -ForegroundColor Cyan
        Write-Host ""
        Write-Host (Center-Text "- Confirm the AC adapter charges the battery properly.") -ForegroundColor Yellow
        Write-Host (Center-Text "- Check if the adapter port is loose or damaged.") -ForegroundColor Yellow
        Write-Host (Center-Text "- Ensure battery wear level is below 20% (replace if higher).") -ForegroundColor Yellow
        Write-Host ""
        Write-Host (Center-Text "Press any key to continue...") -ForegroundColor Gray
        $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Clear-KeyBuffer

        try {
            $batteryAppPath = Get-Tool -ToolName "BatteryApplication.exe"
            Write-Host (Center-Text "Launching Battery Application... Please wait.") -ForegroundColor Gray
            $process = Start-Process -FilePath $batteryAppPath -PassThru -ErrorAction Stop
            Write-ToLog -Message "Battery: Launched BatteryApplication" -LogPath $logFilePath
            $process.WaitForExit()
            Write-ToLog -Message "Battery: BatteryApplication Closed" -LogPath $logFilePath
        } catch {
            Write-ToLog -Message "Failed to launch BatteryApplication: $_" -LogPath $logFilePath
            Write-Host (Center-Text "Error launching BatteryApplication: $_") -ForegroundColor Red
            Write-Host ""
            Write-Host (Center-Text "Press any key to continue...") -ForegroundColor Gray
            $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            Clear-KeyBuffer
        }

        # Block 10: LCD Test
        Clear-Host
        Show-SystemInfoHeader
        Write-Host ""
        Write-Host (Center-Text "TEST THE LCD PANEL") -ForegroundColor Cyan
        Write-Host (Center-Text "------------------") -ForegroundColor Cyan
        Write-Host ""
        Write-Host (Center-Text "- Adjust and test brightness levels for consistency.") -ForegroundColor Yellow
        Write-Host (Center-Text "- Inspect LCD cable connections for security.") -ForegroundColor Yellow
        Write-Host (Center-Text "- Look for dead pixels, lines, or discoloration.") -ForegroundColor Yellow
        Write-Host ""
        Write-Host (Center-Text "Press any key to continue...") -ForegroundColor Gray
        $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Clear-KeyBuffer

        try {
            $deadPixelPath = Get-Tool -ToolName "DeadPixelFinder.exe"
            Write-Host (Center-Text "Launching Dead Pixel Finder... Please wait.") -ForegroundColor Gray
            $process = Start-Process -FilePath $deadPixelPath -PassThru -ErrorAction Stop
            Write-ToLog -Message "LCD: Launched DeadPixelFinder" -LogPath $logFilePath
            $process.WaitForExit()
            Write-ToLog -Message "LCD: DeadPixelFinder Closed" -LogPath $logFilePath
        } catch {
            Write-ToLog -Message "Failed to launch DeadPixelFinder: $_" -LogPath $logFilePath
            Write-Host (Center-Text "Error launching DeadPixelFinder: $_") -ForegroundColor Red
            Write-Host ""
            Write-Host (Center-Text "Press any key to continue...") -ForegroundColor Gray
            $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            Clear-KeyBuffer
        }

        # Block 11: Touch Screen Test
        Clear-Host
        Show-SystemInfoHeader
        Write-Host ""
        Write-Host (Center-Text "TOUCH SCREEN TEST") -ForegroundColor Cyan
        Write-Host (Center-Text "-----------------") -ForegroundColor Cyan
        Write-Host ""
        Write-Host (Center-Text "- Test touch responsiveness across the entire screen.") -ForegroundColor Yellow
        Write-Host (Center-Text "- Check for dead spots, lag, or inaccurate touches.") -ForegroundColor Yellow
        Write-Host (Center-Text "If not a touch screen unit, skip the tool launch.") -ForegroundColor Yellow
        Write-Host ""

        Write-Host (Center-Text "Is this unit equipped with a Touch Screen? (y/n): ") -ForegroundColor Gray -NoNewline
        $keyChar = $host.UI.RawUI.ReadKey("IncludeKeyDown,NoEcho").Character
        $key = $keyChar.ToString().ToLower()
        Write-Host $key
        Clear-KeyBuffer

        if ($key -eq 'y') {
            try {
                $touchScreenPath = Get-Tool -ToolName "TouchScreenTester.exe"
                Write-Host (Center-Text "Launching Touch Screen Tester... Please wait.") -ForegroundColor Gray
                $process = Start-Process -FilePath $touchScreenPath -PassThru -ErrorAction Stop
                Write-ToLog -Message "Touchscreen: Launched TouchScreenTester" -LogPath $logFilePath
                $process.WaitForExit()
                Write-ToLog -Message "Touchscreen: TouchScreenTester Closed" -LogPath $logFilePath
            } catch {
                Write-ToLog -Message "Failed to launch TouchScreenTester: $_" -LogPath $logFilePath
                Write-Host (Center-Text "Error launching TouchScreenTester: $_") -ForegroundColor Red
                Write-Host ""
                Write-Host (Center-Text "Press any key to continue...") -ForegroundColor Gray
                $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                Clear-KeyBuffer
            }
        }

        # Block 12: Touchpad Test
        Clear-Host
        Show-SystemInfoHeader
        Write-Host ""
        Write-Host (Center-Text "TOUCHPAD TEST") -ForegroundColor Cyan
        Write-Host (Center-Text "-------------") -ForegroundColor Cyan
        Write-Host ""
        Write-Host (Center-Text "- Test scrolling, multi-finger gestures, and clicking.") -ForegroundColor Yellow
        Write-Host (Center-Text "- Verify the touchpad enable/disable function works.") -ForegroundColor Yellow
        Write-Host (Center-Text "Check for sensitivity issues or hardware faults.") -ForegroundColor Yellow
        Write-Host ""
        Write-Host (Center-Text "Press any key to continue...") -ForegroundColor Gray
        $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Clear-KeyBuffer
        Write-ToLog -Message "Mouse:" -LogPath $logFilePath

        # Block 13: Keyboard Test
        Clear-Host
        Show-SystemInfoHeader
        Write-Host ""
        Write-Host (Center-Text "KEYBOARD TEST") -ForegroundColor Cyan
        Write-Host (Center-Text "-------------") -ForegroundColor Cyan
        Write-Host ""
        Write-Host (Center-Text "- Test all keys, including media keys and function keys.") -ForegroundColor Yellow
        Write-Host (Center-Text "- Verify the fingerprint reader (if present) functions correctly.") -ForegroundColor Yellow
        Write-Host (Center-Text "Look for stuck keys or non-responsive areas.") -ForegroundColor Yellow
        Write-Host ""
        Write-Host (Center-Text "Press any key to continue...") -ForegroundColor Gray
        $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Clear-KeyBuffer

        try {
            $keyboardPath = Get-Tool -ToolName "keyboardtest.exe"
            Write-Host (Center-Text "Launching Keyboard Test... Please wait.") -ForegroundColor Gray
            $process = Start-Process -FilePath $keyboardPath -PassThru -ErrorAction Stop
            Write-ToLog -Message "Keyboard: Launched KeyboardTest" -LogPath $logFilePath
            $process.WaitForExit()
            Write-ToLog -Message "Keyboard: KeyboardTest Closed" -LogPath $logFilePath
        } catch {
            Write-ToLog -Message "Failed to launch KeyboardTest: $_" -LogPath $logFilePath
            Write-Host (Center-Text "Error launching Keyboard Test: $_") -ForegroundColor Red
            Write-Host ""
            Write-Host (Center-Text "Press any key to continue...") -ForegroundColor Gray
            $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            Clear-KeyBuffer
        }

        # Block 14: Sound Test
        Clear-Host
        Show-SystemInfoHeader
        Write-Host ""
        Write-Host (Center-Text "SOUND TEST") -ForegroundColor Cyan
        Write-Host (Center-Text "----------") -ForegroundColor Cyan
        Write-Host ""
        Write-Host (Center-Text "- Test speakers, headphones, and microphone for clear audio.") -ForegroundColor Yellow
        Write-Host (Center-Text "- Check volume levels and any distortion.") -ForegroundColor Yellow
        Write-Host (Center-Text "Use test tones or recordings to verify.") -ForegroundColor Yellow
        Write-Host ""
        Write-Host (Center-Text "Press any key to continue...") -ForegroundColor Gray
        $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Clear-KeyBuffer

        try {
            Write-Host (Center-Text "Launching Sound Settings... Please wait.") -ForegroundColor Gray
            $process = Start-Process -FilePath "mmsys.cpl" -PassThru -ErrorAction Stop
            Write-ToLog -Message "Audio: Launched Sound Settings" -LogPath $logFilePath
            $process.WaitForExit()
            Write-ToLog -Message "Audio: Sound Settings Closed" -LogPath $logFilePath
        } catch {
            Write-ToLog -Message "Failed to launch Sound Settings: $_" -LogPath $logFilePath
            Write-Host (Center-Text "Error launching Sound Settings: $_") -ForegroundColor Red
            Write-Host ""
            Write-Host (Center-Text "Press any key to continue...") -ForegroundColor Gray
            $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            Clear-KeyBuffer
        }

        # Block 15: Network Test
        Clear-Host
        Show-SystemInfoHeader
        Write-Host ""
        Write-Host (Center-Text "TEST WIFI, LAN, AND BLUETOOTH") -ForegroundColor Cyan
        Write-Host (Center-Text "-----------------------------") -ForegroundColor Cyan
        Write-Host ""
        Write-Host (Center-Text "- Ensure Bluetooth devices are detected and pair correctly.") -ForegroundColor Yellow
        Write-Host (Center-Text "- Verify WiFi connection stability and strong signal strength.") -ForegroundColor Yellow
        Write-Host (Center-Text "- Test LAN if applicable. Monitor for drops or weak performance.") -ForegroundColor Yellow
        Write-Host ""
        Write-Host (Center-Text "Press any key to continue...") -ForegroundColor Gray
        $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Clear-KeyBuffer

        try {
            $processes = @()
            Write-Host (Center-Text "Launching Network Connections... Please wait.") -ForegroundColor Gray
            $processes += Start-Process -FilePath "ncpa.cpl" -PassThru -ErrorAction Stop
            Write-ToLog -Message "Network: Launched Network Connections" -LogPath $logFilePath

            $bluetoothPath = Get-Tool -ToolName "BluetoothScanner.exe"
            Write-Host (Center-Text "Launching Bluetooth Scanner... Please wait.") -ForegroundColor Gray
            $processes += Start-Process -FilePath $bluetoothPath -PassThru -ErrorAction Stop
            Write-ToLog -Message "Network: Launched BluetoothScanner" -LogPath $logFilePath

            $pingPath = Get-Tool -ToolName "PingView.exe"
            Write-Host (Center-Text "Launching Ping View... Please wait.") -ForegroundColor Gray
            $processes += Start-Process -FilePath $pingPath -PassThru -ErrorAction Stop
            Write-ToLog -Message "Network: Launched PingView" -LogPath $logFilePath

            Write-Host (Center-Text "Launching Edge Browser for Network Test... Please wait.") -ForegroundColor Gray
            $processes += Start-Process -FilePath "msedge.exe" -ArgumentList "-inPrivate", "https://www.youtube.com/watch?v=vCbYim764zQ" -PassThru -ErrorAction Stop
            Write-ToLog -Message "Network: Launched Edge Browser" -LogPath $logFilePath

            Write-Host ""
            Write-Host (Center-Text "Close the network tools when done testing...") -ForegroundColor Yellow
            Write-Host (Center-Text "Press any key to continue after closing...") -ForegroundColor Gray
            $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

            foreach ($process in $processes) {
                if (-not $process.HasExited) {
                    $process.Kill()
                }
            }
            Write-ToLog -Message "Network: All network tools closed" -LogPath $logFilePath
        } catch {
            Write-ToLog -Message "Failed to launch Network Tools: $_" -LogPath $logFilePath
            Write-Host (Center-Text "Error launching Network Tools: $_") -ForegroundColor Red
            Write-Host ""
            Write-Host (Center-Text "Press any key to continue...") -ForegroundColor Gray
            $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            Clear-KeyBuffer
        }

        # Block 16: Optical Drive Test
        Clear-Host
        Show-SystemInfoHeader
        Write-Host ""
        Write-Host (Center-Text "TEST THE DVD/BLU-RAY/CD DRIVE") -ForegroundColor Cyan
        Write-Host (Center-Text "-----------------------------") -ForegroundColor Cyan
        Write-Host ""
        Write-Host (Center-Text "- Insert media to test reading/writing if applicable.") -ForegroundColor Yellow
        Write-Host (Center-Text "Ejecting drive for inspection...") -ForegroundColor Yellow
        Write-Host ""
        Write-Host (Center-Text "Press any key to continue...") -ForegroundColor Gray
        $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Clear-KeyBuffer

        try {
            $cdDrives = Get-CimInstance -ClassName Win32_CDROMDrive -ErrorAction SilentlyContinue
            if ($cdDrives) {
                $shell = New-Object -ComObject Shell.Application
                foreach ($drive in $cdDrives) {
                    $shell.Namespace(17).Items() | Where-Object { $_.Name -eq $drive.Caption } | ForEach-Object { $_.InvokeVerb("Eject") }
                }
                Write-ToLog -Message "Optical: Ejected CD/DVD drive" -LogPath $logFilePath
                Write-Host (Center-Text "Drive ejected. Test functionality and close when done.") -ForegroundColor Yellow
                Write-Host ""
                Write-Host (Center-Text "Press any key when finished...") -ForegroundColor Gray
                $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                Clear-KeyBuffer
            } else {
                Write-ToLog -Message "Optical: No CD/DVD drive detected" -LogPath $logFilePath
                Write-Host (Center-Text "No optical drive detected on this unit.") -ForegroundColor Yellow
                Write-Host ""
                Write-Host (Center-Text "Press any key to continue...") -ForegroundColor Gray
                $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                Clear-KeyBuffer
            }
        } catch {
            Write-ToLog -Message "Failed to eject Optical Drive: $_" -LogPath $logFilePath
            Write-Host (Center-Text "Error ejecting Optical Drive: $_") -ForegroundColor Red
            Write-Host ""
            Write-Host (Center-Text "Press any key to continue...") -ForegroundColor Gray
            $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            Clear-KeyBuffer
        }

        # Block 17: Webcam Test
        Clear-Host
        Show-SystemInfoHeader
        Write-Host ""
        Write-Host (Center-Text "TEST THE WEBCAM") -ForegroundColor Cyan
        Write-Host (Center-Text "---------------") -ForegroundColor Cyan
        Write-Host ""
        Write-Host (Center-Text "- Ensure the webcam does not cut out or freeze.") -ForegroundColor Yellow
        Write-Host (Center-Text "- Verify proper permissions and image quality.") -ForegroundColor Yellow
        Write-Host (Center-Text "Test in different lighting conditions if possible.") -ForegroundColor Yellow
        Write-Host ""
        Write-Host (Center-Text "Press any key to continue...") -ForegroundColor Gray
        $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Clear-KeyBuffer

        # Check if the Windows Camera app is installed
        $cameraAppInstalled = Get-AppxPackage -Name "Microsoft.WindowsCamera" -ErrorAction SilentlyContinue
        if ($cameraAppInstalled) {
            try {
                Write-Host (Center-Text "Launching Built-in Windows Camera App... Please wait.") -ForegroundColor Gray
                Start-Process -FilePath "microsoft.windows.camera:" -ErrorAction Stop
                Write-ToLog -Message "Camera: Launched Windows built-in Camera app" -LogPath $logFilePath
                Write-Host ""
                Write-Host (Center-Text "Test the webcam, then close the Camera app when done.") -ForegroundColor Yellow
                Write-Host ""
                Write-Host (Center-Text "Press any key to continue after closing the app...") -ForegroundColor Gray
                $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                Clear-KeyBuffer
                Write-ToLog -Message "Camera: Windows built-in Camera app testing completed" -LogPath $logFilePath
            } catch {
                Write-ToLog -Message "Failed to launch built-in Camera app: $_" -LogPath $logFilePath
                Write-Host (Center-Text "Built-in Camera app failed to launch. Using fallback...") -ForegroundColor Yellow

                try {
                    $cameraPath = Get-Tool -ToolName "CameraApp.exe"
                    Write-Host (Center-Text "Launching Fallback Camera App... Please wait.") -ForegroundColor Gray
                    $process = Start-Process -FilePath $cameraPath -PassThru -ErrorAction Stop
                    Write-ToLog -Message "Camera: Fallback to CameraApp.exe launched" -LogPath $logFilePath
                    $process.WaitForExit()
                    Write-ToLog -Message "Camera: CameraApp.exe closed" -LogPath $logFilePath
                } catch {
                    Write-ToLog -Message "Failed to launch fallback CameraApp.exe: $_" -LogPath $logFilePath
                    Write-Host (Center-Text "Error launching CameraApp.exe: $_") -ForegroundColor Red
                    Write-Host ""
                    Write-Host (Center-Text "Press any key to continue...") -ForegroundColor Gray
                    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    Clear-KeyBuffer
                }
            }
        } else {
            Write-ToLog -Message "Camera: Built-in Camera app not installed" -LogPath $logFilePath
            Write-Host (Center-Text "Built-in Camera app not available. Using fallback...") -ForegroundColor Yellow

            try {
                $cameraPath = Get-Tool -ToolName "CameraApp.exe"
                Write-Host (Center-Text "Launching Fallback Camera App... Please wait.") -ForegroundColor Gray
                $process = Start-Process -FilePath $cameraPath -PassThru -ErrorAction Stop
                Write-ToLog -Message "Camera: Fallback to CameraApp.exe launched" -LogPath $logFilePath
                $process.WaitForExit()
                Write-ToLog -Message "Camera: CameraApp.exe closed" -LogPath $logFilePath
            } catch {
                Write-ToLog -Message "Failed to launch fallback CameraApp.exe: $_" -LogPath $logFilePath
                Write-Host (Center-Text "Error launching CameraApp.exe: $_") -ForegroundColor Red
                Write-Host ""
                Write-Host (Center-Text "Press any key to continue...") -ForegroundColor Gray
                $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                Clear-KeyBuffer
            }
        }

        # Block 18: Sleep Mode Test
        Clear-Host
        Show-SystemInfoHeader
        Write-Host ""
        Write-Host (Center-Text "TEST SLEEP MODE") -ForegroundColor Cyan
        Write-Host (Center-Text "---------------") -ForegroundColor Cyan
        Write-Host ""
        Write-Host (Center-Text "- Verify the unit enters and wakes from sleep properly.") -ForegroundColor Yellow
        Write-Host (Center-Text "- Test both methods: closing the lid and using the menu.") -ForegroundColor Yellow
        Write-Host (Center-Text "Monitor for any wake-up delays or failures.") -ForegroundColor Yellow
        Write-Host ""
        Write-Host (Center-Text "Press any key to continue...") -ForegroundColor Gray
        $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Clear-KeyBuffer
        Write-ToLog -Message "Sleep:" -LogPath $logFilePath

        # Block 19: VGA/HDMI Ports Test
        Clear-Host
        Show-SystemInfoHeader
        Write-Host ""
        Write-Host (Center-Text "TEST VGA/HDMI PORTS") -ForegroundColor Cyan
        Write-Host (Center-Text "-------------------") -ForegroundColor Cyan
        Write-Host ""
        Write-Host (Center-Text "- Connect external displays to verify connection and output.") -ForegroundColor Yellow
        Write-Host (Center-Text "- Check if ports are loose or show signal issues.") -ForegroundColor Yellow
        Write-Host (Center-Text "Test resolution and audio passthrough if applicable.") -ForegroundColor Yellow
        Write-Host ""
        Write-Host (Center-Text "Press any key to continue...") -ForegroundColor Gray
        $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Clear-KeyBuffer
        Write-ToLog -Message "HDMI:" -LogPath $logFilePath

        # Block 20: QC Complete
        Clear-Host
        Show-SystemInfoHeader
        Write-Host ""
        Write-Host (Center-Text "QC CHECK COMPLETE") -ForegroundColor Cyan
        Write-Host (Center-Text "-----------------") -ForegroundColor Cyan
        Write-Host ""
        Write-Host (Center-Text "!!! REMINDER: REMOVE ANY SD CARD OR USB STICK BEFORE FINISHING !!!") -ForegroundColor Yellow
        Write-Host ""
        Write-Host (Center-Text "Press any key to EXIT and clean up...") -ForegroundColor Gray
        $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Clear-KeyBuffer

        Write-ToLog -Message "FINISH:" -LogPath $logFilePath
        "" | Out-File -FilePath $logFilePath -Append -ErrorAction SilentlyContinue
    }

    # Clean up and exit immediately
    Invoke-Cleanup -exit $true

} catch {
    Write-ToLog -Message "Script Error: $_" -LogPath $logFilePath
    Write-Host ""
    Write-Host (Center-Text "An error occurred: $_") -ForegroundColor Red
    Write-Host (Center-Text "Check log file at $logFilePath for details.") -ForegroundColor Yellow
    Write-Host ""
    Write-Host (Center-Text "Press any key to exit...") -ForegroundColor Gray
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Clear-KeyBuffer
    Invoke-Cleanup -exit $true
}
