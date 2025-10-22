# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Version and Status

**Current Version:** 1.0.0.RC1

**Status:** Release Candidate 1

The x0dus migration toolkit is in release candidate status. The core backup functionality is robust and includes comprehensive error handling for file copy failures. This RC includes failed files logging and improved robocopy error handling.

## Project Overview

x0dus is a Windows-to-Linux migration toolkit consisting of six companion scripts (all v1.0.0.RC1):
- `backup.ps1` (PowerShell) - Backs up Windows user profiles before OS replacement
- `linux-restore-helper.sh` (Bash) - Helps locate and mount the backup drive on Linux
- `linux-data-restore.sh` (Bash) - Restores Windows profile data to Linux home directory
- `linux-software-inventory.sh` (Bash) - Analyzes Windows software inventory and provides Linux reinstall guidance
- `linux-hardware-helper.sh` (Bash) - Analyzes Windows hardware inventory for Linux driver compatibility
- `linux-ai-prompt-generator.sh` (Bash) - Generates AI chatbot prompts based on migration context

## Testing and Development

### PowerShell Testing (backup.ps1)

Test the backup script on Windows using:

```powershell
# Interactive mode - launches wizard (DEFAULT when no DestinationPath provided)
.\backup.ps1

# Dry run to preview operations without copying
.\backup.ps1 -DestinationPath "E:\UserBackup" -DryRun

# Test with additional paths
.\backup.ps1 -DestinationPath "E:\UserBackup" -AdditionalPaths "C:\Projects" -DryRun

# Test AppData filtering modes
.\backup.ps1 -DestinationPath "E:\UserBackup" -AppDataMode RoamingOnly -DryRun  # Only settings, skip caches
.\backup.ps1 -DestinationPath "E:\UserBackup" -AppDataMode EssentialFoldersOnly -DryRun  # Only Documents/Desktop/etc
.\backup.ps1 -DestinationPath "E:\UserBackup" -AppDataMode None -DryRun  # Skip all AppData
.\backup.ps1 -DestinationPath "E:\UserBackup" -AppDataMode Full -DryRun  # Include everything (default)

# Test network share mounting (SMB)
$credential = Get-Credential
.\backup.ps1 -NetworkShare "\\nas\Migration" -NetworkCredential $credential -DestinationPath "Workstation-Backup" -DryRun

# Test with non-interactive destination creation
.\backup.ps1 -DestinationPath "E:\UserBackup" -ForceCreateDestination -DryRun

# Test with custom Robocopy tuning (reduced threads, more retries)
.\backup.ps1 -DestinationPath "E:\UserBackup" -RobocopyThreads 1 -RobocopyRetries 4 -RobocopyRetryDelaySeconds 10 -DryRun

# Force non-interactive mode (fail if DestinationPath not provided)
.\backup.ps1 -NonInteractive -DestinationPath "E:\UserBackup" -DryRun
```

To bypass execution policy during testing:
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

### Bash Testing (Linux helpers)

Test the Linux helpers using:

```bash
# Make scripts executable
chmod +x linux-restore-helper.sh linux-data-restore.sh linux-software-inventory.sh linux-hardware-helper.sh linux-ai-prompt-generator.sh

# Test version and help flags
./linux-restore-helper.sh --version
./linux-restore-helper.sh --help

# Test restore helper (interactive)
./linux-restore-helper.sh

# Test data restore with dry run
./linux-data-restore.sh --dry-run

# Test with explicit paths to skip prompts
./linux-data-restore.sh --backup-root /mnt/backup --profile /mnt/backup/Users/Alice --dry-run

# Test software inventory
./linux-software-inventory.sh /mnt/backup

# Test hardware compatibility helper
./linux-hardware-helper.sh /mnt/backup

# Test AI prompt generator
./linux-ai-prompt-generator.sh
```

## Architecture

### AppData Filtering (Recent Feature)

The backup script now supports granular AppData filtering via the `-AppDataMode` parameter:

**AppDataMode values:**
- `Full` (default) - Include all AppData (Roaming, Local, LocalLow)
- `RoamingOnly` - Include only AppData\Roaming (settings/saves), exclude Local and LocalLow (caches)
- `None` - Exclude all AppData folders
- `EssentialFoldersOnly` - Skip entire user profile, backup only specific folders (Documents, Desktop, Pictures, Videos, Music, Downloads, Favorites)

**Why AppData filtering matters:**
- AppData\Roaming: Typically 1-10 GB, contains app settings and game saves
- AppData\Local: Can be 5-50+ GB, contains browser caches, temp files, Steam shader caches, etc.
- Many users migrating to Linux don't need Windows application caches

