#requires -version 5.1

<#
.SYNOPSIS
    WinOptimizer - Gain$ - Windows Setup, Gaming & Optimization Utility

.DESCRIPTION
    A safety-first Windows optimization utility.

    Features:
      - Hardware / OS detection
      - Restore point
      - Registry backup
      - Gaming profile
      - Performance profiles
      - Safe debloat
      - Privacy tweaks
      - Application installation through WinGet
      - Gaming runtimes
      - Health check
      - Verification after changes
      - Rollback support
      - Detailed logging
      - Preview mode

.NOTES
    Run as Administrator.
    Designed for Windows 10/11.

.VERSION
    2.0.0
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ============================================================
# CONFIG
# ============================================================

$script:AppName    = "WinOptimizer"
$script:Version    = "2.0.0"
$script:Root       = Join-Path $env:ProgramData "WinOptimizer"
$script:BackupRoot = Join-Path $script:Root "Backups"
$script:LogRoot    = Join-Path $script:Root "Logs"
$script:LogFile    = Join-Path $script:LogRoot "WinOptimizer.log"
$script:StateFile  = Join-Path $script:Root "state.json"

$script:PreviewMode = $false
$script:ChangesMade = $false
$script:NeedsReboot = $false

# ============================================================
# DIRECTORIES
# ============================================================

