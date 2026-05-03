Add-Type -AssemblyName PresentationFramework

$script:keyMap = @{}
$script:keyStates = @{} 

$window = New-Object System.Windows.Window
$window.Title = "Pro Keyboard Tester"
$window.Width  = 1200
$window.Height = 650
$window.Background = "#1E1E1E"
$window.Topmost = $true

$statusText = New-Object System.Windows.Controls.TextBlock
$statusText.FontSize = 20 ; $statusText.Foreground = "White" ; $statusText.Margin = "10"
$statusText.Text = "Press keys to test..."

$mainPanel = New-Object System.Windows.Controls.StackPanel
$mainPanel.Children.Add($statusText)
$window.Content = $mainPanel

$colorInactive = [System.Windows.Media.BrushConverter]::new().ConvertFrom("#B0B0B0")
$colorActive   = [System.Windows.Media.Brushes]::LimeGreen
$colorPressed  = [System.Windows.Media.Brushes]::ForestGreen

function New-Key {
    param([string]$label, [string]$keyName, [int]$width = 58)
    $border = New-Object System.Windows.Controls.Border
    $border.Width = $width ; $border.Height = 54 ; $border.Margin = "3"
    $border.Background = $colorInactive
    $border.BorderBrush = "#666" ; $border.BorderThickness = "1" ; $border.CornerRadius = "5"

    $txt = New-Object System.Windows.Controls.TextBlock
    $txt.Text = $label ; $txt.HorizontalAlignment = "Center" ; $txt.VerticalAlignment = "Center"
    $txt.Foreground = "#111" ; $txt.FontWeight = "Bold"

    $border.Child = $txt
    $script:keyMap[$keyName] = $border
    $script:keyStates[$keyName] = $false 
    return $border
}

function Add-Row($rowKeys) {
    $row = New-Object System.Windows.Controls.WrapPanel
    $row.HorizontalAlignment = "Center"
    foreach ($k in $rowKeys) {
        if ($k -is [array]) { $btn = New-Key -label $k[0] -keyName $k[1] -width $k[2] }
        else { $btn = New-Key -label $k -keyName $k }
        [void]$row.Children.Add($btn)
    }
    [void]$mainPanel.Children.Add($row)
}

# --- Layout ---
Add-Row @(@("Esc", "Escape", 68), "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12")
Add-Row @(@("~", "Oem3", 58), "D1", "D2", "D3", "D4", "D5", "D6", "D7", "D8", "D9", "D0", @("-", "OemMinus", 58), @("+", "OemPlus", 58), @("Back", "Back", 110))
Add-Row @(@("Tab", "Tab", 85), "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", @("[", "Oem4", 58), @("]", "Oem6", 58), @("\", "Oem5", 85))
Add-Row @(@("Caps", "Capital", 100), "A", "S", "D", "F", "G", "H", "J", "K", "L", @(";", "Oem1", 58), @("' """, "Oem7", 58), @("Enter", "Return", 120))
Add-Row @(@("Shift", "LeftShift", 130), "Z", "X", "C", "V", "B", "N", "M", @(",", "Oemcomma", 58), @(".", "OemPeriod", 58), @("/", "OemQuestion", 58), @("Shift", "RightShift", 130))
Add-Row @(@("Ctrl", "LeftCtrl", 80), @("Win", "LWin", 70), @("Alt", "LeftAlt", 70), @("Space", "Space", 400), @("Alt", "RightAlt", 70), @("Ctrl", "RightCtrl", 80))

# Separate row for Arrows to ensure they appear clearly
Add-Row @(@("←", "Left", 60), @("↑", "Up", 60), @("↓", "Down", 60), @("→", "Right", 60))

# --- Unified Logic ---
$handler = {
    param($e, $isDown)
    # Detect Key Name, including System keys (Alt)
    $keyName = $e.Key.ToString()
    if ($keyName -eq "System") { $keyName = $e.SystemKey.ToString() }

    if ($script:keyMap.ContainsKey($keyName)) {
        if ($isDown) {
            $script:keyMap[$keyName].Background = $colorPressed
            $statusText.Text = "Pressing: $keyName"
        } else {
            $script:keyStates[$keyName] = $true
            $script:keyMap[$keyName].Background = $colorActive
            $statusText.Text = "Tested: $keyName"
        }
    }
    # Block Windows Key
    if ($keyName -match "LWin|RWin") { $e.Handled = $true }
}

$window.Add_PreviewKeyDown({ $handler.Invoke($args[1], $true) })
$window.Add_PreviewKeyUp({ $handler.Invoke($args[1], $false) })

$window.ShowDialog()