**Interactive mode improvements:**
The interactive backup wizard now offers 4 modes with detailed explanations:
1. **Essential Files Only** - Documents/Desktop/Pictures/etc., no AppData (smallest)
2. **Essential + Settings** (RECOMMENDED) - Essential files + AppData\Roaming (settings/saves)
3. **Full User Profile** - Everything including all AppData (largest, with warnings)
4. **Custom Backup** - Full control including AppData mode selection

Each mode displays estimated size ranges (per user) and use cases to help users make informed decisions.

**All modes prompt for:**
- User profile selection (current user, all users, all users + Public, or skip profiles)
- Destination path (local or network share for Custom mode)
- Dry run option (preview-only mode without copying files)

**Custom mode additionally prompts for:**
- Network share configuration (SMB/NFS)
- Additional folders to backup
- AppData handling mode (override the default Full mode)
- Advanced Robocopy tuning options

### New PowerShell Parameters (Recent Changes)

The backup script recently added several new parameters:

**Interactive mode** (NEW):
- `-NonInteractive` - Disables interactive mode when DestinationPath is not provided
- **Default behavior**: When `DestinationPath` is not provided and `NonInteractive` is not set, the script launches an interactive wizard
- **Interactive wizard features** (all modes):
  - Mode selection: Essential Files Only, Essential + Settings (recommended), Full Profile, or Custom Backup
  - AppData handling: Automatic based on mode (EssentialFoldersOnly, RoamingOnly, or Full)
  - User profile selection: Current user, all users, all users + Public folder, or skip profiles
  - Destination selection: Local path (all modes), network share (Custom mode only)
  - Configuration confirmation with summary (including AppData mode)
  - Dry Run option: Preview backup without copying files
- **Custom mode additional features**:
  - Network share configuration: SMB/NFS with credentials
  - Additional folders: Text entry for multiple paths beyond user profiles
  - AppData handling override: Manual selection to override default Full mode
  - Robocopy tuning: Thread count, retries, retry delay

**Interactive mode functions**:
- `Get-InteractiveConfiguration` - Main interactive wizard orchestrator
  - Shows configuration summary with AppData mode
  - Prompts for confirmation
  - Prompts for Dry Run mode (preview only, no file copying)
- `Show-Menu` - Generic menu display and selection
- `Get-DestinationPathInteractive` - Destination path selection
- `Get-NetworkShareInteractive` - Network share configuration
- `Get-UserProfileSelectionInteractive` - User profile selection menu
- `Get-AdditionalPathsInteractive` - Multiple folder entry loop
- `Get-AppDataModeInteractive` - AppData handling selection (Custom mode only)
- `Get-RobocopyOptionsInteractive` - Advanced Robocopy tuning

**Progress visualization** (NEW):
- `Show-RobocopyProgress` - Displays visual progress bar and item information during backup
- Shows current item number, total items, overall progress percentage
- Displays source and destination paths for each backup item
- `Invoke-RobocopyBackup` updated to accept `CurrentItem` and `TotalItems` parameters

**Destination management**:
- `-ForceCreateDestination` - Automatically create destination directory without prompting (useful for automation/scripting)
- `Confirm-DestinationInteractive` function - Prompts user to create missing destination unless `-ForceCreateDestination` is specified

**Robocopy tuning**:
- `-RobocopyThreads` (1-128, default 8) - Controls `/MT:n` flag for multi-threaded copying
- `-RobocopyRetries` (0-10, default 2) - Number of retry attempts after initial Robocopy run
- `-RobocopyRetryDelaySeconds` (1-600, default 5) - Base delay for exponential backoff between retries

**Script logging**:
- `Get-ScriptLogFilePath` / `Start-ScriptLogging` / `Stop-ScriptLogging` - Full PowerShell transcript logging to `logs/script-*.log`
- Separate from Robocopy log (`logs/backup-*.log`)
- Both logs saved in destination's `logs/` directory

### Backup Pre-flight Checks

Before starting the backup, the script performs comprehensive validation:

**Size Estimation Phase:**
1. Visual header: "BACKUP SIZE ESTIMATION"
2. Calculates total size of all backup items
3. Shows "Size estimation completed!" when done
4. Displays warnings for any files/folders that couldn't be scanned

**Space Availability Check:**
1. Visual header: "SPACE AVAILABILITY CHECK"
2. Displays three key metrics:
   - Estimated backup size
   - Available space at destination
   - Space utilization percentage (color-coded)