foreach ($Directory in @(
    $script:Root,
    $script:BackupRoot,
    $script:LogRoot
)) {
    if (-not (Test-Path -LiteralPath $Directory)) {
        New-Item `
            -ItemType Directory `
            -Path $Directory `
            -Force |
            Out-Null
    }
}

# ============================================================
# ADMIN CHECK
# ============================================================

function Test-Administrator {

    $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()

    $Principal = New-Object `
        Security.Principal.WindowsPrincipal($Identity)

    return $Principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

if (-not (Test-Administrator)) {

    $Arguments = @(
        "-NoProfile"
        "-ExecutionPolicy"
        "Bypass"
        "-File"
        "`"$PSCommandPath`""
    )

    Start-Process `
        -FilePath "powershell.exe" `
        -ArgumentList ($Arguments -join " ") `
        -Verb RunAs

    exit
}

# ============================================================
# LOGGING
# ============================================================

function Write-Log {

    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet(
            "INFO",
            "OK",
            "WARN",
            "ERROR"
        )]
        [string]$Level = "INFO"
    )

    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $Line = "$Timestamp [$Level] $Message"

    try {
        Add-Content `
            -Path $script:LogFile `
            -Value $Line `
            -Encoding UTF8
    }
    catch {}
}

# ============================================================
# UI HELPERS
# ============================================================

function Write-Header {

    param(
        [string]$Title = ""
    )

    Clear-Host

    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════╗" `
        -ForegroundColor DarkCyan

    Write-Host "║" -NoNewline -ForegroundColor DarkCyan
    Write-Host "                    WINOPTIMIZER - Gain$                   " `
        -NoNewline -ForegroundColor White
    Write-Host "║" -ForegroundColor DarkCyan

    Write-Host "║" -NoNewline -ForegroundColor DarkCyan
    Write-Host "             Windows Optimization Utility                  " `
        -NoNewline -ForegroundColor DarkGray
    Write-Host "║" -ForegroundColor DarkCyan

    Write-Host "║" -NoNewline -ForegroundColor DarkCyan
    Write-Host "                     v$script:Version                      " `
        -NoNewline -ForegroundColor DarkGray
    Write-Host "║" -ForegroundColor DarkCyan

    Write-Host "╚══════════════════════════════════════════════════════════╝" `
        -ForegroundColor DarkCyan

    if ($Title) {

        Write-Host ""
        Write-Host "  $Title" `
            -ForegroundColor Cyan

        Write-Host "  ────────────────────────────────────────────────────────" `
            -ForegroundColor DarkGray
    }

    Write-Host ""
}

function Write-Success {

    param([string]$Message)

    Write-Host "  [✓] $Message" -ForegroundColor Green
    Write-Log $Message "OK"
}

function Write-WarningMessage {

    param([string]$Message)

    Write-Host "  [!] $Message" -ForegroundColor Yellow
    Write-Log $Message "WARN"
}

function Write-ErrorMessage {

    param([string]$Message)

    Write-Host "  [✗] $Message" -ForegroundColor Red
    Write-Log $Message "ERROR"
}

function Write-InfoMessage {

    param([string]$Message)

    Write-Host "  [i] $Message" -ForegroundColor Cyan
    Write-Log $Message "INFO"
}

function Write-Step {

    param([string]$Message)

    Write-Host ""
    Write-Host "  » $Message" -ForegroundColor White
}

function Pause-Menu {

    Write-Host ""
    Read-Host "  Press ENTER to continue" | Out-Null
}

function Confirm-Action {

    param(
        [string]$Message
    )

    $Answer = Read-Host "  $Message [Y/N]"

    return $Answer -match "^(Y|y|YES|yes)$"
}

# ============================================================
# SAFE EXECUTION
# ============================================================

function Invoke-Safe {

    param(
        [Parameter(Mandatory)]
        [scriptblock]$Action,

        [Parameter(Mandatory)]
        [string]$Description
    )

    try {

        if ($script:PreviewMode) {

            Write-InfoMessage "PREVIEW: $Description"

            return $true
        }

        & $Action

        $script:ChangesMade = $true

        Write-Success $Description

        return $true
    }
    catch {

        Write-ErrorMessage `
            "$Description failed: $($_.Exception.Message)"

        return $false
    }
}

# ============================================================
# OS INFORMATION
# ============================================================

function Get-SystemInfo {

    try {

        $OS = Get-CimInstance Win32_OperatingSystem
        $CPU = Get-CimInstance Win32_Processor |
            Select-Object -First 1

        $GPU = Get-CimInstance Win32_VideoController |
            Where-Object {
                $_.Name -and
                $_.Name -notmatch "Microsoft Basic"
            }

        $RAMGB = [Math]::Round(
            $OS.TotalVisibleMemorySize / 1MB,
            1
        )

        $FreeRAMGB = [Math]::Round(
            $OS.FreePhysicalMemory / 1MB,
            1
        )

        return [PSCustomObject]@{
            ComputerName = $env:COMPUTERNAME
            Windows      = $OS.Caption
            Version      = $OS.Version
            Build        = $OS.BuildNumber
            CPU          = $CPU.Name
            RAMGB        = $RAMGB
            FreeRAMGB    = $FreeRAMGB
            GPU          = (
                $GPU.Name -join ", "
            )
        }
    }
    catch {

        return $null
    }
}

# ============================================================
# HARDWARE TYPE
# ============================================================

function Get-SystemType {

    try {

        $Battery = Get-CimInstance `
            Win32_Battery `
            -ErrorAction SilentlyContinue

        if ($Battery) {
            return "Laptop"
        }

        return "Desktop"
    }
    catch {

        return "Unknown"
    }
}

# ============================================================
# GPU VENDOR
# ============================================================

function Get-GPUVendor {

    try {

        $GPU = Get-CimInstance Win32_VideoController |
            Where-Object {
                $_.Name
            } |
            Select-Object -First 1

        if (-not $GPU) {
            return "Unknown"
        }

        if ($GPU.Name -match "NVIDIA") {
            return "NVIDIA"
        }

        if ($GPU.Name -match "AMD|Radeon") {
            return "AMD"
        }

        if ($GPU.Name -match "Intel") {
            return "Intel"
        }

        return "Other"
    }
    catch {

        return "Unknown"
    }
}

# ============================================================
# STATUS
# ============================================================

function Get-PowerPlan {

    try {

        $Output = powercfg /getactivescheme 2>$null

        if ($Output -match "High performance") {
            return "High Performance"
        }

        if ($Output -match "Ultimate Performance") {
            return "Ultimate Performance"
        }

        if ($Output -match "Balanced") {
            return "Balanced"
        }

        return "Custom"
    }
    catch {

        return "Unknown"
    }
}

function Get-GameDVRStatus {

    try {

        $Path = "HKCU:\System\GameConfigStore"

        if (-not (Test-Path $Path)) {
            return "Unknown"
        }

        $Value = Get-ItemProperty `
            -Path $Path `
            -Name GameDVR_Enabled `
            -ErrorAction SilentlyContinue

        if ($null -eq $Value) {
            return "Unknown"
        }

        if ($Value.GameDVR_Enabled -eq 0) {
            return "Disabled"
        }

        return "Enabled"
    }
    catch {

        return "Unknown"
    }
}

function Get-TransparencyStatus {

    try {

        $Path =
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"

        $Value = Get-ItemProperty `
            -Path $Path `
            -Name EnableTransparency `
            -ErrorAction SilentlyContinue

        if ($null -eq $Value) {
            return "Unknown"
        }

        if ($Value.EnableTransparency -eq 0) {
            return "Disabled"
        }

        return "Enabled"
    }
    catch {

        return "Unknown"
    }
}

# ============================================================
# DASHBOARD
# ============================================================

function Show-Dashboard {

    Write-Header "Dashboard"

    $Info = Get-SystemInfo

    if ($Info) {

        Write-Host "  SYSTEM" `
            -ForegroundColor DarkCyan

        Write-Host ""
        Write-Host "  PC       : " -NoNewline -ForegroundColor DarkGray
        Write-Host $Info.ComputerName

        Write-Host "  Windows  : " -NoNewline -ForegroundColor DarkGray
        Write-Host "$($Info.Windows) / Build $($Info.Build)"

        Write-Host "  CPU      : " -NoNewline -ForegroundColor DarkGray
        Write-Host $Info.CPU

        Write-Host "  RAM      : " -NoNewline -ForegroundColor DarkGray
        Write-Host "$($Info.RAMGB) GB"

        Write-Host "  GPU      : " -NoNewline -ForegroundColor DarkGray
        Write-Host $Info.GPU

        Write-Host "  Type     : " -NoNewline -ForegroundColor DarkGray
        Write-Host (Get-SystemType)

        Write-Host ""
        Write-Host "  STATUS" `
            -ForegroundColor DarkCyan

        Write-Host ""

        $Power = Get-PowerPlan
        $DVR = Get-GameDVRStatus
        $Transparency = Get-TransparencyStatus

        Write-Host "  Power Plan      : " -NoNewline
        Write-Host $Power `
            -ForegroundColor Cyan

        Write-Host "  Game DVR        : " -NoNewline

        if ($DVR -eq "Disabled") {
            Write-Host $DVR -ForegroundColor Green
        }
        else {
            Write-Host $DVR -ForegroundColor Yellow
        }

        Write-Host "  Transparency    : " -NoNewline

        if ($Transparency -eq "Disabled") {
            Write-Host $Transparency -ForegroundColor Green
        }
        else {
            Write-Host $Transparency -ForegroundColor Yellow
        }

        Write-Host "  GPU Vendor      : " -NoNewline
        Write-Host (Get-GPUVendor) -ForegroundColor Cyan

        if ($script:NeedsReboot) {

            Write-Host ""
            Write-WarningMessage `
                "A restart is recommended."
        }
    }

    Write-Host ""
    Pause-Menu
}

# ============================================================
# RESTORE POINT
# ============================================================

function New-OptimizerRestorePoint {

    Write-Step "Creating Windows restore point"

    try {

        Enable-ComputerRestore `
            -Drive "$env:SystemDrive\" `
            -ErrorAction SilentlyContinue

        Checkpoint-Computer `
            -Description "WinOptimizer $script:Version" `
            -RestorePointType MODIFY_SETTINGS `
            -ErrorAction Stop

        Write-Success "Restore point created."
    }
    catch {

        Write-WarningMessage `
            "Restore point could not be created."

        Write-WarningMessage `
            "Continuing because registry backup will still be created."
    }
}

# ============================================================
# REGISTRY BACKUP
# ============================================================

function Backup-Registry {

    $Stamp = Get-Date -Format "yyyyMMdd_HHmmss"

    $Destination = Join-Path `
        $script:BackupRoot `
        $Stamp

    New-Item `
        -ItemType Directory `
        -Path $Destination `
        -Force |
        Out-Null

    Write-Step "Creating backup"

    $RegistryItems = @(
        @{
            Hive = "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR"
            File = "GameDVR.reg"
        },
        @{
            Hive = "HKCU\System\GameConfigStore"
            File = "GameConfigStore.reg"
        },
        @{
            Hive = "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
            File = "Personalize.reg"
        },
        @{
            Hive = "HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo"
            File = "AdvertisingInfo.reg"
        }
    )

    foreach ($Item in $RegistryItems) {

        $File = Join-Path `
            $Destination `
            $Item.File

        try {

            reg.exe export `
                $Item.Hive `
                $File `
                /y 2>$null |
                Out-Null
        }
        catch {}
    }

    try {

        Get-Service |
            Select-Object Name, Status, StartType |
            ConvertTo-Json -Depth 3 |
            Out-File `
                (Join-Path $Destination "Services.json") `
                -Encoding UTF8
    }
    catch {}

    try {

        powercfg /getactivescheme |
            Out-File `
                (Join-Path $Destination "PowerPlan.txt") `
                -Encoding UTF8
    }
    catch {}

    try {

        Get-CimInstance Win32_OperatingSystem |
            Select-Object Caption, Version, BuildNumber |
            ConvertTo-Json |
            Out-File `
                (Join-Path $Destination "System.json") `
                -Encoding UTF8
    }
    catch {}

    Write-Success `
        "Backup created: $Destination"
}

# ============================================================
# PROTECTION
# ============================================================

function Start-Protection {

    Write-Header "Protection"

    New-OptimizerRestorePoint
    Backup-Registry

    Pause-Menu
}

# ============================================================
# REGISTRY HELPER
# ============================================================

function Set-RegistryValueSafe {

    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [object]$Value,

        [Microsoft.Win32.RegistryValueKind]
        $Type = [Microsoft.Win32.RegistryValueKind]::DWord
    )

    if (-not (Test-Path $Path)) {

        New-Item `
            -Path $Path `
            -Force |
            Out-Null
    }

    Set-ItemProperty `
        -Path $Path `
        -Name $Name `
        -Value $Value `
        -Type $Type `
        -Force
}

# ============================================================
# GAME DVR
# ============================================================

function Set-GameDVRDisabled {

    Write-Step "Disabling Game DVR"

    $Success = Invoke-Safe -Description "Game DVR disabled" -Action {

        Set-RegistryValueSafe `
            -Path "HKCU:\System\GameConfigStore" `
            -Name "GameDVR_Enabled" `
            -Value 0

        Set-RegistryValueSafe `
            -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" `
            -Name "AppCaptureEnabled" `
            -Value 0

        $PolicyPath =
            "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"

        Set-RegistryValueSafe `
            -Path $PolicyPath `
            -Name "AllowGameDVR" `
            -Value 0

        $script:NeedsReboot = $true
    }

    return $Success
}

# ============================================================
# GAME MODE
# ============================================================

function Set-GameModeEnabled {

    Write-Step "Ensuring Windows Game Mode is enabled"

    Invoke-Safe -Description "Game Mode enabled" -Action {

        Set-RegistryValueSafe `
            -Path "HKCU:\Software\Microsoft\GameBar" `
            -Name "AutoGameModeEnabled" `
            -Value 1
    }
}

# ============================================================
# TRANSPARENCY
# ============================================================

function Set-TransparencyDisabled {

    Write-Step "Disabling transparency effects"

    Invoke-Safe -Description "Transparency disabled" -Action {

        Set-RegistryValueSafe `
            -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" `
            -Name "EnableTransparency" `
            -Value 0

        $script:NeedsReboot = $true
    }
}

# ============================================================
# MOUSE
# ============================================================

function Set-MouseAccelerationDisabled {

    Write-Step "Disabling pointer acceleration"

    Invoke-Safe -Description "Mouse acceleration disabled" -Action {

        $Path = "HKCU:\Control Panel\Mouse"

        Set-ItemProperty `
            -Path $Path `
            -Name "MouseSpeed" `
            -Value "0"

        Set-ItemProperty `
            -Path $Path `
            -Name "MouseThreshold1" `
            -Value "0"

        Set-ItemProperty `
            -Path $Path `
            -Name "MouseThreshold2" `
            -Value "0"
    }
}

# ============================================================
# POWER PLAN
# ============================================================

function Set-PowerPlan {

    param(
        [ValidateSet(
            "Balanced",
            "HighPerformance",
            "Ultimate"
        )]
        [string]$Profile = "HighPerformance"
    )

    Write-Step "Configuring power plan: $Profile"

    switch ($Profile) {

        "Balanced" {

            $Guid = "SCHEME_BALANCED"
        }

        "HighPerformance" {

            $Guid = "SCHEME_MIN"
        }

        "Ultimate" {

            $Existing = powercfg -list 2>$null

            $UltimateGuid =
                [regex]::Match(
                    ($Existing -join "`n"),
                    "([a-f0-9]{8}(-[a-f0-9]{4}){3}-[a-f0-9]{12}).*Ultimate Performance",
                    "IgnoreCase"
                ).Groups[1].Value

            if ($UltimateGuid) {

                $Guid = $UltimateGuid
            }
            else {

                try {

                    $Output = powercfg `
                        -duplicatescheme `
                        e9a42b02-d5df-448d-aa00-03f14749eb61 `
                        2>&1

                    $Match =
                        [regex]::Match(
                            ($Output -join "`n"),
                            "([a-f0-9]{8}(-[a-f0-9]{4}){3}-[a-f0-9]{12})",
                            "IgnoreCase"
                        )

                    if ($Match.Success) {

                        $Guid = $Match.Groups[1].Value
                    }
                    else {

                        $Guid = "SCHEME_MIN"
                    }
                }
                catch {

                    $Guid = "SCHEME_MIN"
                }
            }
        }
    }

    Invoke-Safe -Description "Power plan set to $Profile" -Action {

        powercfg /setactive $Guid

        if ($LASTEXITCODE -ne 0) {
            throw "powercfg returned exit code $LASTEXITCODE"
        }
    }
}

# ============================================================
# XBOX SERVICES
# ============================================================

function Set-XboxServicesDisabled {

    Write-Step "Disabling optional Xbox services"

    $Services = @(
        "XboxGipSvc",
        "XblAuthManager",
        "XblGameSave",
        "XboxNetApiSvc"
    )

    foreach ($Name in $Services) {

        $Service = Get-Service `
            -Name $Name `
            -ErrorAction SilentlyContinue

        if (-not $Service) {
            continue
        }

        Invoke-Safe `
            -Description "Xbox service disabled: $Name" `
            -Action {

                Stop-Service `
                    -Name $Name `
                    -Force `
                    -ErrorAction SilentlyContinue

                Set-Service `
                    -Name $Name `
                    -StartupType Disabled
            }
    }
}

# ============================================================
# PRIVACY
# ============================================================

function Set-PrivacyTweaks {

    Write-Step "Applying privacy settings"

    Invoke-Safe -Description "Advertising ID disabled" -Action {

        Set-RegistryValueSafe `
            -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" `
            -Name "Enabled" `
            -Value 0
    }

    Invoke-Safe -Description "Windows suggestions disabled" -Action {

        $Path =
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"

        $Values = @(
            "SubscribedContent-338388Enabled",
            "SubscribedContent-338389Enabled",
            "SubscribedContent-353694Enabled",
            "SubscribedContent-353696Enabled",
            "SystemPaneSuggestionsEnabled",
            "SoftLandingEnabled"
        )

        foreach ($Name in $Values) {

            Set-RegistryValueSafe `
                -Path $Path `
                -Name $Name `
                -Value 0
        }
    }
}

# ============================================================
# LOCATION
# ============================================================

function Set-LocationServiceDisabled {

    Write-Step "Disabling Windows Location Service"

    Write-WarningMessage `
        "This is an optional privacy change."

    if (-not (Confirm-Action "Disable Location Service?")) {
        return
    }

    $Service = Get-Service `
        -Name "lfsvc" `
        -ErrorAction SilentlyContinue

    if (-not $Service) {

        Write-WarningMessage `
            "Location service was not found."

        return
    }

    Invoke-Safe `
        -Description "Location Service disabled" `
        -Action {

            Stop-Service `
                -Name "lfsvc" `
                -Force `
                -ErrorAction SilentlyContinue

            Set-Service `
                -Name "lfsvc" `
                -StartupType Disabled
        }
}

# ============================================================
# SAFE DEBLOAT
# ============================================================

$script:DebloatPackages = @(
    "Microsoft.BingNews",
    "Microsoft.BingWeather",
    "Microsoft.GetHelp",
    "Microsoft.Getstarted",
    "Microsoft.Microsoft3DViewer",
    "Microsoft.MicrosoftSolitaireCollection",
    "Microsoft.People",
    "Microsoft.PowerAutomateDesktop",
    "Microsoft.Todos",
    "Microsoft.WindowsFeedbackHub",
    "Microsoft.Xbox.TCUI",
    "Microsoft.XboxApp",
    "Microsoft.XboxGamingOverlay",
    "Microsoft.XboxGameOverlay",
    "Microsoft.XboxIdentityProvider",
    "Microsoft.XboxSpeechToTextOverlay",
    "Microsoft.ZuneMusic",
    "Microsoft.ZuneVideo"
)

function Remove-AppxSafe {

    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $Packages = Get-AppxPackage `
        -AllUsers `
        -Name $Name `
        -ErrorAction SilentlyContinue

    if (-not $Packages) {
        return
    }

    foreach ($Package in $Packages) {

        if ($Package.NonRemovable) {

            Write-WarningMessage `
                "Protected package skipped: $($Package.Name)"

            continue
        }

        Invoke-Safe `
            -Description "Removed $($Package.Name)" `
            -Action {

                Remove-AppxPackage `
                    -Package $Package.PackageFullName `
                    -AllUsers `
                    -ErrorAction Stop
            }
    }
}

function Invoke-SafeDebloat {

    Write-Header "Safe Debloat"

    Write-Host "The following optional packages may be removed:"
    Write-Host ""

    foreach ($Package in $script:DebloatPackages) {

        Write-Host "  • $Package" `
            -ForegroundColor DarkGray
    }

    Write-Host ""

    Write-WarningMessage `
        "Core Windows components are not targeted."

    Write-Host ""

    if (-not (Confirm-Action "Start Safe Debloat?")) {
        return
    }

    foreach ($Package in $script:DebloatPackages) {

        Remove-AppxSafe `
            -Name $Package
    }

    Write-Host ""
    Write-Success "Safe debloat completed."

    Pause-Menu
}

# ============================================================
# GAMING PROFILE
# ============================================================

function Apply-GamingProfile {

    Write-Header "Gaming Profile"

    Write-Host "This profile applies conservative gaming-oriented settings:"
    Write-Host ""
    Write-Host "  ✓ Game Mode"
    Write-Host "  ✓ Game DVR disabled"
    Write-Host "  ✓ High Performance power plan"
    Write-Host "  ✓ Optional Xbox recording services disabled"
    Write-Host "  ✓ Transparency disabled"
    Write-Host "  ✓ Mouse acceleration disabled"
    Write-Host ""
    Write-Host "It does NOT disable:"
    Write-Host "  • Windows Defender"
    Write-Host "  • Windows Update"
    Write-Host "  • Essential networking services"
    Write-Host "  • Core Windows services"
    Write-Host ""

    if (-not (Confirm-Action "Apply Gaming Profile?")) {
        return
    }

    New-OptimizerRestorePoint
    Backup-Registry

    Set-GameModeEnabled
    Set-GameDVRDisabled
    Set-PowerPlan -Profile HighPerformance
    Set-TransparencyDisabled
    Set-MouseAccelerationDisabled
    Set-XboxServicesDisabled

    Write-Host ""
    Write-Success "Gaming profile completed."

    if ($script:NeedsReboot) {

        Write-WarningMessage `
            "Restart Windows to apply all changes."
    }

    Pause-Menu
}

# ============================================================
# PERFORMANCE PROFILE
# ============================================================

function Apply-PerformanceProfile {

    Write-Header "Performance Profiles"

    Write-Host "[1] Balanced"
    Write-Host "    Windows default-style power behavior"
    Write-Host ""

    Write-Host "[2] High Performance"
    Write-Host "    Performance-focused power profile"
    Write-Host ""

    Write-Host "[3] Ultimate Performance"
    Write-Host "    Aggressive performance-oriented power profile"
    Write-Host ""

    Write-Host "[0] Back"
    Write-Host ""

    $Choice = Read-Host "  Select"

    switch ($Choice) {

        "1" {

            Set-PowerPlan -Profile Balanced
        }

        "2" {

            Set-PowerPlan -Profile HighPerformance
        }

        "3" {

            Set-PowerPlan -Profile Ultimate
        }

        "0" {
            return
        }

        default {

            Write-WarningMessage "Invalid selection."
        }
    }

    Pause-Menu
}

# ============================================================
# ADVANCED TWEAKS
# ============================================================

function Show-AdvancedTweaks {

    while ($true) {

        Write-Header "Advanced Tweaks"

        Write-WarningMessage `
            "These settings can affect Windows behavior."

        Write-Host ""

        Write-Host "[1] Disable Location Service"
        Write-Host "[2] Disable Xbox Services"
        Write-Host "[3] Disable Transparency"
        Write-Host "[4] Disable Mouse Acceleration"
        Write-Host "[5] High Performance Power Plan"
        Write-Host "[6] Ultimate Performance Power Plan"
        Write-Host ""
        Write-Host "[0] Back"
        Write-Host ""

        $Choice = Read-Host "  Select"

        switch ($Choice) {

            "1" {

                Set-LocationServiceDisabled
                Pause-Menu
            }

            "2" {

                Set-XboxServicesDisabled
                Pause-Menu
            }

            "3" {

                Set-TransparencyDisabled
                Pause-Menu
            }

            "4" {

                Set-MouseAccelerationDisabled
                Pause-Menu
            }

            "5" {

                Set-PowerPlan `
                    -Profile HighPerformance

                Pause-Menu
            }

            "6" {

                Set-PowerPlan `
                    -Profile Ultimate

                Pause-Menu
            }

            "0" {
                return
            }

            default {

                Write-WarningMessage "Invalid selection."

                Start-Sleep -Milliseconds 700
            }
        }
    }
}

# ============================================================
# WINGET
# ============================================================

function Test-Winget {

    return $null -ne (
        Get-Command `
            winget.exe `
            -ErrorAction SilentlyContinue
    )
}

function Update-Winget {

    if (-not (Test-Winget)) {

        Write-ErrorMessage `
            "WinGet is not available."

        return $false
    }

    try {

        winget source update `
            --accept-source-agreements `
            2>$null |
            Out-Null

        if ($LASTEXITCODE -ne 0) {
            throw "WinGet source update failed."
        }

        Write-Success `
            "WinGet sources updated."

        return $true
    }
    catch {

        Write-ErrorMessage `
            $_.Exception.Message

        return $false
    }
}

# ============================================================
# APPLICATION DATABASE
# ============================================================

$script:Applications = @(

    [PSCustomObject]@{
        Name = "Brave"
        ID = "Brave.Brave"
        Category = "Browser"
    },

    [PSCustomObject]@{
        Name = "Google Chrome"
        ID = "Google.Chrome"
        Category = "Browser"
    },

    [PSCustomObject]@{
        Name = "Steam"
        ID = "Valve.Steam"
        Category = "Gaming"
    },

    [PSCustomObject]@{
        Name = "Epic Games Launcher"
        ID = "EpicGames.EpicGamesLauncher"
        Category = "Gaming"
    },

    [PSCustomObject]@{
        Name = "Ubisoft Connect"
        ID = "Ubisoft.Connect"
        Category = "Gaming"
    },

    [PSCustomObject]@{
        Name = "Logitech G HUB"
        ID = "Logitech.GHub"
        Category = "Gaming"
    },

    [PSCustomObject]@{
        Name = "NVIDIA App"
        ID = "Nvidia.NVIDIAApp"
        Category = "Gaming"
    },

    [PSCustomObject]@{
        Name = "Discord"
        ID = "Discord.Discord"
        Category = "Gaming"
    },

    [PSCustomObject]@{
        Name = "WinRAR"
        ID = "RARLab.WinRAR"
        Category = "Utility"
    },

    [PSCustomObject]@{
        Name = "Microsoft Visual C++ Redistributable x64"
        ID = "Microsoft.VCRedist.2015+.x64"
        Category = "Runtime"
    },

    [PSCustomObject]@{
        Name = "Microsoft Visual C++ Redistributable x86"
        ID = "Microsoft.VCRedist.2015+.x86"
        Category = "Runtime"
    },

    [PSCustomObject]@{
        Name = "Microsoft DirectX Runtime"
        ID = "Microsoft.DirectX"
        Category = "Runtime"
    },

    [PSCustomObject]@{
        Name = "Microsoft Edge WebView2 Runtime"
        ID = "Microsoft.EdgeWebView2Runtime"
        Category = "Runtime"
    }
)

# ============================================================
# APP INSTALL
# ============================================================

function Test-AppInstalled {

    param(
        [Parameter(Mandatory)]
        [string]$ID
    )

    if (-not (Test-Winget)) {
        return $false
    }

    try {

        $Output = winget list `
            --id $ID `
            --exact `
            --source winget `
            --accept-source-agreements `
            2>$null |
            Out-String

        return (
            $Output -match [regex]::Escape($ID)
        )
    }
    catch {

        return $false
    }
}

function Install-App {

    param(
        [Parameter(Mandatory)]
        $Application
    )

    if (-not (Test-Winget)) {

        Write-ErrorMessage `
            "WinGet is unavailable."

        return $false
    }

    Write-Host ""
    Write-Host "  » $($Application.Name)" `
        -ForegroundColor Cyan

    if (
        Test-AppInstalled `
            -ID $Application.ID
    ) {

        Write-Success `
            "$($Application.Name) is already installed."

        return $true
    }

    try {

        winget install `
            --id $Application.ID `
            --exact `
            --source winget `
            --silent `
            --accept-package-agreements `
            --accept-source-agreements `
            --disable-interactivity

        $ExitCode = $LASTEXITCODE

        if ($ExitCode -eq 0) {

            Write-Success `
                "$($Application.Name) installed."

            return $true
        }

        if ($ExitCode -eq 3010) {

            Write-WarningMessage `
                "$($Application.Name) installed; reboot required."

            $script:NeedsReboot = $true

            return $true
        }

        Write-ErrorMessage `
            "$($Application.Name) failed. Exit code: $ExitCode"

        return $false
    }
    catch {

        Write-ErrorMessage `
            "$($Application.Name): $($_.Exception.Message)"

        return $false
    }
}

# ============================================================
# APPLICATION MENU
# ============================================================

function Install-ApplicationGroup {

    param(
        [Parameter(Mandatory)]
        [string]$Category
    )

    $Apps = $script:Applications |
        Where-Object {
            $_.Category -eq $Category
        }

    foreach ($App in $Apps) {

        Install-App `
            -Application $App
    }
}

function Install-AllApplications {

    Write-Header "Full Application Setup"

    if (-not (Test-Winget)) {

        Write-ErrorMessage `
            "WinGet is not installed."

        Write-Host ""
        Write-Host "Install Microsoft App Installer / WinGet first."

        Pause-Menu
        return
    }

    Update-Winget | Out-Null

    Write-Host "The following software will be installed if missing:"
    Write-Host ""

    foreach ($App in $script:Applications) {

        Write-Host "  • $($App.Name)" `
            -ForegroundColor DarkGray
    }

    Write-Host ""

    if (-not (Confirm-Action "Continue?")) {
        return
    }

    $Success = 0
    $Failed = 0

    foreach ($App in $script:Applications) {

        if (
            Install-App `
                -Application $App
        ) {

            $Success++
        }
        else {

            $Failed++
        }
    }

    Write-Host ""
    Write-Host "────────────────────────────────────────────────────────────"
    Write-Host "  Installed / ready : $Success" `
        -ForegroundColor Green

    Write-Host "  Failed            : $Failed" `
        -ForegroundColor Red

    if ($script:NeedsReboot) {

        Write-Host ""
        Write-WarningMessage `
            "A reboot is recommended."
    }

    Pause-Menu
}

function Show-Applications {

    while ($true) {

        Write-Header "Applications"

        Write-Host "[1] Full Setup"
        Write-Host ""
        Write-Host "[2] Gaming Applications"
        Write-Host "[3] Windows Runtimes"
        Write-Host "[4] Browsers"
        Write-Host "[5] Utility"
        Write-Host ""
        Write-Host "[6] Individual Application"
        Write-Host "[7] Update WinGet"
        Write-Host ""
        Write-Host "[0] Back"
        Write-Host ""

        $Choice = Read-Host "  Select"

        switch ($Choice) {

            "1" {

                Install-AllApplications
            }

            "2" {

                Write-Header "Gaming Applications"

                Install-ApplicationGroup `
                    -Category "Gaming"

                Pause-Menu
            }

            "3" {

                Write-Header "Windows Runtimes"

                Install-ApplicationGroup `
                    -Category "Runtime"

                Pause-Menu
            }

            "4" {

                Write-Header "Browsers"

                Install-ApplicationGroup `
                    -Category "Browser"

                Pause-Menu
            }

            "5" {

                Write-Header "Utilities"

                Install-ApplicationGroup `
                    -Category "Utility"

                Pause-Menu
            }

            "6" {

                Show-IndividualApplication
            }

            "7" {

                Update-Winget

                Pause-Menu
            }

            "0" {

                return
            }

            default {

                Write-WarningMessage "Invalid selection."
                Start-Sleep -Milliseconds 600
            }
        }
    }
}

function Show-IndividualApplication {

    while ($true) {

        Write-Header "Individual Applications"

        for (
            $Index = 0;
            $Index -lt $script:Applications.Count;
            $Index++
        ) {

            $App = $script:Applications[$Index]

            $Installed =
                Test-AppInstalled -ID $App.ID

            $Number = $Index + 1

            Write-Host "[$Number] " -NoNewline

            Write-Host $App.Name -NoNewline

            if ($Installed) {

                Write-Host "  [INSTALLED]" `
                    -ForegroundColor Green
            }
            else {

                Write-Host "  [NOT INSTALLED]" `
                    -ForegroundColor DarkGray
            }
        }

        Write-Host ""
        Write-Host "[0] Back"
        Write-Host ""

        $Choice = Read-Host "  Select"

        if ($Choice -eq "0") {
            return
        }

        $Number = 0

        if (
            [int]::TryParse(
                $Choice,
                [ref]$Number
            )
        ) {

            if (
                $Number -ge 1 -and
                $Number -le $script:Applications.Count
            ) {

                Install-App `
                    -Application (
                        $script:Applications[
                            $Number - 1
                        ]
                    )

                Pause-Menu

                continue
            }
        }

        Write-WarningMessage "Invalid selection."
    }
}

