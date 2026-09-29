#requires -Version 5.1

<#
.SYNOPSIS
    WinSetup - Windows Setup, Debloat & Gaming Utility

.DESCRIPTION
    Interactive Windows setup utility.

    Main modes:
      1. Dashboard
      2. Full PC Setup
      3. Gaming Tweaks
      4. Applications
      5. Debloat
      6. Privacy
      7. Health Check
      8. Backup / Restore Point

    Full PC Setup:
      - Creates restore point
      - Creates WinSetup backup
      - Applies all gaming tweaks
      - Applies all privacy tweaks
      - Performs safe debloat
      - Installs all supported applications
      - Runs health check

    Other modes are opt-in and ask before making changes.

.NOTES
    PowerShell 5.1 compatible
#>

[CmdletBinding()]
param(
    [switch]$Setup,
    [switch]$Gaming,
    [switch]$Debloat,
    [switch]$Apps,
    [switch]$Privacy,
    [switch]$Preview,
    [switch]$Repair
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ============================================================
# CONFIGURATION
# ============================================================

$script:AppName = "WinSetup"
$script:Version = "4.0.0"

$script:Root = Join-Path $env:ProgramData "WinSetup"
$script:LogDir = Join-Path $script:Root "Logs"
$script:BackupDir = Join-Path $script:Root "Backups"
$script:LogFile = Join-Path $script:LogDir "WinSetup.log"

$script:PreviewMode = [bool]$Preview
$script:NeedsReboot = $false
$script:ChangesMade = $false

# ============================================================
# APPLICATION DATABASE
# ============================================================

$script:Applications = @(

    [PSCustomObject]@{
        Number   = 1
        Name     = "Brave"
        ID       = "Brave.Brave"
        Category = "Browser"
        Source   = "winget"
        Official = "https://brave.com/download/"
    }

    [PSCustomObject]@{
        Number   = 2
        Name     = "Google Chrome"
        ID       = "Google.Chrome"
        Category = "Browser"
        Source   = "winget"
        Official = "https://www.google.com/chrome/"
    }

    [PSCustomObject]@{
        Number   = 3
        Name     = "Steam"
        ID       = "Valve.Steam"
        Category = "Gaming"
        Source   = "winget"
        Official = "https://store.steampowered.com/about/"
    }

    [PSCustomObject]@{
        Number   = 4
        Name     = "Epic Games Launcher"
        ID       = "EpicGames.EpicGamesLauncher"
        Category = "Gaming"
        Source   = "winget"
        Official = "https://store.epicgames.com/download"
    }

    [PSCustomObject]@{
        Number   = 5
        Name     = "Ubisoft Connect"
        ID       = "Ubisoft.Connect"
        Category = "Gaming"
        Source   = "winget"
        Official = "https://ubisoftconnect.com/"
    }

    [PSCustomObject]@{
        Number   = 6
        Name     = "Logitech G HUB"
        ID       = "Logitech.GHUB"
        Category = "Gaming"
        Source   = "winget"
        Official = "https://www.logitechg.com/ghub"
    }

    [PSCustomObject]@{
        Number   = 7
        Name     = "NVIDIA App"
        ID       = $null
        Category = "Gaming"
        Source   = "manual"
        Official = "https://www.nvidia.com/en-us/software/nvidia-app/"
    }

    [PSCustomObject]@{
        Number   = 8
        Name     = "WinRAR"
        ID       = "RARLab.WinRAR"
        Category = "Utility"
        Source   = "winget"
        Official = "https://www.win-rar.com/"
    }

    [PSCustomObject]@{
        Number   = 9
        Name     = "Microsoft Visual C++ Redistributable x64"
        ID       = "Microsoft.VCRedist.2015+.x64"
        Category = "Runtime"
        Source   = "winget"
        Official = "https://learn.microsoft.com/cpp/windows/latest-supported-vc-redist"
    }

    [PSCustomObject]@{
        Number   = 10
        Name     = "Microsoft Visual C++ Redistributable x86"
        ID       = "Microsoft.VCRedist.2015+.x86"
        Category = "Runtime"
        Source   = "winget"
        Official = "https://learn.microsoft.com/cpp/windows/latest-supported-vc-redist"
    }

    [PSCustomObject]@{
        Number   = 11
        Name     = "DirectX End-User Runtime"
        ID       = $null
        Category = "Runtime"
        Source   = "manual"
        Official = "https://www.microsoft.com/download/details.aspx?id=8109"
    }

    [PSCustomObject]@{
        Number   = 12
        Name     = "Microsoft Edge WebView2"
        ID       = "Microsoft.EdgeWebView2Runtime"
        Category = "Runtime"
        Source   = "winget"
        Official = "https://developer.microsoft.com/microsoft-edge/webview2/"
    }
)

# ============================================================
# DEBLOAT DATABASE
# ============================================================

$script:DebloatList = @(
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
    "Microsoft.ZuneMusic",
    "Microsoft.ZuneVideo"
)

# ============================================================
# LOGGING
# ============================================================

function Write-Log {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    try {
        $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

        Add-Content `
            -LiteralPath $script:LogFile `
            -Value "$Timestamp | $Message" `
            -Encoding UTF8
    }
    catch {
        # Logging must never crash WinSetup.
    }
}

# ============================================================
# UI
# ============================================================

function Write-Line {
    Write-Host "  ─────────────────────────────────────────────────────────────" `
        -ForegroundColor DarkGray
}

function Write-Section {
    param(
        [Parameter(Mandatory)]
        [string]$Title
    )

    Write-Host ""
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Line
}

function Write-OK {
    param([string]$Message)

    Write-Host "  " -NoNewline
    Write-Host "✓" -NoNewline -ForegroundColor Green
    Write-Host " $Message"
}

function Write-Warn {
    param([string]$Message)

    Write-Host "  " -NoNewline
    Write-Host "!" -NoNewline -ForegroundColor Yellow
    Write-Host " $Message"
}

function Write-Fail {
    param([string]$Message)

    Write-Host "  " -NoNewline
    Write-Host "✗" -NoNewline -ForegroundColor Red
    Write-Host " $Message"
}

function Write-Info {
    param([string]$Message)

    Write-Host "  " -NoNewline
    Write-Host "i" -NoNewline -ForegroundColor Cyan
    Write-Host " $Message"
}

function Pause-Menu {
    Write-Host ""
    [void](Read-Host "  Press ENTER to continue")
}

function Test-Yes {
    param([string]$Value)

    return $Value -match "^(Y|YES|J|JA)$"
}

function Clear-And-Logo {
    Clear-Host
    Write-Logo
}

function Write-Logo {

    Write-Host ""

    Write-Host "   ██╗    ██╗██╗███╗   ██╗███████╗███████╗████████╗██╗   ██╗██████╗" `
        -ForegroundColor Cyan

    Write-Host "   ██║    ██║██║████╗  ██║██╔════╝██╔════╝╚══██╔══╝██║   ██║██╔══██╗" `
        -ForegroundColor Cyan

    Write-Host "   ██║ █╗ ██║██║██╔██╗ ██║███████╗█████╗     ██║   ██║   ██║██████╔╝" `
        -ForegroundColor Cyan

    Write-Host "   ██║███╗██║██║██║╚██╗██║╚════██║██╔══╝     ██║   ██║   ██║██╔═══╝ " `
        -ForegroundColor Cyan

    Write-Host "   ╚███╔███╔╝██║██║ ╚████║███████║███████╗   ██║   ╚██████╔╝██║     " `
        -ForegroundColor Cyan

    Write-Host "    ╚══╝╚══╝ ╚═╝╚═╝  ╚═══╝╚══════╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝     " `
        -ForegroundColor Cyan

    Write-Host ""
    Write-Host "                    Windows Setup Utility" `
        -ForegroundColor DarkGray

    Write-Host "                         v$script:Version" `
        -ForegroundColor DarkGray

    if ($script:PreviewMode) {

        Write-Host ""
        Write-Host "                         PREVIEW MODE" `
            -ForegroundColor Yellow
    }

    Write-Host ""
}

# ============================================================
# ADMINISTRATOR
# ============================================================

function Test-IsAdmin {

    $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()

    $Principal = New-Object Security.Principal.WindowsPrincipal($Identity)

    return $Principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

function Restart-AsAdmin {

    if (Test-IsAdmin) {
        return
    }

    Write-Host ""
    Write-Warn "WinSetup requires Administrator privileges."

    if ([string]::IsNullOrWhiteSpace($PSCommandPath)) {

        throw @"
WinSetup is not running as Administrator.

When using:
irm <WinSetup URL> | iex

start PowerShell as Administrator before running WinSetup.
"@
    }

    try {

        $Arguments = @(
            "-NoProfile"
            "-ExecutionPolicy"
            "Bypass"
            "-File"
            "`"$PSCommandPath`""
        )

        if ($Setup)   { $Arguments += "-Setup" }
        if ($Gaming)  { $Arguments += "-Gaming" }
        if ($Debloat) { $Arguments += "-Debloat" }
        if ($Apps)    { $Arguments += "-Apps" }
        if ($Privacy) { $Arguments += "-Privacy" }
        if ($Preview) { $Arguments += "-Preview" }
        if ($Repair)  { $Arguments += "-Repair" }

        Start-Process `
            -FilePath "powershell.exe" `
            -ArgumentList ($Arguments -join " ") `
            -Verb RunAs `
            -ErrorAction Stop |
            Out-Null

        exit
    }
    catch {

        throw "Could not restart WinSetup as Administrator: $($_.Exception.Message)"
    }
}

# ============================================================
# INITIALIZATION
# ============================================================

function Initialize-WinSetup {

    foreach ($Path in @(
        $script:Root,
        $script:LogDir,
        $script:BackupDir
    )) {

        if (-not (Test-Path -LiteralPath $Path)) {

            New-Item `
                -Path $Path `
                -ItemType Directory `
                -Force |
                Out-Null
        }
    }

    Write-Log "======================================================"
    Write-Log "$script:AppName $script:Version started"
    Write-Log "Preview=$script:PreviewMode"
    Write-Log "======================================================"
}

# ============================================================
# SYSTEM INFORMATION
# ============================================================

function Get-SystemInformation {

    $OS = Get-CimInstance Win32_OperatingSystem

    $CPU = Get-CimInstance Win32_Processor |
        Select-Object -First 1

    $GPU = @(
        Get-CimInstance Win32_VideoController |
        Where-Object {
            $_.Name -and
            $_.Name -notmatch "Microsoft Basic"
        }
    )

    $RAM = [Math]::Round(
        $OS.TotalVisibleMemorySize / 1MB,
        1
    )

    $Disk = Get-CimInstance Win32_LogicalDisk `
        -Filter "DeviceID='$env:SystemDrive'"

    $FreeDisk = 0

    if ($null -ne $Disk -and $null -ne $Disk.FreeSpace) {

        $FreeDisk = [Math]::Round(
            $Disk.FreeSpace / 1GB,
            1
        )
    }

    [PSCustomObject]@{
        ComputerName = $env:COMPUTERNAME
        Windows      = $OS.Caption
        Version      = $OS.Version
        Build        = $OS.BuildNumber
        CPU          = $CPU.Name
        RAM          = $RAM
        GPU          = ($GPU.Name -join ", ")
        FreeDisk     = $FreeDisk
    }
}

function Get-DeviceType {

    $Battery = Get-CimInstance `
        Win32_Battery `
        -ErrorAction SilentlyContinue

    if ($null -ne $Battery) {
        return "Laptop"
    }

    return "Desktop"
}

function Get-GPUVendor {

    $GPUs = @(
        Get-CimInstance Win32_VideoController `
            -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name
        }
    )

    foreach ($GPU in $GPUs) {

        if ($GPU.Name -match "NVIDIA") {
            return "NVIDIA"
        }

        if ($GPU.Name -match "AMD|Radeon") {
            return "AMD"
        }

        if ($GPU.Name -match "Intel") {
            return "Intel"
        }
    }

    return "Unknown"
}

# ============================================================
# WINGET
# ============================================================

function Get-WinGetPath {

    $Command = Get-Command `
        winget.exe `
        -ErrorAction SilentlyContinue

    if ($null -ne $Command) {
        return $Command.Source
    }

    return $null
}

function Test-WinGet {
    return $null -ne (Get-WinGetPath)
}

function Update-WinGetSource {

    if (-not (Test-WinGet)) {
        return $false
    }

    try {

        $null = @(
            & winget source update `
                --accept-source-agreements `
                --disable-interactivity `
                2>&1
        )

        return ($LASTEXITCODE -eq 0)
    }
    catch {

        Write-Log `
            "WinGet source update failed: $($_.Exception.Message)"

        return $false
    }
}

# ============================================================
# APPLICATION DETECTION
# ============================================================

function Test-ApplicationInstalled {

    param(
        [Parameter(Mandatory)]
        $Application
    )

    if ($Application.Source -ne "winget") {
        return $false
    }

    if ([string]::IsNullOrWhiteSpace($Application.ID)) {
        return $false
    }

    if (-not (Test-WinGet)) {
        return $false
    }

    try {

        $Output = @(
            & winget list `
                --id $Application.ID `
                --exact `
                --source winget `
                --accept-source-agreements `
                --disable-interactivity `
                2>&1
        )

        $ExitCode = $LASTEXITCODE

        if ($ExitCode -ne 0) {
            return $false
        }

        $Text = $Output -join "`n"

        return $Text -match [regex]::Escape($Application.ID)
    }
    catch {

        Write-Log `
            "Detection failed for $($Application.Name): $($_.Exception.Message)"

        return $false
    }
}

# ============================================================
# APPLICATION INSTALLATION
# ============================================================

function Install-WinGetApplication {

    param(
        [Parameter(Mandatory)]
        $Application
    )

    Write-Host ""
    Write-Host "  Installing " -NoNewline
    Write-Host $Application.Name -ForegroundColor Cyan
    Write-Line

    if ($script:PreviewMode) {

        Write-Info "PREVIEW: $($Application.ID)"

        return [PSCustomObject]@{
            Name   = $Application.Name
            Status = "Preview"
        }
    }

    if (-not (Test-WinGet)) {

        Write-Fail "WinGet is unavailable."

        return [PSCustomObject]@{
            Name   = $Application.Name
            Status = "Failed - WinGet unavailable"
        }
    }

    if (Test-ApplicationInstalled $Application) {

        Write-OK "$($Application.Name) is already installed."

        return [PSCustomObject]@{
            Name   = $Application.Name
            Status = "Already Installed"
        }
    }

    try {

        $Output = @(
            & winget install `
                --id $Application.ID `
                --exact `
                --source winget `
                --silent `
                --accept-package-agreements `
                --accept-source-agreements `
                --disable-interactivity `
                2>&1
        )

        $ExitCode = $LASTEXITCODE

        foreach ($Line in $Output) {

            if ($null -ne $Line) {

                Write-Log `
                    "$($Application.Name) | $Line"
            }
        }

        if ($ExitCode -eq 0) {

            Write-OK "$($Application.Name) installed."

            $script:ChangesMade = $true

            return [PSCustomObject]@{
                Name   = $Application.Name
                Status = "Installed"
            }
        }

        if ($ExitCode -eq 3010) {

            Write-OK "$($Application.Name) installed."
            Write-Warn "Restart may be required."

            $script:NeedsReboot = $true
            $script:ChangesMade = $true

            return [PSCustomObject]@{
                Name   = $Application.Name
                Status = "Installed - Reboot"
            }
        }

        Write-Fail `
            "$($Application.Name) failed with exit code $ExitCode."

        return [PSCustomObject]@{
            Name   = $Application.Name
            Status = "Failed ($ExitCode)"
        }
    }
    catch {

        Write-Fail `
            "$($Application.Name): $($_.Exception.Message)"

        Write-Log `
            "$($Application.Name) exception: $($_.Exception | Out-String)"

        return [PSCustomObject]@{
            Name   = $Application.Name
            Status = "Failed"
        }
    }
}

function Open-ApplicationWebsite {

    param(
        [Parameter(Mandatory)]
        $Application
    )

    try {

        Start-Process `
            -FilePath $Application.Official `
            -ErrorAction Stop |
            Out-Null

        Write-OK `
            "Opened official page for $($Application.Name)."
    }
    catch {

        Write-Fail `
            "Could not open official page."

        Write-Log `
            "Website error: $($_.Exception.Message)"
    }
}