3. Color-coded utilization warnings:
   - Green (<50%): Good
   - Yellow (50-80%): Moderate
   - Yellow (80-90%): Caution - Limited space
   - Red (90-100%): WARNING - Very tight!
   - Red (>100%): INSUFFICIENT SPACE!

**Space Validation:**
- If backup size > available space:
  - Shows "INSUFFICIENT SPACE" error banner
  - Displays shortfall amount
  - Lists options (free space, different destination, reduce scope)
  - Throws error and stops
- If space utilization > 80%:
  - Shows warning about tight space
  - Explains Robocopy may need temporary space
  - **Prompts user for go/no-go decision**
  - User can proceed (Y) or cancel (N)

**Ready to Begin:**
- Visual header: "READY TO BEGIN BACKUP"
- Summary of backup items, total size, mode (dry run if applicable)
- **Universal confirmation prompt:** "Press Enter to start the backup (or Ctrl+C to cancel)"
  - Gives user final opportunity to review size estimates
  - Required for ALL backups, regardless of space utilization
  - Allows user to cancel (Ctrl+C) or screenshot the summary
- Backup only starts after user presses Enter

### Robocopy Error Handling and Failed Files Logging

`Invoke-RobocopyBackup` implements sophisticated error handling with failed file tracking:

**Exit Code Handling:**
- **0-3**: Success (no errors or minor skipped files)
- **4-7**: Warnings - Some files failed but backup CONTINUES
  - Logs warning message
  - Parses and logs failed files to dedicated log
  - Returns normally (does NOT throw error)
- **8+**: Critical errors
  - Logs failed files
  - Shows warning but CONTINUES with next backup item (does NOT quit script)
  - Displays troubleshooting guidance

**Key change from previous behavior:** The script no longer quits on robocopy errors. Instead, it:
1. Logs which files failed for each source path
2. Continues backing up remaining items
3. Shows comprehensive summary at the end with failed files report

**Failed Files Logging:**

New functions added for tracking failed file copies:

1. **`Get-FailedFilesLogPath`** - Creates timestamped log path at `logs/failed-files-<timestamp>.log`
2. **`Parse-FailedFiles`** - Parses robocopy logs to extract failed file paths
   - Searches for ERROR patterns in robocopy log
   - Extracts file paths from error messages
   - Groups failures by source path
   - Writes formatted sections to failed files log

**Failed Files Log Format:**
```
================================================
Failed Files Log - Backup Session 2025-01-15 14:23:45
================================================

------------------------------------------------
Source: C:\Users\YourName\AppData
Timestamp: 2025-01-15 14:25:12
Failed file count: 3
------------------------------------------------
C:\Users\YourName\AppData\Local\Google\Chrome\User Data\lockfile
C:\Users\YourName\AppData\Local\Microsoft\Outlook\outlook.pst
C:\Users\YourName\AppData\Roaming\App\config.db

------------------------------------------------
Source: C:\Users\YourName\Documents
Timestamp: 2025-01-15 14:30:45
Failed file count: 1
------------------------------------------------
C:\Users\YourName\Documents\locked-file.docx
```

**Backup Completion Summary:**

After all backup items complete, the script shows a comprehensive summary:
- Checks if failed files log exists and has content
- If failures occurred:
  - Shows clear WARNING message
  - Displays failed files log location
  - Lists common reasons (files in use, permissions, locked files, network errors)
  - Suggests remediation steps (close apps, run as Administrator, manually copy critical files)
- If no failures: Shows success message

**Retry Logic:**
1. Initial Robocopy attempt
2. If exit code > 3 (failure), wait `2^(attempt-1) * RetryDelaySeconds` and retry
3. Continue until `RobocopyRetries + 1` total attempts exhausted
4. Parse failed files from log after each attempt
5. On final failure, parse last 200 lines of log for ERROR/failed patterns and display troubleshooting guidance

**Use Case:**
This addresses the common issue where robocopy errors in AppData (locked database files, browser caches in use, etc.) would cause the entire script to quit before backing up other important data. Now the script gracefully handles individual file failures and provides a detailed report at the end.

### Shared State Management (Linux helpers)

All Linux helpers share state through `~/x0dus/` workspace directory:

**Shared metadata files:**
- `mount-point.txt` - Remembered backup mount location
- `windows-profile-path.txt` - Selected Windows profile path
- `installed-software-inventory-path.txt` - Path to Windows software CSV
- `installed-software-names-path.txt` - Path to extracted software names
- `hardware-inventory-path.txt` - Path to Windows hardware CSV (NEW)
- `system-info.txt` - Detected distro and system information (appended by each helper)
- `git-info.txt` - Git availability and repository status
- Log files for each helper (`linux-*.log`)