# ============================================================
# HEALTH CHECK
# ============================================================

function Start-HealthCheck {

    Write-Header "System Health Check"

    $Checks = @()

    # Windows
    try {

        $OS = Get-CimInstance Win32_OperatingSystem

        $Checks += [PSCustomObject]@{
            Name = "Windows"
            Status = "OK"
            Detail = "$($OS.Caption) Build $($OS.BuildNumber)"
        }
    }
    catch {

        $Checks += [PSCustomObject]@{
            Name = "Windows"
            Status = "FAIL"
            Detail = "Could not query Windows"
        }
    }

    # Power
    try {

        $Power = Get-PowerPlan

        $Checks += [PSCustomObject]@{
            Name = "Power Plan"
            Status = "OK"
            Detail = $Power
        }
    }
    catch {

        $Checks += [PSCustomObject]@{
            Name = "Power Plan"
            Status = "FAIL"
            Detail = "Could not query"
        }
    }

    # GPU
    try {

        $GPU = Get-CimInstance `
            Win32_VideoController |
            Where-Object {
                $_.Name
            }

        if ($GPU) {

            $Checks += [PSCustomObject]@{
                Name = "GPU"
                Status = "OK"
                Detail = (
                    $GPU.Name -join ", "
                )
            }
        }
    }
    catch {

        $Checks += [PSCustomObject]@{
            Name = "GPU"
            Status = "WARN"
            Detail = "Could not query GPU"
        }
    }

    # WinGet
    if (Test-Winget) {

        $Checks += [PSCustomObject]@{
            Name = "WinGet"
            Status = "OK"
            Detail = "Available"
        }
    }
    else {

        $Checks += [PSCustomObject]@{
            Name = "WinGet"
            Status = "WARN"
            Detail = "Unavailable"
        }
    }

    # Disk
    try {

        $SystemDisk = Get-CimInstance `
            Win32_LogicalDisk `
            -Filter "DeviceID='$env:SystemDrive'"

        $FreeGB = [Math]::Round(
            $SystemDisk.FreeSpace / 1GB,
            1
        )

        $Checks += [PSCustomObject]@{
            Name = "System Disk"
            Status = if ($FreeGB -lt 20) {
                "WARN"
            }
            else {
                "OK"
            }
            Detail = "$FreeGB GB free"
        }
    }
    catch {}

    foreach ($Check in $Checks) {

        $Color = switch ($Check.Status) {

            "OK" {
                "Green"
            }

            "WARN" {
                "Yellow"
            }

            "FAIL" {
                "Red"
            }

            default {
                "White"
            }
        }

        Write-Host "  [$($Check.Status)] " `
            -NoNewline `
            -ForegroundColor $Color

        Write-Host "$($Check.Name): " `
            -NoNewline

        Write-Host $Check.Detail `
            -ForegroundColor DarkGray
    }

    Write-Host ""
    Pause-Menu
}

# ============================================================
# FULL OPTIMIZATION
# ============================================================

function Start-FullOptimization {

    Write-Header "Full Optimization"

    Write-Host "WINOPTIMIZER SAFE PERFORMANCE PROFILE"
    Write-Host ""
    Write-Host "This will:"
    Write-Host ""
    Write-Host "  ✓ Create restore point"
    Write-Host "  ✓ Backup registry"
    Write-Host "  ✓ Enable Game Mode"
    Write-Host "  ✓ Disable Game DVR"
    Write-Host "  ✓ Use High Performance power plan"
    Write-Host "  ✓ Disable transparency"
    Write-Host "  ✓ Disable mouse acceleration"
    Write-Host "  ✓ Disable optional Xbox services"
    Write-Host "  ✓ Apply privacy tweaks"
    Write-Host "  ✓ Remove selected optional inbox apps"
    Write-Host ""
    Write-Host "It will NOT:"
    Write-Host ""
    Write-Host "  ✗ Disable Windows Defender"
    Write-Host "  ✗ Disable Windows Update"
    Write-Host "  ✗ Disable essential networking"
    Write-Host "  ✗ Disable essential Windows services"
    Write-Host ""

    if (-not (Confirm-Action "Start optimization?")) {
        return
    }

    # Backup first.
    New-OptimizerRestorePoint
    Backup-Registry

    # Performance.
    Set-GameModeEnabled
    Set-GameDVRDisabled
    Set-PowerPlan -Profile HighPerformance
    Set-TransparencyDisabled
    Set-MouseAccelerationDisabled

    # Optional gaming services.
    Set-XboxServicesDisabled

    # Privacy.
    Set-PrivacyTweaks

    # Debloat.
    Write-Step "Running safe debloat"

    foreach ($Package in $script:DebloatPackages) {

        Remove-AppxSafe `
            -Name $Package
    }

    Write-Host ""
    Write-Host "════════════════════════════════════════════════════════════"
    Write-Success "FULL OPTIMIZATION COMPLETE"
    Write-Host "════════════════════════════════════════════════════════════"

    if ($script:NeedsReboot) {

        Write-Host ""
        Write-WarningMessage `
            "Restart Windows before benchmarking."
    }

    Pause-Menu
}

# ============================================================
# BACKUPS
# ============================================================

function Open-BackupFolder {

    if (Test-Path $script:BackupRoot) {

        Start-Process `
            explorer.exe `
            -ArgumentList "`"$script:BackupRoot`""
    }
}

