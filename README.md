WinSetup

WinSetup is a Windows setup, debloat and optimization utility built in PowerShell.

The goal is simple:

Install the software you want, remove unnecessary Windows components, apply useful system tweaks, and get a new Windows installation ready to use.

WinSetup is designed to be easy to use while keeping potentially important system changes visible to the user.

Features
🖥️ Windows Setup

System information detection

Windows build detection

CPU / GPU / RAM detection

Laptop / desktop detection

Power plan management

Automatic administrator elevation

Logging

Backup support

Windows Restore Point support

Reboot detection

🎮 Gaming

Optional gaming-focused tweaks including:

Game Mode

Game DVR / Captures

Optional Xbox services

High Performance power plan

Windows transparency

Mouse acceleration

WinSetup does not intentionally disable Windows Defender, Windows Update or essential Windows services.

🧹 Safe Debloat

WinSetup can remove a curated list of optional Microsoft Store applications.

The debloat list is intentionally conservative.

Protected/non-removable packages are skipped.

🔒 Privacy

Optional privacy-related settings include:

Advertising ID

Windows suggestions

Selected content recommendations

📦 Applications

Applications are not automatically installed.

When opening the Applications menu, you can choose exactly what you want:

APPLICATIONS

[1] Brave
[2] Google Chrome
[3] Steam
[4] Epic Games Launcher
[5] Ubisoft Connect
[6] Logitech G HUB
[7] NVIDIA App
[8] WinRAR
[9] Visual C++ Redistributable x64
[10] Visual C++ Redistributable x86
[11] DirectX
[12] Microsoft Edge WebView2

[A] Install ALL applications
[0] Back


This means you can either install individual applications or install the complete software package with one selection.

Included Applications
Application	Category
Brave	Browser
Google Chrome	Browser
Steam	Gaming
Epic Games Launcher	Gaming
Ubisoft Connect	Gaming
Logitech G HUB	Gaming
NVIDIA App	Gaming
WinRAR	Utility
Visual C++ Redistributable x64	Runtime
Visual C++ Redistributable x86	Runtime
DirectX	Runtime
Microsoft Edge WebView2	Runtime

Applications are installed through WinGet where supported.

Availability can depend on Windows version, architecture and current WinGet package availability.

Main Menu
┌─────────────────────────────────────────────────────┐
│                                                     │
│   [1]  Dashboard                                    │
│   [2]  Setup My PC                                  │
│   [3]  Gaming Profile                               │
│   [4]  Applications                                 │
│   [5]  Safe Debloat                                 │
│   [6]  Privacy                                      │
│   [7]  Health Check                                 │
│   [8]  Backup                                       │
│                                                     │
│   [0]  Exit                                         │
│                                                     │
└─────────────────────────────────────────────────────┘

Application Installer

The application installer is intentionally interactive.

Selecting Applications does not automatically install everything.

You can install a single application:

[1] Brave


or install the entire collection:

[A] Install ALL applications


This makes WinSetup useful both for a completely fresh Windows installation and for users who only want a few programs.

Preview Mode

WinSetup includes a preview mode:

.\WinSetup.ps1 -Preview


Preview mode allows you to inspect operations without applying changes.

This is useful before running larger operations such as debloating or applying system tweaks.

Command Line Modes
Normal interface
.\WinSetup.ps1

Complete setup
.\WinSetup.ps1 -Setup

Gaming profile
.\WinSetup.ps1 -Gaming

Applications
.\WinSetup.ps1 -Apps

Debloat
.\WinSetup.ps1 -Debloat

Privacy
.\WinSetup.ps1 -Privacy

Health check
.\WinSetup.ps1 -Repair

Preview
.\WinSetup.ps1 -Preview

Quick Start

Run PowerShell as Administrator and execute:

irm https://raw.githubusercontent.com/gains331/WinSetup/main/WinSetup.ps1 | iex


WinSetup will start its interface and request administrator privileges when required.

⚠️ Important

The irm | iex method downloads the current script directly from GitHub and executes it.

Always review the source code before running a remote PowerShell script.

For maximum transparency, clone the repository and run the script locally:

git clone https://github.com/gains331/WinSetup.git
cd WinSetup
.\WinSetup.ps1

Safety

WinSetup makes changes to Windows configuration.

Before using system modification features, WinSetup attempts to create:

A Windows System Restore Point

A WinSetup configuration backup

A service-state backup

A power-plan backup

Registry backups for selected settings

Backups are stored under:

C:\ProgramData\WinSetup\


No backup system can guarantee recovery from every possible Windows configuration problem. Use WinSetup at your own discretion.

Design Philosophy

WinSetup follows a few principles:

1. Don't break Windows

Core Windows functionality should remain intact.

2. Don't install software without asking

Applications are selected by the user.

3. Verify changes

Where possible, tweaks should be verified after being applied.

4. Keep logs

Operations and errors are logged for troubleshooting.

5. Make changes reversible where practical

Backups and restore points are created before major operations.

6. Keep the project maintainable

WinSetup is intended to grow into a modular Windows setup framework rather than becoming an unmaintainable collection of random tweaks.

Project Structure
WinSetup/
│
├── WinSetup.ps1
├── README.md
├── LICENSE
└── .gitignore

Requirements

Windows 10 or newer

PowerShell 5.1+

Administrator privileges for system modifications

WinGet for application installation

Some functionality may vary depending on Windows edition, version and installed components.

Disclaimer

WinSetup is provided as-is.

System configuration changes can cause unexpected behavior depending on the individual Windows installation, hardware configuration, installed software and Windows version.

Create a backup before making significant system changes.

The authors and contributors are not responsible for data loss, system instability, software conflicts or other damage resulting from the use of this project.

License

WinSetup is released under the MIT License.

See LICENSE for the full license text.

Author

gains331

Project:

gains331/WinSetup

WinSetup is an independent community project and is not affiliated with Microsoft, Valve, Epic Games, Ubisoft, Logitech, NVIDIA, Brave, Google or RARLAB.