**Output files:**
- `hardware-compatibility-report.txt` - Hardware analysis results (linux-hardware-helper.sh)
- `ai-prompts/` directory - Generated AI prompts (linux-ai-prompt-generator.sh)
  - `index.md` - Prompt index and usage guide
  - `01-hardware-compatibility.txt` - Hardware/driver prompt
  - `02-software-alternatives.txt` - Software migration prompt
  - `03-gaming-setup.txt` - Gaming configuration prompt (conditional)
  - `04-development-environment.txt` - Dev tools setup prompt (conditional)
  - `05-troubleshooting-template.txt` - Generic troubleshooting template
  - `06-general-migration-guidance.txt` - Beginner-friendly guidance

**Critical pattern**: Helpers use `remember_path()` and `load_remembered_path()` functions to persist and retrieve values between runs. This enables sequential execution without re-prompting.

### Distribution Detection

All Linux helpers include `detect_distro()` which:
1. Parses `/etc/os-release` or falls back to `lsb_release`
2. Sets `DETECTED_DISTRO_NAME`, `DETECTED_DISTRO_VERSION`, `DETECTED_DISTRO_ID`
3. Used by `git_install_hint()` and `print_package_manager_guidance()` to provide distro-specific commands

Supported families: Debian/Ubuntu, Fedora/RHEL, Arch, openSUSE, Gentoo, Alpine, Void

### PowerShell Backup Architecture

`backup.ps1` uses a modular function-based design:

**Pre-flight checks**:
- `Test-IsSupportedWindows` - Validates Windows 10/11
- `Connect-NetworkDestination` - Handles SMB/NFS network share mounting
- `Resolve-BackupItems` - Builds list of paths to backup
- `Get-BackupSizeEstimate` - Calculates total size with access error tracking
- `Get-DestinationFreeSpace` - Validates sufficient space
- `Test-IsDestinationWithinSource` - Prevents recursive backup loops

**Backup execution**:
- `Invoke-RobocopyBackup` - Wraps Robocopy with proper flags and error handling
- `Get-FailedFilesLogPath` - Creates timestamped path for failed files log
- `Parse-FailedFiles` - Parses robocopy logs to extract failed file paths
- `Export-InstalledSoftwareInventory` - Queries registry for installed software → `installed-software.csv`
- `Export-HardwareInventory` - Collects hardware information via WMI/CIM → `hardware-inventory.csv`

**Key Robocopy flags**: `/E /COPY:DAT /DCOPY:DAT /MT:8 /XJ /V /TEE`
- `/E` - Copy subdirectories including empty
- `/COPY:DAT` - Copy data, attributes, and timestamps for files
- `/DCOPY:DAT` - Preserve directory timestamps and attributes
- `/MT:n` - Multi-threaded copying (configurable via `-RobocopyThreads`, default 8)
- `/XJ` - Exclude junction points (prevents loops)
- `/V` - Verbose output
- `/TEE` - Output to console and log file
- `/L` - List only mode (added when `-DryRun` specified)

### Bash Script Architecture

All bash scripts follow consistent patterns (v1.0.0.RC1):

**Version Management:**
```bash
SCRIPT_VERSION="1.0.0.RC1"
```
- Every script has version variable
- `--version` flag: `printf 'script-name.sh version %s\n' "$SCRIPT_VERSION"`
- Displayed in banner

**Banner Function:**
```bash
show_banner() {
  local subtitle="$1"
  # Displays hexagonal ASCII logo with version and branding
  # Color: cyan (ANSI \033[36m) - approximates Hexaxia #77bfab
  # Includes: version, subtitle, Hexaxia branding, GitHub link, disclaimer
}
```

**Help System:**
- `show_help()` function in every script
- `-h, --help` flag support
- Usage documentation with examples

**Error Handling:**
All bash helpers use:
```bash
set -euo pipefail
```
- `-e` Exit on error
- `-u` Error on undefined variables
- `-o pipefail` Pipe failures propagate

### Desktop Handling Pattern (linux-data-restore.sh)

The data restore script has special logic to keep the new Linux desktop clean:
1. Copies entire Windows profile EXCEPT Desktop folder
2. Processes Desktop separately: filters out `.lnk` shortcuts, copies real files to `~/oldDesktop`
3. During `--dry-run`, Desktop preview written to `~/x0dus/old-desktop-items.txt` without creating `~/oldDesktop`

### Software Inventory Processing