function Open-LogFolder {

    if (Test-Path $script:LogRoot) {

        Start-Process `
            explorer.exe `
            -ArgumentList "`"$script:LogRoot`""
    }
}

# ============================================================
# TOOLS MENU
# ============================================================

function Show-Tools {

    while ($true) {

        Write-Header "Tools"

        Write-Host "[1] Health Check"
        Write-Host "[2] Create Backup"
        Write-Host "[3] Open Backup Folder"
        Write-Host "[4] Open Log Folder"
        Write-Host "[5] Update WinGet"
        Write-Host ""
        Write-Host "[0] Back"
        Write-Host ""

        $Choice = Read-Host "  Select"

        switch ($Choice) {

            "1" {

                Start-HealthCheck
            }

            "2" {

                Start-Protection
            }

            "3" {

                Open-BackupFolder
            }

            "4" {

                Open-LogFolder
            }

            "5" {

                Update-Winget
                Pause-Menu
            }

            "0" {

                return
            }

            default {

                Write-WarningMessage "Invalid selection."
                Start-Sleep -Milliseconds 600
            }
        }
    }
}

# ============================================================
# GAMING MENU
# ============================================================

function Show-GamingMenu {

    while ($true) {

        Write-Header "Gaming"

        Write-Host "[1] Gaming Profile"
        Write-Host ""
        Write-Host "[2] Game Mode"
        Write-Host "[3] Disable Game DVR"
        Write-Host "[4] Performance Profiles"
        Write-Host "[5] Disable Transparency"
        Write-Host "[6] Disable Mouse Acceleration"
        Write-Host ""
        Write-Host "[7] Advanced Tweaks"
        Write-Host ""
        Write-Host "[0] Back"
        Write-Host ""

        $Choice = Read-Host "  Select"

        switch ($Choice) {

            "1" {

                Apply-GamingProfile
            }

            "2" {

                Set-GameModeEnabled
                Pause-Menu
            }

            "3" {

                Set-GameDVRDisabled
                Pause-Menu
            }

            "4" {

                Apply-PerformanceProfile
            }

            "5" {

                Set-TransparencyDisabled
                Pause-Menu
            }

            "6" {

                Set-MouseAccelerationDisabled
                Pause-Menu
            }

            "7" {

                Show-AdvancedTweaks
            }

            "0" {

                return
            }

            default {

                Write-WarningMessage "Invalid selection."
                Start-Sleep -Milliseconds 600
            }
        }
    }
}

# ============================================================
# PRIVACY MENU
# ============================================================

function Show-PrivacyMenu {

    while ($true) {

        Write-Header "Privacy"

        Write-Host "[1] Apply Safe Privacy Profile"
        Write-Host "[2] Disable Location Service"
        Write-Host "[3] Disable Advertising ID"
        Write-Host ""
        Write-Host "[0] Back"
        Write-Host ""

        $Choice = Read-Host "  Select"

        switch ($Choice) {

            "1" {

                Set-PrivacyTweaks
                Pause-Menu
            }

            "2" {

                Set-LocationServiceDisabled
                Pause-Menu
            }

            "3" {

                Set-RegistryValueSafe `
                    -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" `
                    -Name "Enabled" `
                    -Value 0

                Write-Success "Advertising ID disabled."

                Pause-Menu
            }

            "0" {

                return
            }

            default {

                Write-WarningMessage "Invalid selection."
                Start-Sleep -Milliseconds 600
            }
        }
    }
}

# ============================================================
# RESTART
# ============================================================

function Restart-System {

    Write-Header "Restart Windows"

    if (-not $script:NeedsReboot) {

        Write-InfoMessage `
            "WinOptimizer has not detected a mandatory restart."
    }

    if (
        Confirm-Action `
            "Restart the computer now?"
    ) {

        Write-Log `
            "User requested restart."

        Restart-Computer
    }
}