# ============================================================
# APPLICATION MENU
# ============================================================

function Get-ApplicationStatus {

    param(
        [Parameter(Mandatory)]
        $Application
    )

    if ($Application.Source -eq "manual") {
        return "manual"
    }

    if (-not (Test-WinGet)) {
        return "unknown"
    }

    if (Test-ApplicationInstalled $Application) {
        return "installed"
    }

    return "available"
}

function Show-ApplicationList {

    param(
        [array]$Selected
    )

    Write-Host ""
    Write-Host "  APPLICATIONS" -ForegroundColor Cyan
    Write-Line

    foreach ($Application in $script:Applications) {

        $SelectedNow = $Selected -contains $Application.Number

        $Marker = if ($SelectedNow) { "✓" } else { "○" }

        $Color = if ($SelectedNow) {
            "Green"
        }
        else {
            "DarkGray"
        }

        $Status = Get-ApplicationStatus $Application

        $StatusText = switch ($Status) {

            "installed" { " [installed]" }
            "manual"    { " [manual]" }
            "unknown"   { " [WinGet unavailable]" }
            default     { "" }
        }

        Write-Host "  [$($Application.Number.ToString().PadLeft(2))] " `
            -NoNewline `
            -ForegroundColor DarkGray

        Write-Host $Marker `
            -NoNewline `
            -ForegroundColor $Color

        Write-Host " $($Application.Name)" `
            -NoNewline `
            -ForegroundColor White

        Write-Host $StatusText `
            -ForegroundColor DarkGray
    }

    Write-Host ""
    Write-Line

    Write-Host "  [A] " -NoNewline -ForegroundColor Cyan
    Write-Host "Select ALL"

    Write-Host "  [C] " -NoNewline -ForegroundColor Cyan
    Write-Host "Clear selection"

    Write-Host "  [I] " -NoNewline -ForegroundColor Green
    Write-Host "Install selected"

    Write-Host "  [O] " -NoNewline -ForegroundColor Cyan
    Write-Host "Open manual download"

    Write-Host "  [0] " -NoNewline -ForegroundColor DarkGray
    Write-Host "Back"

    Write-Host ""
}

function Install-AllApplications {

    Clear-And-Logo

    Write-Section "INSTALL ALL APPLICATIONS"

    Write-Info `
        "WinSetup will process every application in the application database."

    Write-Host ""

    foreach ($Application in $script:Applications) {

        Write-Host "  • $($Application.Name)"
    }

    Write-Host ""

    if ($script:PreviewMode) {

        Write-Warn `
            "Preview mode is active."

        Pause-Menu

        return
    }

    Write-Host ""

    $Confirm = Read-Host `
        "  Install/process ALL applications? [Y/N]"

    if (-not (Test-Yes $Confirm)) {

        Write-Info "Cancelled."

        Pause-Menu

        return
    }

    if (Test-WinGet) {

        Write-Info "Updating WinGet sources..."

        if (Update-WinGetSource) {

            Write-OK "WinGet source updated."
        }
        else {

            Write-Warn `
                "WinGet source update failed. Continuing."
        }
    }
    else {

        Write-Warn `
            "WinGet is unavailable. Manual applications will still be opened."
    }

    $Results = New-Object System.Collections.Generic.List[object]

    foreach ($Application in $script:Applications) {

        if ($Application.Source -eq "winget") {

            $Result = Install-WinGetApplication `
                -Application $Application

            if ($null -ne $Result) {
                $Results.Add($Result)
            }
        }
        else {

            Write-Host ""
            Write-Host "  $($Application.Name)" `
                -ForegroundColor Cyan

            Write-Info `
                "Opening official download page."

            Open-ApplicationWebsite `
                -Application $Application

            $Results.Add(
                [PSCustomObject]@{
                    Name   = $Application.Name
                    Status = "Manual"
                }
            )
        }
    }

    Show-ApplicationResults `
        -Results $Results

    Pause-Menu
}

function Show-ApplicationResults {

    param(
        [Parameter(Mandatory)]
        $Results
    )

    Write-Section "APPLICATION SUMMARY"

    foreach ($Result in $Results) {

        if ($null -eq $Result) {
            continue
        }

        switch -Regex ($Result.Status) {

            "^Installed$" {

                Write-OK "$($Result.Name) - installed"
                break
            }

            "^Installed - Reboot$" {

                Write-OK "$($Result.Name) - installed"
                Write-Warn "$($Result.Name) may require a restart."
                break
            }

            "^Already Installed$" {

                Write-OK "$($Result.Name) - already installed"
                break
            }

            "^Manual$" {

                Write-Info "$($Result.Name) - manual installation"
                break
            }

            "^Preview$" {

                Write-Info "$($Result.Name) - preview"
                break
            }

            default {

                Write-Fail "$($Result.Name) - $($Result.Status)"
                break
            }
        }
    }
}

function Install-SelectedApplications {

    param(
        [Parameter(Mandatory)]
        [array]$SelectedNumbers
    )

    $SelectedApplications = @(
        foreach ($Number in $SelectedNumbers) {

            $script:Applications |
                Where-Object {
                    $_.Number -eq $Number
                } |
                Select-Object -First 1
        }
    )

    if ($SelectedApplications.Count -eq 0) {

        Write-Warn "No applications selected."
        Pause-Menu

        return
    }

    Clear-And-Logo

    Write-Section "INSTALLATION REVIEW"

    foreach ($Application in $SelectedApplications) {

        Write-Host "  • $($Application.Name)"
    }

    Write-Host ""

    if ($script:PreviewMode) {

        Write-Warn `
            "Preview mode is active."

        Pause-Menu

        return
    }

    $Confirm = Read-Host "  Continue? [Y/N]"

    if (-not (Test-Yes $Confirm)) {

        Write-Info "Cancelled."

        Pause-Menu

        return
    }

    $Results = New-Object System.Collections.Generic.List[object]

    foreach ($Application in $SelectedApplications) {

        if ($Application.Source -eq "winget") {

            $Result = Install-WinGetApplication `
                -Application $Application

            if ($null -ne $Result) {
                $Results.Add($Result)
            }
        }
        else {

            Write-Host ""
            Write-Host "  $($Application.Name)" `
                -ForegroundColor Cyan

            Open-ApplicationWebsite `
                -Application $Application

            $Results.Add(
                [PSCustomObject]@{
                    Name   = $Application.Name
                    Status = "Manual"
                }
            )
        }
    }

    Show-ApplicationResults `
        -Results $Results

    Pause-Menu
}

function Select-Applications {

    $Selected = @()

    while ($true) {

        Clear-And-Logo

        Show-ApplicationList `
            -Selected $Selected

        $Input = Read-Host "  Select"

        if ([string]::IsNullOrWhiteSpace($Input)) {
            continue
        }

        $Input = $Input.Trim().ToUpperInvariant()

        if ($Input -eq "0") {
            return
        }

        # ----------------------------------------------------
        # INSTALL ALL
        # ----------------------------------------------------

        if ($Input -eq "A") {

            Install-AllApplications

            $Selected = @()

            continue
        }

        # ----------------------------------------------------
        # CLEAR
        # ----------------------------------------------------

        if ($Input -eq "C") {

            $Selected = @()

            continue
        }

        # ----------------------------------------------------
        # INSTALL SELECTED
        # ----------------------------------------------------

        if ($Input -eq "I") {

            Install-SelectedApplications `
                -SelectedNumbers $Selected

            $Selected = @()

            continue
        }

        # ----------------------------------------------------
        # MANUAL DOWNLOAD
        # ----------------------------------------------------

        if ($Input -eq "O") {

            Clear-And-Logo

            Write-Section "MANUAL APPLICATIONS"

            foreach ($Application in $script:Applications) {

                if ($Application.Source -eq "manual") {

                    Write-Host "  [$($Application.Number)] " `
                        -NoNewline `
                        -ForegroundColor Cyan

                    Write-Host $Application.Name
                }
            }

            Write-Host ""

            $Number = Read-Host `
                "  Application number"

            $Manual = $script:Applications |
                Where-Object {
                    "$($_.Number)" -eq $Number -and
                    $_.Source -eq "manual"
                } |
                Select-Object -First 1

            if ($null -ne $Manual) {

                Open-ApplicationWebsite `
                    -Application $Manual

                Pause-Menu
            }
            else {

                Write-Warn "Invalid application."
                Start-Sleep -Milliseconds 700
            }

            continue
        }

        # ----------------------------------------------------
        # TOGGLE NUMBERS
        # ----------------------------------------------------

        $Tokens = $Input -split "[,\s]+"

        foreach ($Token in $Tokens) {

            $Number = 0

            if (
                -not [int]::TryParse(
                    $Token,
                    [ref]$Number
                )
            ) {
                continue
            }

            $Application = $script:Applications |
                Where-Object {
                    $_.Number -eq $Number
                } |
                Select-Object -First 1

            if ($null -eq $Application) {
                continue
            }

            if ($Selected -contains $Number) {

                $Selected = @(
                    $Selected |
                    Where-Object {
                        $_ -ne $Number
                    }
                )
            }
            else {

                $Selected += $Number
            }
        }
    }
}

# ============================================================
# REGISTRY HELPER
# ============================================================

function Set-RegDWORD {

    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [int]$Value
    )

    if ($script:PreviewMode) {

        Write-Info `
            "PREVIEW: $Path\$Name = $Value"

        return
    }

    if (-not (Test-Path -LiteralPath $Path)) {

        New-Item `
            -Path $Path `
            -Force |
            Out-Null
    }

    New-ItemProperty `
        -Path $Path `
        -Name $Name `
        -Value $Value `
        -PropertyType DWord `
        -Force |
        Out-Null

    $script:ChangesMade = $true
}

# ============================================================
# BACKUP
# ============================================================

function New-WindowsRestorePoint {

    if ($script:PreviewMode) {

        Write-Info `
            "PREVIEW: Restore point would be created."

        return
    }

    try {

        Enable-ComputerRestore `
            -Drive "$env:SystemDrive\" `
            -ErrorAction SilentlyContinue

        Checkpoint-Computer `
            -Description "WinSetup $script:Version" `
            -RestorePointType MODIFY_SETTINGS `
            -ErrorAction Stop

        Write-OK "Windows restore point created."
    }
    catch {

        Write-Warn `
            "Could not create a restore point."

        Write-Log `
            "Restore point failed: $($_.Exception.Message)"
    }
}

function New-WinSetupBackup {

    if ($script:PreviewMode) {

        Write-Info `
            "PREVIEW: Backup would be created."

        return
    }

    try {

        $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

        $BackupPath = Join-Path `
            $script:BackupDir `
            $Timestamp

        New-Item `
            -Path $BackupPath `
            -ItemType Directory `
            -Force |
            Out-Null

        $RegistryBackups = @(
            @{
                Hive = "HKCU\System\GameConfigStore"
                File = "GameConfigStore.reg"
            }

            @{
                Hive = "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR"
                File = "GameDVR.reg"
            }

            @{
                Hive = "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
                File = "Personalize.reg"
            }

            @{
                Hive = "HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo"
                File = "AdvertisingInfo.reg"
            }
        )

        foreach ($Backup in $RegistryBackups) {

            try {

                $null = @(
                    & reg.exe export `
                        $Backup.Hive `
                        (Join-Path $BackupPath $Backup.File) `
                        /y `
                        2>&1
                )
            }
            catch {

                Write-Log `
                    "Registry backup failed: $($Backup.Hive)"
            }
        }

        try {

            @(
                Get-Service |
                Select-Object Name, Status, StartType
            ) |
            ConvertTo-Json |
            Out-File `
                (Join-Path $BackupPath "services.json") `
                -Encoding UTF8
        }
        catch {

            Write-Log "Service backup failed."
        }

        try {

            @(
                & powercfg /getactivescheme 2>&1
            ) |
            Out-File `
                (Join-Path $BackupPath "powerplan.txt") `
                -Encoding UTF8
        }
        catch {

            Write-Log "Power plan backup failed."
        }

        Write-OK "Backup created."
        Write-Info $BackupPath
    }
    catch {

        Write-Fail `
            "Backup failed: $($_.Exception.Message)"

        Write-Log `
            "Backup exception: $($_.Exception | Out-String)"
    }
}

