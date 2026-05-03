Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

# Suppress ALL console output
$Host.UI.RawUI.WindowTitle = "QC System Info"
$ErrorActionPreference = "SilentlyContinue"
$null = [Console]::Out

# Override Write-Host to do nothing
function Write-Host {}

# ---------------- SYSTEM INFO ----------------
function Get-SystemInfo {
    $sys  = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
    $bios = Get-CimInstance -ClassName Win32_BIOS -ErrorAction SilentlyContinue
    $cpu  = Get-CimInstance -ClassName Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
    $gpu  = Get-CimInstance -ClassName Win32_VideoController -ErrorAction SilentlyContinue | Where-Object { $_.Name -notlike "*Remote*" -and $_.Name -notlike "*Basic*" } | Select-Object -First 1
    $os   = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction SilentlyContinue
    
    # RAM in GB
    $ramGB = if ($sys.TotalPhysicalMemory) { [math]::Round($sys.TotalPhysicalMemory / 1GB, 1) } else { 0 }
    
    # Disk info
    $diskSize = if ($disk.Size) { [math]::Round($disk.Size / 1GB, 1) } else { 0 }
    $diskFree = if ($disk.FreeSpace) { [math]::Round($disk.FreeSpace / 1GB, 1) } else { 0 }
    
    # Uptime
    $uptimeSpan = if ($os.LastBootUpTime) { (Get-Date) - $os.LastBootUpTime } else { New-TimeSpan -Days 0 }
    $uptime = "{0}d {1}h {2}m" -f $uptimeSpan.Days, $uptimeSpan.Hours, $uptimeSpan.Minutes
    
    # CPU load
    $cpuLoad = "N/A"
    $cpuPerf = Get-CimInstance -ClassName Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'" -ErrorAction SilentlyContinue
    if ($cpuPerf.PercentProcessorTime) {
        $cpuLoad = "$($cpuPerf.PercentProcessorTime)%"
    } elseif ($cpu.LoadPercentage) {
        $cpuLoad = "$($cpu.LoadPercentage)%"
    }
    
    # CPU name cleanup
    $cpuName = if ($cpu.Name) { 
        $cpu.Name -replace '\(R\)', '' -replace '\(TM\)', '' -replace 'CPU', '' -replace '@', '' -replace '\s+', ' '
    } else { 
        "Unknown CPU" 
    }
    if ($cpuName.Length -gt 50) { $cpuName = $cpuName.Substring(0,50) + "..." }
    
    # GPU name
    $gpuName = if ($gpu.Name) { 
        $gpu.Name -replace '\(R\)', '' -replace '\(TM\)', '' | ForEach-Object { $_.Trim() }
    } else { 
        "N/A" 
    }
    
    # ---------------- BATTERY INFO ----------------
    $batName = "N/A"
    $batManu = "N/A"
    $batStatus = "N/A"
    $batCharge = "N/A"
    $batHealth = "N/A"
    $batWear = "N/A"
    
    # Battery detection
    $battery = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue
    if ($battery) {
        $batName = if ($battery.Name) { $battery.Name } else { "System Battery" }
        $batManu = if ($battery.Manufacturer) { $battery.Manufacturer } else { "Unknown" }
        $batCharge = if ($battery.EstimatedChargeRemaining) { "$($battery.EstimatedChargeRemaining)%" } else { "N/A" }
        
        # Battery status
        $statusCode = $battery.BatteryStatus
        if ($statusCode -eq 2 -or $statusCode -eq 6 -or $statusCode -eq 7 -or $statusCode -eq 8) {
            $batStatus = "Charging"
        } elseif ($statusCode -eq 1) {
            $batStatus = "Discharging"
        } elseif ($statusCode -eq 3) {
            $batStatus = "Fully Charged"
        } elseif ($statusCode -eq 4) {
            $batStatus = "Low"
        } elseif ($statusCode -eq 5) {
            $batStatus = "Critical"
        } else {
            $powerStatus = Get-CimInstance -ClassName Win32_PowerStatus -ErrorAction SilentlyContinue
            if ($powerStatus -and $powerStatus.ACLineStatus -eq 1) {
                $batStatus = "AC Connected"
            } else {
                $batStatus = "Unknown"
            }
        }
        
        # Battery wear detection
        try {
            $batFull = Get-WmiObject -Namespace "root\WMI" -Class BatteryFullChargedCapacity -ErrorAction Stop | Select-Object -First 1
            $batDesign = Get-WmiObject -Namespace "root\WMI" -Class BatteryStaticData -ErrorAction Stop | Select-Object -First 1

            if ($batFull.FullChargedCapacity -and $batDesign.DesignedCapacity -and $batDesign.DesignedCapacity -gt 0) {
                $healthPct = ($batFull.FullChargedCapacity / $batDesign.DesignedCapacity) * 100
                $wear = 100 - $healthPct
                $batHealth = "{0:N1}%" -f $healthPct
                $batWear = "{0:N1}%" -f $wear
                
                if ($sys.Manufacturer -like "*Microsoft*" -or $sys.Model -like "*Surface*") {
                    $batName = "Surface Battery"
                    $batManu = "Microsoft"
                }
            }
        } catch {}
    }
    
    # OS version
    $osVersion = if ($os.Caption) { $os.Caption } else { "Unknown OS" }
    if ($os.Version) { 
        $buildNum = $os.Version -split '\.' | Select-Object -Last 1
        $osVersion += " (Build $buildNum)" 
    }
    
    return [pscustomobject]@{
        SerialNumber = if ($bios.SerialNumber -and $bios.SerialNumber -notlike "*To be filled*" -and $bios.SerialNumber -notlike "*Default*") { $bios.SerialNumber } else { "N/A" }
        Model = "$($sys.Manufacturer) $($sys.Model)".Trim()
        Manufacturer = $sys.Manufacturer
        CPU = $cpuName
        CPULoad = $cpuLoad
        GPU = $gpuName
        RAM = "$ramGB GB"
        Disk = "$diskFree GB free of $diskSize GB"
        OS = $osVersion
        BIOS = $bios.SMBIOSBIOSVersion
        Uptime = $uptime
        BatteryName = $batName
        BatteryManufacturer = $batManu
        BatteryCharge = $batCharge
        BatteryStatus = $batStatus
        BatteryHealth = $batHealth
        BatteryWear = $batWear
    }
}