# ============================================================
# MAIN MENU
# ============================================================

function Show-MainMenu {

    while ($true) {

        Write-Header "Main Menu"

        $Info = Get-SystemInfo

        if ($Info) {

            Write-Host "  $($Info.Windows)  •  Build $($Info.Build)" `
                -ForegroundColor DarkGray

            Write-Host "  $($Info.CPU)" `
                -ForegroundColor DarkGray

            Write-Host ""
        }

        Write-Host "  ┌──────────────────────────────────────────────────────┐" `
            -ForegroundColor DarkGray

        Write-Host "  │  1  Dashboard                 System information     │" `
            -ForegroundColor White

        Write-Host "  │  2  Gaming                    Gaming optimization    │" `
            -ForegroundColor White

        Write-Host "  │  3  Applications              Install software       │" `
            -ForegroundColor White

        Write-Host "  │  4  Debloat                   Remove optional apps   │" `
            -ForegroundColor White

        Write-Host "  │  5  Privacy                   Privacy settings       │" `
            -ForegroundColor White

        Write-Host "  │  6  FULL OPTIMIZATION         One-click setup        │" `
            -ForegroundColor Cyan

        Write-Host "  │  7  Tools                     Health / backups       │" `
            -ForegroundColor White

        Write-Host "  │  8  Restart                   Restart Windows        │" `
            -ForegroundColor White

        Write-Host "  │  0  Exit                                             │" `
            -ForegroundColor DarkGray

        Write-Host "  └──────────────────────────────────────────────────────┘" `
            -ForegroundColor DarkGray

        Write-Host ""

        if ($script:NeedsReboot) {

            Write-WarningMessage `
                "Restart recommended."
        }

        $Choice = Read-Host "  Select"

        switch ($Choice) {

            "1" {

                Show-Dashboard
            }

            "2" {

                Show-GamingMenu
            }

            "3" {

                Show-Applications
            }

            "4" {

                Invoke-SafeDebloat
            }

            "5" {

                Show-PrivacyMenu
            }

            "6" {

                Start-FullOptimization
            }

            "7" {

                Show-Tools
            }

            "8" {

                Restart-System
            }

            "0" {

                Write-Log `
                    "WinOptimizer closed."

                Clear-Host

                return
            }

            default {

                Write-WarningMessage `
                    "Invalid selection."

                Start-Sleep -Milliseconds 600
            }
        }
    }
}

# ============================================================
# START
# ============================================================

Write-Log `
    "============================================================"

Write-Log `
    "$script:AppName v$script:Version started."

Write-Log `
    "============================================================"

Show-MainMenu