# ============================================================
# POWER PLAN
# ============================================================

function Get-ActivePowerPlan {

    try {

        $Output = @(
            & powercfg /getactivescheme 2>&1
        )

        $Text = $Output -join " "

        if ($Text -match "Ultimate Performance") {
            return "Ultimate Performance"
        }

        if ($Text -match "High performance") {
            return "High Performance"
        }

        if ($Text -match "Balanced") {
            return "Balanced"
        }

        if ($Text -match "Power saver") {
            return "Power Saver"
        }

        return "Custom"
    }
    catch {

        return "Unknown"
    }
}

function Set-HighPerformance {

    if ($script:PreviewMode) {

        Write-Info `
            "PREVIEW: High Performance power plan."

        return
    }

    try {

        $null = @(
            & powercfg /setactive SCHEME_MIN 2>&1
        )

        if ($LASTEXITCODE -ne 0) {

            throw `
                "powercfg returned exit code $LASTEXITCODE"
        }

        Write-OK `
            "High Performance power plan enabled."

        $script:ChangesMade = $true
    }
    catch {

        Write-Fail `
            "Could not enable High Performance."

        Write-Log `
            "Power plan failed: $($_.Exception.Message)"
    }
}

# ============================================================
# TWEAK ENGINE
# ============================================================

function Invoke-Tweak {

    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [scriptblock]$Apply,

        [scriptblock]$Verify
    )

    Write-Host ""
    Write-Host "  $Name" -ForegroundColor Cyan

    try {

        & $Apply

        if ($script:PreviewMode) {
            return
        }

        if ($null -ne $Verify) {

            $Verified = & $Verify

            if ($Verified) {

                Write-OK $Name
            }
            else {

                Write-Warn `
                    "$Name changed, but verification failed."
            }
        }
        else {

            Write-OK $Name
        }

        $script:ChangesMade = $true
    }
    catch {

        Write-Fail `
            "$Name : $($_.Exception.Message)"

        Write-Log `
            "$Name FAILED: $($_.Exception | Out-String)"
    }
}