`linux-software-inventory.sh` processes the Windows `installed-software.csv`:
1. Locates CSV in backup (searches `logs/` subdirectories if needed)
2. Extracts unique application names using Python CSV parser (falls back to manual review if Python unavailable)
3. Creates timestamped snapshot: `installed-software-names-<timestamp>.txt`
4. Symlinks to `installed-software-names-latest.txt` for quick access
5. Calls `print_package_manager_guidance()` which provides distro-specific package manager commands

### Hardware Compatibility Helper (NEW in v1.0.0.RC1)

`linux-hardware-helper.sh` analyzes Windows hardware inventory for Linux driver compatibility:

**Purpose:**
- Detect hardware that may need special drivers or configuration on Linux
- Provide distro-specific installation commands
- Check if drivers are already loaded on the current system
- Generate detailed compatibility report

**Analysis Categories:**
1. **GPU Analysis** (`analyze_gpu`)
   - Detects NVIDIA, AMD, and Intel graphics cards
   - NVIDIA: Yellow warning, checks for nvidia driver (lsmod), provides proprietary driver commands
   - AMD: Yellow warning, checks for amdgpu driver, Mesa driver commands
   - Intel: Green OK, built-in driver support
   - Distro-specific commands for each GPU vendor

2. **Network Analysis** (`analyze_network`)
   - Detects Broadcom Wi-Fi (yellow warning, often needs firmware)
   - Intel Wi-Fi (green OK, iwlwifi driver usually included)
   - Realtek adapters (yellow warning, may need r8168 instead of r8169)
   - Provides installation commands for each adapter type

3. **Audio Analysis** (`analyze_audio`)
   - Detects audio devices
   - Usually green OK (ALSA/PulseAudio/PipeWire work out-of-box)

4. **USB Analysis** (`analyze_usb`)
   - Counts USB controllers
   - Always green OK (excellent Linux support)

**Driver Detection Functions:**
- `check_driver_loaded` - Uses lsmod to check if kernel module is loaded
- `check_package_installed` - Checks with dpkg/rpm/pacman if driver package is installed
- `get_driver_install_command` - Returns distro-specific installation commands

**Color-coded Output:**
- Uses ANSI color codes for clear visual feedback
- RED: Known compatibility issues requiring attention
- YELLOW: May require additional drivers or configuration
- GREEN: Good Linux support, works out-of-the-box
- CYAN: Informational headers

**Report Generation:**
- Saves detailed report to `~/x0dus/hardware-compatibility-report.txt`
- Includes device names, status, and installation commands
- Summary with legend explaining color codes

**Use Case:**
Run immediately after installing Linux to identify hardware that needs drivers before issues occur (e.g., no WiFi, no graphics acceleration).

### AI Prompt Generator (NEW in v1.0.0.RC1)

`linux-ai-prompt-generator.sh` generates contextual AI chatbot prompts for migration assistance:

**Purpose:**
- Bridge the knowledge gap between Windows and Linux
- Provide copy-paste-ready prompts for AI chatbots (ChatGPT, Claude, Gemini, etc.)
- Context-aware: includes user's specific distro, hardware, and software
- Future-proof: works with any AI chatbot, not tied to specific tools

**Generated Prompt Types:**

1. **Hardware Compatibility Prompt** (`01-hardware-compatibility.txt`)
   - Includes full hardware-inventory.csv data
   - Asks for driver installation commands specific to user's distro
   - Questions about proprietary vs open-source drivers
   - Always generated if hardware inventory exists

2. **Software Alternatives Prompt** (`02-software-alternatives.txt`)
   - Includes list of Windows applications from software inventory
   - Asks for Linux alternatives (native, Flatpak, Snap, Wine)
   - Prioritizes open-source and native packages
   - Always generated if software inventory exists

3. **Gaming Setup Prompt** (`03-gaming-setup.txt`) - *Conditional*
   - Generated only if gaming software detected (Steam, Epic, GOG, etc.)
   - Covers Steam, Proton, Lutris, Wine configuration
   - GPU-specific gaming optimizations
   - Anti-cheat compatibility questions

4. **Development Environment Prompt** (`04-development-environment.txt`) - *Conditional*
   - Generated only if dev tools detected (VS Code, IDEs, Docker, etc.)
   - Asks about IDE alternatives and setup
   - Docker without Docker Desktop
   - Language version managers (nvm, pyenv, etc.)

5. **Troubleshooting Template** (`05-troubleshooting-template.txt`)
   - Customizable template for specific problems
   - Pre-filled with user's distro and hardware info
   - Always generated

6. **General Migration Guidance** (`06-general-migration-guidance.txt`)
   - Beginner-friendly comprehensive guide
   - File system navigation, software management, system configuration
   - Always generated

