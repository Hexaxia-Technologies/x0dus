# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

x0dus is a Windows-to-Linux migration toolkit consisting of four companion scripts:
- `backup.ps1` (PowerShell) - Backs up Windows user profiles before OS replacement
- `linux-restore-helper.sh` (Bash) - Helps locate and mount the backup drive on Linux
- `linux-data-restore.sh` (Bash) - Restores Windows profile data to Linux home directory
- `linux-software-inventory.sh` (Bash) - Analyzes Windows software inventory and provides Linux reinstall guidance

## Testing and Development

### PowerShell Testing (backup.ps1)

Test the backup script on Windows using:

```powershell
# Dry run to preview operations without copying
.\backup.ps1 -DestinationPath "E:\UserBackup" -DryRun

# Test with additional paths
.\backup.ps1 -DestinationPath "E:\UserBackup" -AdditionalPaths "C:\Projects" -DryRun

# Test network share mounting (SMB)
$credential = Get-Credential
.\backup.ps1 -NetworkShare "\\nas\Migration" -NetworkCredential $credential -DestinationPath "Workstation-Backup" -DryRun

# Test with non-interactive destination creation
.\backup.ps1 -DestinationPath "E:\UserBackup" -ForceCreateDestination -DryRun

# Test with custom Robocopy tuning (reduced threads, more retries)
.\backup.ps1 -DestinationPath "E:\UserBackup" -RobocopyThreads 1 -RobocopyRetries 4 -RobocopyRetryDelaySeconds 10 -DryRun
```

To bypass execution policy during testing:
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

### Bash Testing (Linux helpers)

Test the Linux helpers using:

```bash
# Make scripts executable
chmod +x linux-restore-helper.sh linux-data-restore.sh linux-software-inventory.sh

# Test restore helper (interactive)
./linux-restore-helper.sh

# Test data restore with dry run
./linux-data-restore.sh --dry-run

# Test with explicit paths to skip prompts
./linux-data-restore.sh --backup-root /mnt/backup --profile /mnt/backup/Users/Alice --dry-run

# Test software inventory
./linux-software-inventory.sh /mnt/backup
```

## Architecture

### New PowerShell Parameters (Recent Changes)

The backup script recently added several new parameters:

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

### Robocopy Retry Logic

`Invoke-RobocopyBackup` now implements exponential backoff retry logic:
1. Initial Robocopy attempt
2. If exit code > 3 (failure), wait `2^(attempt-1) * RetryDelaySeconds` and retry
3. Continue until `RobocopyRetries + 1` total attempts exhausted
4. On final failure, parse last 200 lines of log for ERROR/failed patterns and display troubleshooting guidance

### Shared State Management (Linux helpers)

All three Linux helpers share state through `~/x0dus/` workspace directory:
- `mount-point.txt` - Remembered backup mount location
- `windows-profile-path.txt` - Selected Windows profile path
- `installed-software-inventory-path.txt` - Path to Windows software CSV
- `installed-software-names-path.txt` - Path to extracted software names
- `system-info.txt` - Detected distro and system information (appended by each helper)
- `git-info.txt` - Git availability and repository status
- Log files for each helper (`linux-*.log`)

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
- `Invoke-RobocopyBackup` - Wraps Robocopy with proper flags
- `Export-InstalledSoftwareInventory` - Queries registry for installed software → `installed-software.csv`

**Key Robocopy flags**: `/E /COPY:DAT /DCOPY:DAT /MT:8 /XJ /V /TEE`
- `/E` - Copy subdirectories including empty
- `/COPY:DAT` - Copy data, attributes, and timestamps for files
- `/DCOPY:DAT` - Preserve directory timestamps and attributes
- `/MT:n` - Multi-threaded copying (configurable via `-RobocopyThreads`, default 8)
- `/XJ` - Exclude junction points (prevents loops)
- `/V` - Verbose output
- `/TEE` - Output to console and log file
- `/L` - List only mode (added when `-DryRun` specified)

### Bash Script Error Handling

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

## Key Implementation Patterns

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