# ---------------- GUI ----------------
$window = New-Object System.Windows.Window
$window.Title = "System Information @IMVSK"
$window.Width = 680
$window.Height = 520
$window.WindowStartupLocation = "CenterScreen"
$window.ResizeMode = "NoResize"
$window.Topmost = $true
$window.Background = "White"

$mainGrid = New-Object System.Windows.Controls.Grid
$mainGrid.Margin = "20"

# Create rows
[void]$mainGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height="Auto"})) # Info Grid
[void]$mainGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height="Auto"})) # Battery Panel
[void]$mainGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height="*"}))    # Buttons

# Info Grid
$infoGrid = New-Object System.Windows.Controls.Grid
$infoGrid.Margin = "0,0,0,15"
[void]$infoGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width="140"}))
[void]$infoGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width="*"}))

# Add rows for each info field
for ($i = 0; $i -lt 12; $i++) {
    $rowDef = New-Object System.Windows.Controls.RowDefinition
    $rowDef.Height = "Auto"
    [void]$infoGrid.RowDefinitions.Add($rowDef)
}

# Function to add field
function AddField {
    param([int]$row, [string]$label, [ref]$box)
    
    $lbl = New-Object System.Windows.Controls.TextBlock
    $lbl.Text = $label
    $lbl.FontWeight = "Bold"
    $lbl.VerticalAlignment = "Center"
    $lbl.Margin = "5,3,5,3"
    [System.Windows.Controls.Grid]::SetRow($lbl, $row)
    [System.Windows.Controls.Grid]::SetColumn($lbl, 0)
    [void]$infoGrid.Children.Add($lbl)
    
    $txt = New-Object System.Windows.Controls.TextBox
    $txt.IsReadOnly = $true
    $txt.Background = [System.Windows.Media.Brushes]::White
    $txt.BorderThickness = "1"
    $txt.BorderBrush = [System.Windows.Media.Brushes]::LightGray
    $txt.Height = 24
    $txt.Margin = "3,3,3,3"
    $txt.Padding = "3,0,0,0"
    $txt.FontFamily = "Consolas"
    $txt.FontSize = 12
    $txt.VerticalContentAlignment = "Center"
    [System.Windows.Controls.Grid]::SetRow($txt, $row)
    [System.Windows.Controls.Grid]::SetColumn($txt, 1)
    [void]$infoGrid.Children.Add($txt)
    
    $box.Value = $txt
}

# Create field references
$sn=$null; $model=$null; $cpu=$null; $cpul=$null; $gpu=$null; $ram=$null
$disk=$null; $os=$null; $bios=$null; $up=$null; $batName=$null; $batCharge=$null