**Prompt Structure:**
```
# Prompt Title
# Metadata (generated date, distro, version)

========================================
COPY THE TEXT BELOW TO YOUR AI CHATBOT:
========================================

[Pre-filled prompt with user's context]

**My System:**
- Distribution: [detected distro]
- Package Manager: [detected PM]
- Hardware: [relevant hardware]

**[Category-specific data]**

**Questions:**
1. Question 1...
2. Question 2...
...

========================================
```

**Index File** (`index.md`):
- Markdown index explaining each prompt
- When to use each prompt
- Tips for best results with AI chatbots
- Links to supported AI platforms

**Smart Detection:**
- Uses grep to detect gaming software (case-insensitive pattern matching)
- Detects dev tools (IDEs, Docker, language runtimes)
- Only generates relevant prompts (avoids prompt fatigue)

**Dependencies:**
- Requires hardware/software inventories to be present
- Falls back gracefully if files missing
- Provides instructions to run prerequisite helpers

**Use Case:**
Run after all other helpers to get comprehensive AI assistance. Users can then copy prompts into their preferred AI chatbot for personalized migration guidance that accounts for vast hardware/software ecosystem diversity.

### Hardware Inventory Export

`backup.ps1` exports comprehensive hardware information to `hardware-inventory.csv`:

**Hardware categories captured:**
- **System** - Manufacturer, model, total RAM
- **CPU** - Processor model, cores, threads
- **GPU** - Graphics card model, manufacturer, driver version, VRAM (critical for NVIDIA/AMD proprietary drivers)
- **Network** - Ethernet and WiFi adapters with MAC addresses (essential for driver compatibility)
- **Audio** - Sound devices (for ALSA/PulseAudio configuration)
- **Motherboard** - Manufacturer, model, serial number
- **BIOS** - Version and release date
- **RAM** - Memory modules with capacity, speed, and slot location
- **Storage** - Disk drives with size and interface type
- **USB** - USB controller information

**Use cases for Linux migration:**
- **WiFi drivers** - Identify WiFi chipset to find Linux driver packages
- **GPU drivers** - Determine if NVIDIA/AMD proprietary drivers are needed
- **Network adapters** - Ensure Ethernet drivers are available
- **Hardware compatibility** - Pre-migration compatibility checking with Linux hardware databases
- **Troubleshooting** - Complete hardware manifest for post-migration driver issues

**Export timing:**
- Runs after successful backup completion
- Skipped during dry run mode (same as software inventory)
- Uses Get-CimInstance (modern) for hardware queries
- Graceful error handling if WMI/CIM queries fail

## Key Implementation Patterns

### AppData filtering implementation

The AppData filtering feature uses a two-pronged approach:

1. **EssentialFoldersOnly mode** - Handled at backup item resolution level:
   - `Resolve-BackupItems` calls `Get-EssentialFoldersBackupPaths` instead of `Get-UserProfileBackupPath`
   - Creates separate backup items for each essential folder (Documents, Desktop, Pictures, etc.)
   - AppData is never included in the backup item list

2. **RoamingOnly/None modes** - Handled at Robocopy execution level:
   - `Invoke-RobocopyBackup` adds `/XD` (exclude directory) flags to Robocopy arguments
   - `RoamingOnly`: Excludes `AppData\Local` and `AppData\LocalLow`
   - `None`: Excludes entire `AppData` folder
   - User profile is still backed up as a single item, but specified subdirectories are excluded

3. **Full mode** - No special handling, backs up everything

**Key functions:**
- `Get-EssentialFoldersBackupPaths` - Returns array of essential folder items (Desktop, Documents, Pictures, Videos, Music, Downloads, Favorites)
- `Resolve-BackupItems` - Accepts `AppDataMode` parameter, chooses between essential folders or full profile
- `Invoke-RobocopyBackup` - Accepts `AppDataMode` parameter, adds Robocopy exclusion flags

### When adding new backup sources (PowerShell)

1. Update `Resolve-BackupItems` to add new items to `$backupItems` array
2. Each item is hashtable: `@{ Source = "path"; Destination = "folder-name" }`
3. Drive roots get special naming via `Get-BackupItemName`
4. Size estimation happens in `Get-BackupSizeEstimate` - ensure new sources are included

### When adding new Linux helper workspace files

Use the established `remember_path()` pattern:
```bash
remember_path "$value" "$WORKSPACE_DIR/new-file.txt" "Display Label"
```

Load with:
```bash
load_remembered_path "$WORKSPACE_DIR/new-file.txt" "Display Label"
```