# ============================================================
# GAMING TWEAKS
# ============================================================

function Enable-GameMode {

    Invoke-Tweak `
        -Name "Enable Windows Game Mode" `
        -Apply {

            Set-RegDWORD `
                "HKCU:\Software\Microsoft\GameBar" `
                "AutoGameModeEnabled" `
                1
        } `
        -Verify {

            $Value = Get-ItemProperty `
                "HKCU:\Software\Microsoft\GameBar" `
                -Name "AutoGameModeEnabled" `
                -ErrorAction SilentlyContinue

            return (
                $null -ne $Value -and
                $Value.AutoGameModeEnabled -eq 1
            )
        }
}

function Disable-GameDVR {

    Invoke-Tweak `
        -Name "Disable Game DVR / Captures" `
        -Apply {

            Set-RegDWORD `
                "HKCU:\System\GameConfigStore" `
                "GameDVR_Enabled" `
                0

            Set-RegDWORD `
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" `
                "AppCaptureEnabled" `
                0

            Set-RegDWORD `
                "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" `
                "AllowGameDVR" `
                0
        } `
        -Verify {

            $A = Get-ItemProperty `
                "HKCU:\System\GameConfigStore" `
                -Name "GameDVR_Enabled" `
                -ErrorAction SilentlyContinue

            $B = Get-ItemProperty `
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" `
                -Name "AppCaptureEnabled" `
                -ErrorAction SilentlyContinue

            return (
                $null -ne $A -and
                $null -ne $B -and
                $A.GameDVR_Enabled -eq 0 -and
                $B.AppCaptureEnabled -eq 0
            )
        }

    $script:NeedsReboot = $true
}

function Disable-Transparency {

    Invoke-Tweak `
        -Name "Disable Transparency Effects" `
        -Apply {

            Set-RegDWORD `
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" `
                "EnableTransparency" `
                0
        } `
        -Verify {

            $Value = Get-ItemProperty `
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" `
                -Name "EnableTransparency" `
                -ErrorAction SilentlyContinue

            return (
                $null -ne $Value -and
                $Value.EnableTransparency -eq 0
            )
        }
}

function Disable-MouseAcceleration {

    Invoke-Tweak `
        -Name "Disable Mouse Acceleration" `
        -Apply {

            Set-ItemProperty `
                -Path "HKCU:\Control Panel\Mouse" `
                -Name "MouseSpeed" `
                -Value "0"

            Set-ItemProperty `
                -Path "HKCU:\Control Panel\Mouse" `
                -Name "MouseThreshold1" `
                -Value "0"

            Set-ItemProperty `
                -Path "HKCU:\Control Panel\Mouse" `
                -Name "MouseThreshold2" `
                -Value "0"
        }
}

function Disable-OptionalXboxServices {

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

        if ($null -eq $Service) {
            continue
        }

        Invoke-Tweak `
            -Name "Disable optional Xbox service: $Name" `
            -Apply {

                if ($script:PreviewMode) {

                    Write-Info `
                        "PREVIEW: $Name would be disabled."

                    return
                }

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

function Apply-AllGamingTweaks {

    Write-Section "GAMING TWEAKS"

    Enable-GameMode
    Disable-GameDVR
    Disable-Transparency
    Disable-MouseAcceleration
    Disable-OptionalXboxServices
    Set-HighPerformance
}

function Apply-InteractiveGamingTweaks {

    Clear-And-Logo

    Write-Section "GAMING TWEAKS"

    Write-Info `
        "Nothing will be changed unless you select YES."

    Write-Host ""

    $Choices = @(
        [PSCustomObject]@{
            Number = 1
            Name = "Enable Game Mode"
            Action = { Enable-GameMode }
        }

        [PSCustomObject]@{
            Number = 2
            Name = "Disable Game DVR / Captures"
            Action = { Disable-GameDVR }
        }

        [PSCustomObject]@{
            Number = 3
            Name = "Disable Transparency Effects"
            Action = { Disable-Transparency }
        }

        [PSCustomObject]@{
            Number = 4
            Name = "Disable Mouse Acceleration"
            Action = { Disable-MouseAcceleration }
        }

        [PSCustomObject]@{
            Number = 5
            Name = "Disable optional Xbox services"
            Action = { Disable-OptionalXboxServices }
        }

        [PSCustomObject]@{
            Number = 6
            Name = "Set High Performance power plan"
            Action = { Set-HighPerformance }
        }
    )

    foreach ($Choice in $Choices) {

        Write-Host ""
        Write-Host "  [$($Choice.Number)] $($Choice.Name)" `
            -ForegroundColor White

        $Answer = Read-Host "      Apply this tweak? [Y/N]"

        if (Test-Yes $Answer) {

            & $Choice.Action
        }
        else {

            Write-Info "Skipped."
        }
    }

    Pause-Menu
}

# ============================================================
# PRIVACY
# ============================================================

function Disable-AdvertisingID {

    Invoke-Tweak `
        -Name "Disable Advertising ID" `
        -Apply {

            Set-RegDWORD `
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" `
                "Enabled" `
                0
        }
}

function Disable-WindowsSuggestions {

    Invoke-Tweak `
        -Name "Disable Windows Suggestions" `
        -Apply {

            $Path =
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"

            foreach ($Name in @(
                "SystemPaneSuggestionsEnabled",
                "SoftLandingEnabled",
                "SubscribedContent-338388Enabled",
                "SubscribedContent-338389Enabled",
                "SubscribedContent-353694Enabled",
                "SubscribedContent-353696Enabled"
            )) {

                Set-RegDWORD `
                    $Path `
                    $Name `
                    0
            }
        }
}

function Apply-AllPrivacyTweaks {

    Write-Section "PRIVACY"

    Disable-AdvertisingID
    Disable-WindowsSuggestions
}

function Apply-InteractivePrivacyTweaks {

    Clear-And-Logo

    Write-Section "PRIVACY"

    Write-Info `
        "Choose exactly which privacy changes you want."

    Write-Host ""

    $Choices = @(
        [PSCustomObject]@{
            Number = 1
            Name = "Disable Advertising ID"
            Action = { Disable-AdvertisingID }
        }

        [PSCustomObject]@{
            Number = 2
            Name = "Disable Windows Suggestions"
            Action = { Disable-WindowsSuggestions }
        }
    )

    foreach ($Choice in $Choices) {

        Write-Host ""
        Write-Host "  [$($Choice.Number)] $($Choice.Name)" `
            -ForegroundColor White

        $Answer = Read-Host "      Apply this setting? [Y/N]"

        if (Test-Yes $Answer) {

            & $Choice.Action
        }
        else {

            Write-Info "Skipped."
        }
    }

    Pause-Menu
}

# ============================================================
# DEBLOAT
# ============================================================

function Get-InstalledDebloatPackages {

    $Found = New-Object System.Collections.Generic.List[object]

    foreach ($Name in $script:DebloatList) {

        $Packages = @(
            Get-AppxPackage `
                -AllUsers `
                -Name $Name `
                -ErrorAction SilentlyContinue
        )

        foreach ($Package in $Packages) {

            if ($null -ne $Package) {

                $Found.Add($Package)
            }
        }
    }

    return $Found.ToArray()
}

function Start-InteractiveDebloat {

    Clear-And-Logo

    Write-Section "SAFE DEBLOAT"

    $Packages = @(Get-InstalledDebloatPackages)

    if ($Packages.Count -eq 0) {

        Write-OK "No selected optional packages were found."
        Pause-Menu

        return
    }

    Write-Info `
        "Select the packages you want to remove."

    Write-Host ""

    $Selected = @()

    for ($i = 0; $i -lt $Packages.Count; $i++) {

        $Number = $i + 1

        Write-Host "  [$Number] " `
            -NoNewline `
            -ForegroundColor Cyan

        Write-Host $Packages[$i].Name
    }

    Write-Host ""
    Write-Host "  [A] Remove ALL listed packages"
    Write-Host "  [0] Cancel"
    Write-Host ""

    $Input = Read-Host "  Select"

    if ($Input.Trim().ToUpperInvariant() -eq "0") {

        Write-Info "Debloat cancelled."
        Pause-Menu

        return
    }

    if ($Input.Trim().ToUpperInvariant() -eq "A") {

        $Selected = @(
            1..$Packages.Count
        )
    }
    else {

        $Tokens = $Input -split "[,\s]+"

        foreach ($Token in $Tokens) {

            $Number = 0

            if (
                [int]::TryParse(
                    $Token,
                    [ref]$Number
                )
            ) {

                if (
                    $Number -ge 1 -and
                    $Number -le $Packages.Count
                ) {

                    $Selected += $Number
                }
            }
        }
    }

    if ($Selected.Count -eq 0) {

        Write-Warn "Nothing selected."
        Pause-Menu

        return
    }

    Write-Host ""
    Write-Warn "The following packages will be removed:"

    foreach ($Number in $Selected) {

        Write-Host "  • $($Packages[$Number - 1].Name)"
    }

    Write-Host ""

    if (-not $script:PreviewMode) {

        $Confirm = Read-Host "  Confirm removal? [Y/N]"

        if (-not (Test-Yes $Confirm)) {

            Write-Info "Cancelled."
            Pause-Menu

            return
        }
    }

    foreach ($Number in $Selected) {

        $Package = $Packages[$Number - 1]

        if ($Package.NonRemovable) {

            Write-Warn `
                "Protected package skipped: $($Package.Name)"

            continue
        }

        if ($script:PreviewMode) {

            Write-Info `
                "PREVIEW: Remove $($Package.Name)"

            continue
        }

        try {

            Remove-AppxPackage `
                -Package $Package.PackageFullName `
                -AllUsers `
                -ErrorAction Stop

            Write-OK `
                "Removed $($Package.Name)"

            $script:ChangesMade = $true
        }
        catch {

            Write-Fail `
                "Could not remove $($Package.Name)"

            Write-Log `
                "Debloat failed: $($Package.Name) | $($_.Exception.Message)"
        }
    }

    Pause-Menu
}

function Start-FullDebloat {

    Write-Section "SAFE DEBLOAT"

    $Packages = @(Get-InstalledDebloatPackages)

    if ($Packages.Count -eq 0) {

        Write-OK "No selected optional packages found."

        return
    }

    foreach ($Package in $Packages) {

        if ($Package.NonRemovable) {

            Write-Warn `
                "Protected: $($Package.Name)"

            continue
        }

        if ($script:PreviewMode) {

            Write-Info `
                "PREVIEW: Remove $($Package.Name)"

            continue
        }

        try {

            Remove-AppxPackage `
                -Package $Package.PackageFullName `
                -AllUsers `
                -ErrorAction Stop

            Write-OK `
                "Removed $($Package.Name)"

            $script:ChangesMade = $true
        }
        catch {

            Write-Warn `
                "Could not remove $($Package.Name)"

            Write-Log `
                "Full debloat failed: $($Package.Name) | $($_.Exception.Message)"
        }
    }
}

# ============================================================
# HEALTH CHECK
# ============================================================

function Invoke-HealthCheck {

    Write-Section "SYSTEM HEALTH"

    try {

        $Info = Get-SystemInformation

        Write-OK "Computer: $($Info.ComputerName)"
        Write-OK "Windows: $($Info.Windows)"
        Write-OK "Build: $($Info.Build)"
        Write-OK "CPU: $($Info.CPU)"
        Write-OK "GPU: $($Info.GPU)"
        Write-OK "RAM: $($Info.RAM) GB"
        Write-OK "System disk free: $($Info.FreeDisk) GB"
        Write-OK "Device: $(Get-DeviceType)"
        Write-OK "GPU vendor: $(Get-GPUVendor)"
        Write-OK "Power plan: $(Get-ActivePowerPlan)"

        if (Test-WinGet) {

            Write-OK "WinGet: Available"
        }
        else {

            Write-Warn "WinGet: Unavailable"
        }

        if ($script:NeedsReboot) {

            Write-Warn "Restart recommended."
        }
    }
    catch {

        Write-Fail `
            "Health check failed."

        Write-Log `
            "Health check failed: $($_.Exception | Out-String)"
    }
}

# ============================================================
# DASHBOARD
# ============================================================

function Show-Dashboard {

    Clear-And-Logo

    try {

        $Info = Get-SystemInformation

        Write-Section "SYSTEM"

        Write-Host "  PC        " -NoNewline -ForegroundColor DarkGray
        Write-Host $Info.ComputerName

        Write-Host "  Windows   " -NoNewline -ForegroundColor DarkGray
        Write-Host "$($Info.Windows) • Build $($Info.Build)"

        Write-Host "  CPU       " -NoNewline -ForegroundColor DarkGray
        Write-Host $Info.CPU

        Write-Host "  GPU       " -NoNewline -ForegroundColor DarkGray
        Write-Host $Info.GPU

        Write-Host "  RAM       " -NoNewline -ForegroundColor DarkGray
        Write-Host "$($Info.RAM) GB"

        Write-Host "  Disk      " -NoNewline -ForegroundColor DarkGray
        Write-Host "$($Info.FreeDisk) GB free"

        Write-Host "  Device    " -NoNewline -ForegroundColor DarkGray
        Write-Host (Get-DeviceType)

        Write-Section "STATUS"

        Write-Host "  Power     " -NoNewline -ForegroundColor DarkGray
        Write-Host (Get-ActivePowerPlan) -ForegroundColor Green

        Write-Host "  GPU       " -NoNewline -ForegroundColor DarkGray
        Write-Host (Get-GPUVendor) -ForegroundColor Cyan

        Write-Host "  WinGet    " -NoNewline -ForegroundColor DarkGray

        if (Test-WinGet) {

            Write-Host "Available" -ForegroundColor Green
        }
        else {

            Write-Host "Unavailable" -ForegroundColor Yellow
        }

        if ($script:NeedsReboot) {

            Write-Host ""
            Write-Warn "Restart recommended."
        }
    }
    catch {

        Write-Fail `
            "Dashboard error: $($_.Exception.Message)"
    }

    Pause-Menu
}

# ============================================================
# BACKUP MENU
# ============================================================

function Start-Backup {

    Clear-And-Logo

    Write-Section "BACKUP / RESTORE POINT"

    Write-Info `
        "This does not modify your Windows settings."

    Write-Host ""

    New-WindowsRestorePoint
    New-WinSetupBackup

    Pause-Menu
}

# ============================================================
# FULL PC SETUP
# ============================================================

function Start-FullSetup {

    Clear-And-Logo

    Write-Section "FULL PC SETUP"

    Write-Host ""
    Write-Host "  This mode will perform the COMPLETE WinSetup package."
    Write-Host ""

    Write-Host "  [1] Create Windows restore point"
    Write-Host "  [2] Create WinSetup backup"
    Write-Host "  [3] Apply ALL gaming tweaks"
    Write-Host "  [4] Apply ALL privacy tweaks"
    Write-Host "  [5] Perform ALL safe debloat"
    Write-Host "  [6] Process ALL applications"
    Write-Host "  [7] Run final health check"
    Write-Host ""

    Write-Warn `
        "This is the ONLY mode that automatically applies everything."

    Write-Host ""

    if ($script:PreviewMode) {

        Write-Warn `
            "PREVIEW MODE: no actual changes will be made."

        Write-Host ""

        $Confirm = "Y"
    }
    else {

        $Confirm = Read-Host `
            "  Start FULL PC SETUP? [Y/N]"
    }

    if (-not (Test-Yes $Confirm)) {

        Write-Info "Full PC Setup cancelled."

        Pause-Menu

        return
    }

    # ========================================================
    # PHASE 1
    # ========================================================

    Clear-And-Logo

    Write-Section "PHASE 1 / 7 • BACKUP"

    New-WindowsRestorePoint
    New-WinSetupBackup

    # ========================================================
    # PHASE 2
    # ========================================================

    Write-Section "PHASE 2 / 7 • GAMING TWEAKS"

    Apply-AllGamingTweaks

    # ========================================================
    # PHASE 3
    # ========================================================

    Write-Section "PHASE 3 / 7 • PRIVACY"

    Apply-AllPrivacyTweaks

    # ========================================================
    # PHASE 4
    # ========================================================

    Write-Section "PHASE 4 / 7 • DEBLOAT"

    Start-FullDebloat

    # ========================================================
    # PHASE 5
    # ========================================================

    Write-Section "PHASE 5 / 7 • APPLICATIONS"

    Write-Info `
        "Processing ALL applications."

    if (Test-WinGet) {

        Write-Info `
            "Updating WinGet source..."

        if (Update-WinGetSource) {

            Write-OK "WinGet source updated."
        }
        else {

            Write-Warn `
                "WinGet source update failed. Continuing."
        }
    }
    else {

        Write-Warn `
            "WinGet unavailable. WinGet applications will be skipped."
    }

    $Results = New-Object System.Collections.Generic.List[object]

    foreach ($Application in $script:Applications) {

        if ($Application.Source -eq "winget") {

            $Result = Install-WinGetApplication `
                -Application $Application

            if ($null -ne $Result) {

                $Results.Add($Result)
            }
        }
        else {

            Write-Host ""
            Write-Host "  $($Application.Name)" `
                -ForegroundColor Cyan

            Write-Info `
                "Opening official download page."

            Open-ApplicationWebsite `
                -Application $Application

            $Results.Add(
                [PSCustomObject]@{
                    Name   = $Application.Name
                    Status = "Manual"
                }
            )
        }
    }

    Show-ApplicationResults `
        -Results $Results

    # ========================================================
    # PHASE 6
    # ========================================================

    Write-Section "PHASE 6 / 7 • VERIFICATION"

    Invoke-HealthCheck

    # ========================================================
    # PHASE 7
    # ========================================================

    Write-Section "PHASE 7 / 7 • COMPLETE"

    if ($script:NeedsReboot) {

        Write-Warn `
            "A restart is recommended to finish applying changes."
    }

    Write-Host ""

    Write-OK `
        "FULL PC SETUP completed."

    Write-Host ""

    Write-Info `
        "Log: $script:LogFile"

    if ($script:NeedsReboot) {

        Write-Host ""

        $Restart = Read-Host `
            "  Restart the PC now? [Y/N]"

        if (
            (Test-Yes $Restart) -and
            -not $script:PreviewMode
        ) {

            Write-Info "Restarting Windows..."

            Start-Sleep -Seconds 2

            Restart-Computer -Force
        }
    }

    Pause-Menu
}

# ============================================================
# MAIN MENU
# ============================================================

function Show-MainMenu {

    while ($true) {

        Clear-And-Logo

        try {

            $Info = Get-SystemInformation

            Write-Host "  $($Info.Windows) • Build $($Info.Build)" `
                -ForegroundColor DarkGray
        }
        catch {

            Write-Host "  Windows Setup Utility" `
                -ForegroundColor DarkGray
        }

        Write-Host ""

        Write-Host "  ┌─────────────────────────────────────────────────────────┐" `
            -ForegroundColor DarkCyan

        Write-Host "  │                                                         │" `
            -ForegroundColor DarkCyan

        Write-Host "  │  [1]  " -NoNewline -ForegroundColor DarkCyan
        Write-Host "Dashboard" -NoNewline -ForegroundColor White
        Write-Host "                                       │" -ForegroundColor DarkCyan

        Write-Host "  │  [2]  " -NoNewline -ForegroundColor DarkCyan
        Write-Host "FULL PC SETUP" -NoNewline -ForegroundColor Green
        Write-Host "                                 │" -ForegroundColor DarkCyan

        Write-Host "  │  [3]  " -NoNewline -ForegroundColor DarkCyan
        Write-Host "Gaming Tweaks" -NoNewline -ForegroundColor White
        Write-Host "                                  │" -ForegroundColor DarkCyan

        Write-Host "  │  [4]  " -NoNewline -ForegroundColor DarkCyan
        Write-Host "Applications" -NoNewline -ForegroundColor White
        Write-Host "                                    │" -ForegroundColor DarkCyan

        Write-Host "  │  [5]  " -NoNewline -ForegroundColor DarkCyan
        Write-Host "Debloat" -NoNewline -ForegroundColor White
        Write-Host "                                         │" -ForegroundColor DarkCyan

        Write-Host "  │  [6]  " -NoNewline -ForegroundColor DarkCyan
        Write-Host "Privacy" -NoNewline -ForegroundColor White
        Write-Host "                                        │" -ForegroundColor DarkCyan

        Write-Host "  │  [7]  " -NoNewline -ForegroundColor DarkCyan
        Write-Host "Health Check" -NoNewline -ForegroundColor White
        Write-Host "                                   │" -ForegroundColor DarkCyan

        Write-Host "  │  [8]  " -NoNewline -ForegroundColor DarkCyan
        Write-Host "Backup / Restore Point" -NoNewline -ForegroundColor White
        Write-Host "                       │" -ForegroundColor DarkCyan

        Write-Host "  │                                                         │" `
            -ForegroundColor DarkCyan

        Write-Host "  │  [0]  " -NoNewline -ForegroundColor DarkGray
        Write-Host "Exit" -NoNewline
        Write-Host "                                              │" -ForegroundColor DarkCyan

        Write-Host "  │                                                         │" `
            -ForegroundColor DarkCyan

        Write-Host "  └─────────────────────────────────────────────────────────┘" `
            -ForegroundColor DarkCyan

        Write-Host ""

        if ($script:NeedsReboot) {

            Write-Warn "Restart recommended."
            Write-Host ""
        }

        $Choice = Read-Host "  Select"

        switch ($Choice.Trim().ToUpperInvariant()) {

            # ------------------------------------------------
            # DASHBOARD
            # ------------------------------------------------

            "1" {

                Show-Dashboard
            }

            # ------------------------------------------------
            # FULL SETUP
            # ------------------------------------------------

            "2" {

                Start-FullSetup
            }

            # ------------------------------------------------
            # GAMING
            # ------------------------------------------------

            "3" {

                Apply-InteractiveGamingTweaks
            }

            # ------------------------------------------------
            # APPLICATIONS
            # ------------------------------------------------

            "4" {

                Select-Applications
            }

            # ------------------------------------------------
            # DEBLOAT
            # ------------------------------------------------

            "5" {

                Start-InteractiveDebloat
            }

            # ------------------------------------------------
            # PRIVACY
            # ------------------------------------------------

            "6" {

                Apply-InteractivePrivacyTweaks
            }

            # ------------------------------------------------
            # HEALTH
            # ------------------------------------------------

            "7" {

                Clear-And-Logo

                Invoke-HealthCheck

                Pause-Menu
            }

            # ------------------------------------------------
            # BACKUP
            # ------------------------------------------------

            "8" {

                Start-Backup
            }

            # ------------------------------------------------
            # EXIT
            # ------------------------------------------------

            "0" {

                Clear-Host

                Write-Host ""
                Write-Host "  Thanks for using WinSetup." `
                    -ForegroundColor Cyan
                Write-Host ""

                Write-Log "WinSetup closed."

                return
            }

            default {

                Write-Warn "Invalid selection."

                Start-Sleep -Milliseconds 700
            }
        }
    }
}

# ============================================================
# COMMAND LINE MODES
# ============================================================

function Invoke-CommandMode {

    if ($Setup) {

        Start-FullSetup
        return
    }

    if ($Gaming) {

        Apply-InteractiveGamingTweaks
        return
    }

    if ($Debloat) {

        Start-InteractiveDebloat
        return
    }

    if ($Apps) {

        Select-Applications
        return
    }

    if ($Privacy) {

        Apply-InteractivePrivacyTweaks
        return
    }

    if ($Repair) {

        Clear-And-Logo
        Invoke-HealthCheck
        Pause-Menu

        return
    }

    Show-MainMenu
}

# ============================================================
# ENTRY POINT
# ============================================================

try {

    Initialize-WinSetup

    Restart-AsAdmin

    Invoke-CommandMode
}
catch {

    Clear-Host

    Write-Host ""
    Write-Host "  WINSETUP ERROR" `
        -ForegroundColor Red

    Write-Line

    Write-Host ""

    Write-Host "  $($_.Exception.Message)" `
        -ForegroundColor Red

    Write-Host ""

    Write-Log `
        "FATAL ERROR: $($_.Exception | Out-String)"

    Write-Host "  Log file:" `
        -ForegroundColor DarkGray

    Write-Host "  $script:LogFile" `
        -ForegroundColor White

    Pause-Menu
}