# Add fields
AddField 0  "Serial Number:"       ([ref]$sn)
AddField 1  "Model:"               ([ref]$model)
AddField 2  "CPU:"                 ([ref]$cpu)
AddField 3  "CPU Load:"            ([ref]$cpul)
AddField 4  "GPU:"                 ([ref]$gpu)
AddField 5  "RAM:"                 ([ref]$ram)
AddField 6  "C: Drive:"            ([ref]$disk)
AddField 7  "Operating System:"    ([ref]$os)
AddField 8  "BIOS Version:"        ([ref]$bios)
AddField 9  "System Uptime:"       ([ref]$up)
AddField 10 "Battery:"             ([ref]$batName)
AddField 11 "Battery Charge:"      ([ref]$batCharge)

[System.Windows.Controls.Grid]::SetRow($infoGrid, 0)
[void]$mainGrid.Children.Add($infoGrid)

# Battery status panel
$batteryPanel = New-Object System.Windows.Controls.WrapPanel
$batteryPanel.Margin = "0,0,0,15"
$batteryPanel.HorizontalAlignment = "Left"

# Status
$statusLabel = New-Object System.Windows.Controls.TextBlock
$statusLabel.Text = "Status: "
$statusLabel.FontWeight = "Bold"
$statusLabel.Margin = "0,0,5,0"

$statusValue = New-Object System.Windows.Controls.TextBlock
$statusValue.Margin = "0,0,20,0"
$statusValue.FontWeight = "Bold"

# Health
$healthLabel = New-Object System.Windows.Controls.TextBlock
$healthLabel.Text = "Health: "
$healthLabel.FontWeight = "Bold"
$healthLabel.Margin = "0,0,5,0"

$healthValue = New-Object System.Windows.Controls.TextBlock
$healthValue.Margin = "0,0,20,0"
$healthValue.FontWeight = "Bold"

# Wear
$wearLabel = New-Object System.Windows.Controls.TextBlock
$wearLabel.Text = "Wear: "
$wearLabel.FontWeight = "Bold"
$wearLabel.Margin = "0,0,5,0"

$wearValue = New-Object System.Windows.Controls.TextBlock
$wearValue.FontWeight = "Bold"

[void]$batteryPanel.Children.Add($statusLabel)
[void]$batteryPanel.Children.Add($statusValue)
[void]$batteryPanel.Children.Add($healthLabel)
[void]$batteryPanel.Children.Add($healthValue)
[void]$batteryPanel.Children.Add($wearLabel)
[void]$batteryPanel.Children.Add($wearValue)

[System.Windows.Controls.Grid]::SetRow($batteryPanel, 1)
[void]$mainGrid.Children.Add($batteryPanel)

# Button panel
$btnPanel = New-Object System.Windows.Controls.StackPanel
$btnPanel.Orientation = "Horizontal"
$btnPanel.HorizontalAlignment = "Right"
$btnPanel.VerticalAlignment = "Bottom"

# Copy All Button
$copyAll = New-Object System.Windows.Controls.Button
$copyAll.Content = "Copy All"
$copyAll.Width = 80
$copyAll.Height = 30
$copyAll.Margin = "0,0,8,0"
$copyAll.Background = [System.Windows.Media.Brushes]::LightGray

# Copy SN Button
$copySN = New-Object System.Windows.Controls.Button
$copySN.Content = "Copy SN"
$copySN.Width = 80
$copySN.Height = 30
$copySN.Margin = "0,0,8,0"
$copySN.Background = [System.Windows.Media.Brushes]::LightGray

# Refresh Button
$refreshBtn = New-Object System.Windows.Controls.Button
$refreshBtn.Content = "Refresh"
$refreshBtn.Width = 80
$refreshBtn.Height = 30
$refreshBtn.Margin = "0,0,8,0"
$refreshBtn.Background = [System.Windows.Media.Brushes]::LightGray

# Close Button
$closeBtn = New-Object System.Windows.Controls.Button
$closeBtn.Content = "Close"
$closeBtn.Width = 80
$closeBtn.Height = 30
$closeBtn.Background = [System.Windows.Media.Brushes]::LightGray

[void]$btnPanel.Children.Add($copyAll)
[void]$btnPanel.Children.Add($copySN)
[void]$btnPanel.Children.Add($refreshBtn)
[void]$btnPanel.Children.Add($closeBtn)

[System.Windows.Controls.Grid]::SetRow($btnPanel, 2)
[void]$mainGrid.Children.Add($btnPanel)

$window.Content = $mainGrid