### When extending distribution support

1. Add new distro ID patterns to `detect_distro()` (already handles fallbacks)
2. Add case in `git_install_hint()` for Git installation command
3. Add case in `print_package_manager_guidance()` (linux-software-inventory.sh) for package manager commands

### Network share handling

Both PowerShell and Bash helpers support SMB and NFS:
- **PowerShell**: `Connect-NetworkDestination` uses `New-SmbMapping` or `net use` for SMB, `mount` for NFS
- **Bash**: `linux-restore-helper.sh` has `mount_network_share()` using `mount.cifs` or `mount.nfs`
- Protocol auto-detection based on path format (`\\server\share` = SMB, `server:/export` = NFS)

## Code Style

### PowerShell
- Verb-Noun function naming (e.g., `Get-BackupSizeEstimate`, `Test-IsDestinationWithinSource`)
- `[CmdletBinding()]` on main script, verbose support via `Write-Verbose`
- Parameter validation with `[ValidateNotNullOrEmpty()]`
- Use `Write-Host` for user messages, `Write-Warning` for warnings

### Bash
- snake_case function naming
- Use `printf` over `echo` for formatted output
- `print_header()` creates consistent section headers
- Redirect all output to log via `exec > >(tee -a "$LOG_FILE") 2>&1`
- Privilege escalation via `run_with_privilege()` which tries `sudo` then `doas`

## Common Pitfalls

### PowerShell
- Network credentials only work for SMB, not NFS
- Drive letter mapping for network shares defaults to `Z:`, can conflict if already in use
- Robocopy exit codes: 0-3 are success (script treats these as success), >3 trigger retries
- `$PROFILE.CurrentUserAllHosts` vs `$env:USERPROFILE` - script backs up user profile directory, not PowerShell profile
- Destination prompting behavior: By default the script prompts interactively before creating missing destinations; use `-ForceCreateDestination` to bypass prompts for automation
- Script transcript logging: The script now logs both Robocopy output (`backup-*.log`) AND full PowerShell transcript (`script-*.log`) to the destination's `logs/` directory
- Robocopy retry logic passes `-Threads`, `-Retries`, and `-RetryDelaySeconds` parameters to `Invoke-RobocopyBackup`, not to Robocopy itself; the function handles retry orchestration

### Bash
- `~/x0dus` workspace directory must exist before helpers can persist state
- Helpers can run in any order, but data restore needs mount point established first
- Desktop restore skips `.lnk` files but preserves all other file types
- Python 3 is required for CSV parsing in software inventory helper; gracefully degrades if missing

## Potential Future Enhancements

The following features have been considered for future versions but are not currently implemented. These represent potential v2.0+ enhancements based on user feedback and use cases:

### Backup Features

**1. Resume Capability (High Priority)**
- Allow resuming failed backups from the point of failure instead of restarting
- Robocopy supports this natively with `/MIR` or `/DCOPY:T` flags
- Would save significant time on large backups that fail near completion
- Estimated implementation effort: Medium
- User benefit: High (especially for slow/unreliable connections)

**2. Incremental/Differential Backup Support**
- Support for incremental backups (only changed files since last backup)
- Differential backups (all changes since full backup)
- Would reduce backup time and storage requirements for repeated backups
- Requires backup metadata/tracking system
- Estimated implementation effort: High
- User benefit: Medium-High (useful for ongoing backups, less critical for one-time migrations)

**3. Backup Verification**
- Hash-based verification of copied files (MD5/SHA256)
- Ensures data integrity after transfer
- Option to verify during or after backup
- Performance impact: Significant (hashing is CPU/IO intensive)
- Estimated implementation effort: Medium
- User benefit: Medium (peace of mind, but Robocopy is already reliable)

**4. Compression Support**
- Optional compression using 7z/zip
- Could significantly reduce backup size and transfer time
- Trade-off: CPU usage vs storage/network savings
- Estimated implementation effort: Medium-High
- User benefit: Medium (helpful for network transfers, less for local drives)

### Script Organization

**5. Modularization**
- Split large backup.ps1 (~2000 lines) into multiple files
- Use dot-sourcing to import helper modules
- Modules: Interactive functions, hardware inventory, network operations, etc.
- Estimated implementation effort: Medium
- User benefit: Low (developer quality-of-life, easier maintenance)

**6. Configuration File Support**
- Support for .conf or .json configuration files
- Pre-define backup sets for repeated operations
- Useful for IT administrators managing multiple migrations
- Estimated implementation effort: Low-Medium
- User benefit: Low-Medium (nice-to-have for advanced users)

