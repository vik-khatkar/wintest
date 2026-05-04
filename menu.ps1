# ==========================================
#               IMVSK TOOL MENU
# ==========================================

# 1. Admin Auto-Elevation
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Start-Process powershell "-ExecutionPolicy Bypass -Command `"irm https://raw.githubusercontent.com/vik-khatkar/winclean/main/menu.ps1 | iex`"" -Verb RunAs
    exit
}

function Show-Menu {
    Clear-Host
    Write-Host "`n==========================================" -ForegroundColor Cyan
    Write-Host "             TOOLS @IMVSK                 " -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  1) KB Test" -ForegroundColor Green
    Write-Host "  2) Temp Clean-UP" -ForegroundColor Green
    Write-Host "  3) OS Repair" -ForegroundColor Green
    Write-Host "  4) Reset Default" -ForegroundColor Green
    Write-Host "  5) System Info" -ForegroundColor Green
    Write-Host "  0) Exit" -ForegroundColor Red
    Write-Host ""
}

# Start the interactive loop
do {
    Show-Menu
    $choice = Read-Host "Select an option: "

    switch ($choice) {
        '1' { 
            Write-Host "`nLaunching KB Test..." -ForegroundColor Yellow
            irm https://raw.githubusercontent.com/vik-khatkar/winclean/main/kb.ps1 | iex 
        }
        '2' { 
            Write-Host "`nLaunching Clean..." -ForegroundColor Yellow
            irm https://raw.githubusercontent.com/vik-khatkar/winclean/main/clean.ps1 | iex 
        }
        '3' { 
            Write-Host "`nLaunching Repair..." -ForegroundColor Yellow
            irm https://raw.githubusercontent.com/vik-khatkar/winclean/main/repair.ps1 | iex 
        }
        '4' { 
            Write-Host "`nLaunching Reset..." -ForegroundColor Yellow
            irm https://raw.githubusercontent.com/vik-khatkar/winclean/main/reset.ps1 | iex
        }
        '5' {
            Write-Host "`nLaunching System Information Tool..." -ForegroundColor Yellow
            Start-Process powershell -ArgumentList "-NoLogo -NoProfile -ExecutionPolicy Bypass -Command `"irm https://raw.githubusercontent.com/vik-khatkar/winclean/main/sysinfo.ps1 | iex`""
        }
        '0' { 
            Write-Host "`nExiting..." -ForegroundColor Gray
            break 
        }
        Default { 
            Write-Host "`nInvalid choice, try again." -ForegroundColor Red
            Start-Sleep -Seconds 1
            continue 
        }
    }

    # Pause after each task (except exit)
    if ($choice -ne '0') {
        Write-Host "`nTask finished. Press any key to return to menu..." -ForegroundColor Cyan
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }

} while ($choice -ne '0')

# --- CLEANUP ON EXIT ---
Write-Host "`nClearing PowerShell history..." -ForegroundColor Yellow
Clear-History -ErrorAction SilentlyContinue
$hPath = (Get-PSReadlineOption).HistorySavePath
if (Test-Path $hPath) { Remove-Item $hPath -Force -ErrorAction SilentlyContinue }

Write-Host "Goodbye!" -ForegroundColor Gray
Start-Sleep -Seconds 2
exit