# Update function
function Update-Info {
    $info = Get-SystemInfo
    
    $sn.Text = $info.SerialNumber
    $model.Text = $info.Model
    $cpu.Text = $info.CPU
    $cpul.Text = $info.CPULoad
    $gpu.Text = $info.GPU
    $ram.Text = $info.RAM
    $disk.Text = $info.Disk
    $os.Text = $info.OS
    $bios.Text = $info.BIOS
    $up.Text = $info.Uptime
    $batName.Text = $info.BatteryName
    $batCharge.Text = $info.BatteryCharge
    
    # Update battery details
    $statusValue.Text = $info.BatteryStatus
    $healthValue.Text = $info.BatteryHealth
    $wearValue.Text = $info.BatteryWear
    
    # Color coding for Health (Green for good)
    if ($info.BatteryHealth -match "[\d.]+%") {
        $healthVal = [double]($info.BatteryHealth -replace '[^\d.]', '')
        if ($healthVal -ge 80) {
            $healthValue.Foreground = [System.Windows.Media.Brushes]::Green
        } elseif ($healthVal -ge 60) {
            $healthValue.Foreground = [System.Windows.Media.Brushes]::Orange
        } else {
            $healthValue.Foreground = [System.Windows.Media.Brushes]::Red
        }
    }
    
    # Color coding for Wear (Orange/Yellow for medium, Red for high)
    if ($info.BatteryWear -match "[\d.]+%") {
        $wearVal = [double]($info.BatteryWear -replace '[^\d.]', '')
        if ($wearVal -le 10) {
            $wearValue.Foreground = [System.Windows.Media.Brushes]::Green
        } elseif ($wearVal -le 20) {
            $wearValue.Foreground = [System.Windows.Media.Brushes]::Orange
        } elseif ($wearVal -le 30) {
            $wearValue.Foreground = [System.Windows.Media.Brushes]::OrangeRed
        } else {
            $wearValue.Foreground = [System.Windows.Media.Brushes]::Red
        }
    }
}

# Button handlers
$copySN.Add_Click({
    if ($sn.Text -and $sn.Text -ne "N/A") {
        [System.Windows.Clipboard]::SetText($sn.Text)
        $copySN.Content = "Copied!"
        $copySN.Background = [System.Windows.Media.Brushes]::LightGreen
        $timer = New-Object System.Windows.Threading.DispatcherTimer
        $timer.Interval = [TimeSpan]::FromSeconds(1)
        $timer.Add_Tick({
            $copySN.Content = "Copy SN"
            $copySN.Background = [System.Windows.Media.Brushes]::LightGray
            $timer.Stop()
        })
        $timer.Start()
    }
})

$copyAll.Add_Click({
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $allText = @"
SYSTEM INFORMATION REPORT
Generated: $timestamp
========================

SYSTEM DETAILS
--------------
Serial Number: $($sn.Text)
Model: $($model.Text)
CPU: $($cpu.Text)
CPU Load: $($cpul.Text)
GPU: $($gpu.Text)
RAM: $($ram.Text)
C: Drive: $($disk.Text)
Operating System: $($os.Text)
BIOS Version: $($bios.Text)
System Uptime: $($up.Text)

BATTERY INFORMATION
-------------------
Battery: $($batName.Text)
Charge Level: $($batCharge.Text)
Status: $($statusValue.Text)
Health: $($healthValue.Text)
Wear Level: $($wearValue.Text)
"@
    [System.Windows.Clipboard]::SetText($allText)
    $copyAll.Content = "Copied!"
    $copyAll.Background = [System.Windows.Media.Brushes]::LightGreen
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromSeconds(1)
    $timer.Add_Tick({
        $copyAll.Content = "Copy All"
        $copyAll.Background = [System.Windows.Media.Brushes]::LightGray
        $timer.Stop()
    })
    $timer.Start()
})

$refreshBtn.Add_Click({
    $refreshBtn.Content = "Refreshing..."
    $refreshBtn.IsEnabled = $false
    Update-Info
    $refreshBtn.Content = "Refresh"
    $refreshBtn.IsEnabled = $true
})

$closeBtn.Add_Click({
    $window.Close()
})

# Initial update
Update-Info

# Show window
$window.ShowDialog() | Out-Null

# ---------------------------------------------------------
# CLEAR POWERSHELL HISTORY
# ---------------------------------------------------------
try {
    $historyPath = (Get-PSReadlineOption).HistorySavePath
    if (Test-Path $historyPath) {
        Remove-Item $historyPath -Force -ErrorAction SilentlyContinue
    }
    Clear-History -ErrorAction SilentlyContinue
}
catch {}

# Clean exit
Stop-Process -Id $PID -Force