### Advanced Features

**7. Scheduled Backups**
- Windows Task Scheduler integration
- Automated recurring backups
- Less relevant for one-time migration use case
- Estimated implementation effort: Low
- User benefit: Low (outside primary use case)

**8. Email/Notifications**
- Email or SMS notifications on backup completion/failure
- Useful for unattended backups
- Requires SMTP configuration or notification service
- Estimated implementation effort: Medium
- User benefit: Low-Medium (nice-to-have for automated scenarios)

**9. Encryption Support**
- Encrypt backup data at rest
- Useful for sensitive data or cloud storage destinations
- Could use 7z with password or VeraCrypt integration
- Estimated implementation effort: High
- User benefit: Medium (security-conscious users)

**10. Bandwidth Throttling**
- Limit network bandwidth for remote backups
- Prevent saturating network connection
- Robocopy supports `/IPG` flag for inter-packet gap
- Estimated implementation effort: Low
- User benefit: Low-Medium (useful for network backups)

**11. Custom Exclude Patterns**
- User-defined file/folder exclusion patterns
- Regex or glob-based filtering
- More granular control than current AppData modes
- Estimated implementation effort: Medium
- User benefit: Medium (power users)

### UX Improvements

**12. Dry Run Visibility Enhancements**
- Show example Robocopy command that would execute
- More detailed preview of what will be copied
- Estimated implementation effort: Low
- User benefit: Low-Medium (helpful for advanced users)

**13. Progress Estimation**
- Real-time progress percentage based on file count/size
- ETA for backup completion
- Requires Robocopy output parsing
- Estimated implementation effort: Medium
- User benefit: Medium (nice-to-have UX improvement)

## Development Priorities

If implementing future enhancements, recommended priority order:
1. **Resume capability** - Highest user value for large backups
2. **Backup verification** - Important for data integrity confidence
3. **Incremental backups** - Useful if tool evolves beyond one-time migrations
4. **Compression** - Depends on user feedback about backup sizes
5. **Encryption** - Security-focused enhancement
6. Lower priority: Modularization, scheduling, notifications, etc.

## Version History

- **v1.0.0.RC1** (2025-10-22) - Maintenance Release (Post-v1.0.0 Hotfix)
  - Added comprehensive robocopy error handling
  - Failed files logging feature
  - Script continues on file copy errors instead of quitting
  - Backup completion summary with failed files report
  - Exit codes 4-7 handled as warnings (backup continues)
  - Exit codes 8+ continue with next item instead of terminating
  - Note: Critical bug fixes for issues discovered shortly after v1.0.0 release

- **v1.0.0** (2025-10-20) - Initial production release

  **PowerShell (backup.ps1):**
  - Interactive wizard with 4 backup modes
  - Granular AppData filtering (Full, RoamingOnly, None, EssentialFoldersOnly)
  - Hardware inventory export for Linux driver compatibility
  - Software inventory export
  - Pre-flight space checks with go/no-go prompts
  - Comprehensive error handling and retry logic
  - Network share support (SMB/NFS)
  - Professional branding with hexagonal logo and disclaimer

  **Bash Scripts (all):**
  - Consistent branding with hexagonal ASCII logo (cyan color)
  - Version management (SCRIPT_VERSION variable)
  - --version and --help flag support
  - Professional banners with Hexaxia branding and disclaimer

  **linux-restore-helper.sh:**
  - Locate and mount backup drives (local or network)
  - SMB and NFS support
  - Git availability detection

  **linux-data-restore.sh:**
  - Restore Windows profile to Linux home directory
  - Desktop file handling (excludes shortcuts)
  - Space availability checking

  **linux-software-inventory.sh:**
  - Parse Windows software inventory CSV
  - Extract unique application names
  - Distro-specific package manager guidance

  **linux-hardware-helper.sh (NEW):**
  - Analyze hardware inventory for Linux compatibility
  - Detect problematic hardware (NVIDIA/AMD GPUs, Broadcom WiFi, Realtek network)
  - Distro-specific driver installation commands
  - Color-coded warnings (Red/Yellow/Green)
  - Check if drivers already loaded
  - Generate detailed compatibility report

  **linux-ai-prompt-generator.sh (NEW):**
  - Generate AI chatbot prompts based on migration context
  - 6 prompt types: hardware, software, gaming, dev environment, troubleshooting, general
  - Conditional prompt generation (gaming/dev only if detected)
  - Works with ChatGPT, Claude, Gemini, and other AI chatbots
  - Context-aware: includes distro, hardware, software data
  - Comprehensive index with usage guidance
