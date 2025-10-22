# x0dus

**Version:** 1.0.0.RC1

Windows and Linux helper scripts to migrate to Linux.

## Overview

The repository provides comprehensive Windows-to-Linux migration tools:

### Windows Backup Script (PowerShell)
- **`backup.ps1`** - Copies user profiles from Windows 10/11 machines to a safe
  location before replacing the operating system. Features include granular
  AppData filtering (to reduce backup size), hardware inventory collection (for
  Linux driver compatibility), and installed software inventory to help with
  post-migration setup.

### Linux Migration Helpers (Bash)
- **`linux-restore-helper.sh`** - Runs on Linux after migration, summarizes
  distro details, and guides you through locating and mounting the backup drive.
- **`linux-data-restore.sh`** - Copies a selected Windows profile into the
  current Linux home directory, checks available space, and collects Windows
  desktop files (excluding shortcuts) under `~/oldDesktop`.
- **`linux-software-inventory.sh`** - Inspects the mounted backup, summarizes
  the Windows software inventory, and provides reinstall guidance tailored to
  your Linux distribution.
- **`linux-hardware-helper.sh`** - Analyzes Windows hardware inventory and
  provides Linux driver compatibility guidance, detecting potential issues with
  GPUs, Wi-Fi adapters, and other hardware.
- **`linux-ai-prompt-generator.sh`** - Generates ready-to-use AI chatbot prompts
  based on your migration context, helping you get personalized assistance from
  ChatGPT, Claude, Gemini, or other AI assistants.

All Linux helpers record their activity under `~/x0dus`, a workspace folder
in the current user's home directory that keeps logs, detected system details,
hardware/software reports, and handy path references so you can resume the
migration at any point.

## Requirements

- Windows 10 or Windows 11
- PowerShell 5.1 or newer (the default version that ships with Windows 10/11)
- Sufficient free space on the destination drive to hold the backup
- Python 3 on the Linux system (used by the software inventory helper to parse
  the Windows report; if it is missing you can review the CSV manually)

Git is optional but recommended on Linux so you can keep the helpers up to
date, especially as new features are added.

## Getting the helpers with Git

### 1. Check whether Git is available

Run the following command. If Git is installed it prints the version; otherwise
the shell reports that the command was not found.

```bash
git --version
```

### 2. Install Git when needed

Use your distribution's package manager to add Git if the previous command
failed. Replace `sudo` with your preferred privilege escalation method when
necessary.

- Debian, Ubuntu, Linux Mint, Pop!_OS, and derivatives:

  ```bash
  sudo apt update
  sudo apt install -y git
  ```

- Fedora, RHEL, CentOS Stream, Rocky Linux, AlmaLinux, and Oracle Linux:

  ```bash
  sudo dnf install -y git
  ```

- Arch Linux, Manjaro, EndeavourOS, and Garuda Linux:

  ```bash
  sudo pacman -S git
  ```

- openSUSE Leap/Tumbleweed and SUSE Linux Enterprise:

  ```bash
  sudo zypper install -y git
  ```

- Gentoo Linux:

  ```bash
  sudo emerge --ask dev-vcs/git
  ```

- Alpine Linux:

  ```bash
  sudo apk add git
  ```

- Void Linux:

  ```bash
  sudo xbps-install -Sy git
  ```

For other distributions, consult the vendor documentation for the appropriate
command.

### 3. Clone or update the repository in your home directory

After Git is installed, download the helpers to `~/x0dus`:

```bash
cd ~
git clone https://github.com/Hexaxia-Technologies/x0dus.git
cd ~/x0dus
```

When you already have a clone, pull in the latest updates before running the
scripts:

```bash
cd ~/x0dus
git pull
```

## Usage

### Windows backup script

The backup script can run in two modes:

#### Interactive Mode (Default)

Run the script without any parameters to launch the interactive wizard:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\backup.ps1
```

The wizard will guide you through:
1. **Mode Selection**: Choose between Quick Backup or Custom Backup
   - **Quick Backup**: Minimal configuration - backs up current user profile to a local path
   - **Custom Backup**: Full control over all options including network shares, multiple user profiles, additional folders, and Robocopy tuning
2. **Destination Selection**: Choose local path or network share (SMB/NFS)
3. **User Profile Selection**: Current user, all users, or all users + Public folder
4. **Additional Folders**: Add extra directories to backup (one at a time)
5. **Advanced Options**: Configure Robocopy threading, retries, and delays (Custom mode only)
6. **Confirmation**: Review your configuration before starting

#### Command-Line Mode

You can also run the script with command-line parameters for automation or scripting:

1. Decide where the backup should be stored (for example an external drive,
   secondary internal disk, or network share) and create the destination
   folder if needed.
2. Open **PowerShell** as the user whose data should be backed up. If you run
   into access denied errors, re-run PowerShell as an administrator.
3. Download `backup.ps1` from this repository to a convenient folder on the
   Windows machine.
4. Execute the script, providing the destination folder. The script will
   estimate the total size of the selected items and verify the destination has
   enough free space before any copy begins. Example:

   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   .\backup.ps1 -DestinationPath "E:\UserBackup"
   ```

### Optional parameters

- `-NonInteractive` – disable interactive mode even when no destination is provided.
  Useful for automation scenarios where you want the script to fail rather than prompt.
- `-AdditionalPaths <string[]>` – include extra folders in the backup (for
  example project directories stored outside the user profile). Drive roots are
  supported and saved with a friendly name.
- `-IncludeAllUsers` – copy every profile under `C:\Users` (excluding system
  templates). The current user remains included unless
  `-SkipDefaultDirectories` is also specified.
- `-IncludePublicProfile` – include the shared `C:\Users\Public` folder.
  This can be combined with `-IncludeAllUsers`.
- `-SkipDefaultDirectories` – skip copying the user profile. This switch is
  primarily provided for backward compatibility with earlier versions of the
  script.
- `-DryRun` – list the actions Robocopy would take without copying files.
- `-NoLog` – disable writing a log file to the destination directory.
- `-LogPath <string>` – set a custom location for the Robocopy log file.
- `-NetworkShare <string>` – mount an SMB (`\\server\share`) or NFS (`server:/export`)
  location before the backup runs. When specified, you can provide a relative
  `-DestinationPath` that will be created inside the mapped share.
- `-NetworkProtocol <SMB|NFS>` – override protocol detection for `-NetworkShare`.
  If omitted the script infers the protocol from the share format.
- `-NetworkDriveLetter <char>` – drive letter used when mounting the share
  (defaults to `Z`).
- `-NetworkCredential <PSCredential>` – credential to authenticate with SMB
  shares. Not used for NFS.
- `-NetworkPersistent` – leave the mapped drive connected after the script
  finishes. By default the helper removes temporary mappings.
- `-NetworkMountOptions <string>` – additional options passed to the underlying
  mount command (useful for supplying NFS mount options or SMB dialect flags).
- `-ForceCreateDestination` – when present the script will create the destination
  directory without prompting. By default the script asks interactively before
  creating a missing destination to avoid accidental disk changes when run
  manually.
- `-AppDataMode <Full|RoamingOnly|None|EssentialFoldersOnly>` – controls how
  AppData folders are handled during backup (default: `Full`):
  - `Full` – includes all AppData (Roaming, Local, LocalLow)
  - `RoamingOnly` – includes only AppData\Roaming (settings/saves), excludes
    Local and LocalLow (caches). Can save 10-50+ GB.
  - `None` – excludes all AppData folders from the backup
  - `EssentialFoldersOnly` – skips the entire user profile, backs up only essential
    folders (Documents, Desktop, Pictures, Videos, Music, Downloads, Favorites)

### Robocopy tuning and retries

The backup script exposes a few options to tune Robocopy's behavior and add
automated retries for transient failures:

- `-RobocopyThreads <int>` – number of threads passed to Robocopy's `/MT` flag
  (default 8). Valid values: 1-128. Use `1` if you want single-threaded copying.
- `-RobocopyRetries <int>` – number of additional retry attempts after the
  initial Robocopy run (default 2). Valid values: 0-10. Combined with the
  initial attempt this yields up to `1 + RobocopyRetries` attempts.
- `-RobocopyRetryDelaySeconds <int>` – base retry delay in seconds (default 5).
  Exponential backoff is applied between retries.

Example: reduce thread count and increase retries for a flaky network share

```powershell
.\backup.ps1 -DestinationPath "E:\UserBackup" -RobocopyThreads 1 -RobocopyRetries 4 -RobocopyRetryDelaySeconds 10
```

If some locations cannot be scanned because of permissions, the script warns
you so you can re-run PowerShell as an administrator or ensure extra free space
before retrying.

### Example: include extra folders

```powershell
.\backup.ps1 -DestinationPath "E:\UserBackup" -AdditionalPaths "C:\", "D:\VMs"
```

### Example: copy all profiles and the Public folder

```powershell
.\backup.ps1 -DestinationPath "E:\UserBackup" -IncludeAllUsers -IncludePublicProfile
```

### Example: back up to a network share with credentials

```powershell
$credential = Get-Credential
.\backup.ps1 -NetworkShare "\\nas\Migration" -NetworkCredential $credential -DestinationPath "Workstation-Backup"
```

### Example: test the backup without copying files

```powershell
.\backup.ps1 -DestinationPath "E:\UserBackup" -DryRun
```

### Example: non-interactive creation of the destination

```powershell
.\backup.ps1 -DestinationPath "E:\UserBackup" -ForceCreateDestination -DryRun
```

### Progress Visualization

The script now includes visual progress indicators during backup operations:
- Shows current item number and total items being backed up
- Displays overall progress percentage with a progress bar
- Shows source and destination paths for each item
- Provides clear visual feedback throughout the backup process

## What gets backed up?

By default the script copies the entire user profile directory (for example
`C:\Users\Alice`) so hidden folders such as `AppData` are preserved alongside
Desktop, Documents, and other visible locations. You can expand the scope to
include every profile under `C:\Users` by adding `-IncludeAllUsers`, and the
shared `C:\Users\Public` folder with `-IncludePublicProfile`. Additional
directories can be added with `-AdditionalPaths`.

The data is copied with Robocopy using options that preserve file attributes
and timestamps while skipping junction loops. A timestamped Robocopy log file is
stored in `logs\` inside the destination folder (unless logging is disabled).

### Error Handling and Failed Files Logging

The backup script includes comprehensive error handling that gracefully manages individual file failures:

**Robocopy Exit Code Handling:**
- **Exit codes 0-3**: Success - All files copied or no changes needed
- **Exit codes 4-7**: Warnings - Some files failed, but backup **continues** with remaining items
- **Exit codes 8+**: Critical errors - Script logs the issue and **continues** with next backup item

**Key behavior:** The script no longer quits when robocopy encounters errors. Instead, it:
1. Logs failed files to `logs/failed-files-<timestamp>.log` for each source
2. Continues backing up remaining items
3. Shows a comprehensive summary at the end

**Failed Files Log:**

When files cannot be copied (typically due to being locked by running applications, permission issues, or system file restrictions), the script creates a detailed failed files log with:
- Session timestamp
- Source path for each group of failures
- Individual file paths that failed to copy
- Count of failed files per source

Example log format:
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
```

**Backup Completion Summary:**

At the end of the backup, the script displays a summary showing:
- Whether any files failed to copy
- Location of the failed files log (if failures occurred)
- Common reasons for failures (files in use, permissions, locked files, network errors)
- Suggested remediation steps (close applications, run as Administrator, manually copy critical files)

This approach ensures that common issues like locked database files or browser caches in use don't prevent the backup of your important documents, pictures, and other data.

### Inventory Files

When the backup completes, the script exports two inventory files:
- `installed-software.csv` – containing the Display Name, Version, Publisher,
  Install Date, and Install Location reported by Windows for each detected program.
- `hardware-inventory.csv` – comprehensive hardware information including CPU, GPU,
  network adapters, motherboard, BIOS, RAM, storage, and USB controllers. This is
  especially useful for identifying WiFi chipsets, graphics cards, and other hardware
  that may require specific Linux drivers.

### Linux restore helper

Run `linux-restore-helper.sh` on the Linux system after the migration to locate
and mount the backup drive.

1. Download `linux-restore-helper.sh` to the Linux machine (for example via a
   USB drive or network share) and make it executable:

   ```bash
   chmod +x linux-restore-helper.sh
   ```

2. Execute the script:

   ```bash
   ./linux-restore-helper.sh
   ```

   The helper reports the detected distribution, kernel, and current user, then
   lists available block devices (using `lsblk`), filesystem signatures, and
   current mounts.

3. Choose whether the backup is stored on a local device or a network share.
   For local drives the helper checks if the device is already mounted and lets
   you reuse the existing mount point. For network shares it supports both SMB
   and NFS exports, guiding you through protocol selection, mount options, and
   reuse of any active mounts.

4. Once the location is mounted (or an existing mount point is reused), the
   helper displays the contents of the backup so you can copy files to their new
   locations.
5. The helper prints suggested next steps, including reminders to run
   `linux-data-restore.sh` to copy your files and `linux-software-inventory.sh`
   to review the software list when you are ready.
6. If the helper mounted the location it prints the corresponding `umount`
   command; otherwise it reminds you that the mount was already active.

   ```bash
   sudo umount /mnt/backup
   ```

The Windows backup retains the original folder structure, making it easy to
copy files to the new environment once the drive is mounted.

### Linux data restore helper

Run `linux-data-restore.sh` after the backup location is mounted to copy your
Windows profile into the current Linux user's home directory without cluttering
the fresh desktop.

1. Download `linux-data-restore.sh` to the Linux machine and make it
   executable:

   ```bash
   chmod +x linux-data-restore.sh
   ```

2. Execute the script. It automatically reuses mount points and profile paths
   remembered by the other helpers, or prompts you to select the appropriate
   locations:

   ```bash
   ./linux-data-restore.sh
   ```

3. Review the size summary the helper prints. It measures your current Linux
   home usage, the Windows profile size, and checks the free space on the
   destination partition, warning you if the backup appears larger than the
   available space.
4. Confirm the restore. The helper copies the Windows profile into your Linux
   home directory while excluding the Desktop folder.
5. Any Windows desktop items that are not `.lnk` shortcut files are copied into
   `~/oldDesktop` so you can access them without crowding the new Linux desktop.
   During `--dry-run` previews the helper lists the files without creating
   `~/oldDesktop`, and the preview is saved to `~/x0dus/old-desktop-items.txt`.
6. A summary of the restore is appended to `~/x0dus/restore-summary.txt`, and a
   full log is captured in `~/x0dus/linux-data-restore.log`. Rerun the script
   with `--dry-run` to preview the copy operations, or supply `--backup-root`
   and `--profile` to skip the interactive prompts when you already know the
   exact paths.

#### Linux helper workspace

The first time you run one of the Linux helpers, the scripts create
`~/x0dus` and begin storing shared metadata there:

- `linux-software-inventory.log` and `linux-data-restore.log` capture the
  console output of their respective helpers so you can review exactly what ran
  during each session (additional helpers can append their own logs here in the
  future).
- `system-info.txt` tracks detected Linux distribution information (appended to
  by each helper run).
- `git-info.txt` records whether Git is installed, where the helpers were
  sourced from, and recommended update or installation commands.
- `mount-point.txt`, `windows-profile-path.txt`,
  `installed-software-inventory-path.txt`, and `installed-software-names-path.txt`
  remember the backup mount location, the chosen Windows profile, the Windows
  CSV path, and the simplified software list so you can run helpers in any order
  without re-entering information.
- `restore-summary.txt` appends a short record for every restore run, and
  `old-desktop-items.txt` lists the non-shortcut files that were copied (or
  would be copied during a dry run) into `~/oldDesktop` for quick reference.
- Timestamped `installed-software-names-*.txt` files provide snapshots of the
  extracted application names, and `installed-software-names-latest.txt`
  mirrors the most recent export for quick access.

### Linux software inventory helper

After the backup drive is mounted and you have copied your data (or at least
verified the files you need), run `linux-software-inventory.sh` to review the
saved Windows application list.

1. Download `linux-software-inventory.sh` to the Linux machine and make it
   executable:

   ```bash
   chmod +x linux-software-inventory.sh
   ```

2. Execute the script, optionally providing the mount point of the backup. If
   no argument is supplied the helper prompts for a path (defaulting to
   `/mnt/backup`):

   ```bash
   ./linux-software-inventory.sh /mnt/backup
   ```

3. The helper locates the `installed-software.csv` report, extracts unique
   application names into `~/x0dus/installed-software-names-<timestamp>.txt`
   (and updates `~/x0dus/installed-software-names-latest.txt`), and prints
   package manager guidance tailored to the detected distribution. When Python
   3 is unavailable it reminds you to open the CSV manually.

### Linux hardware compatibility helper

Run `linux-hardware-helper.sh` to analyze your Windows hardware inventory and
get Linux-specific driver guidance.

1. Download `linux-hardware-helper.sh` to the Linux machine and make it
   executable:

   ```bash
   chmod +x linux-hardware-helper.sh
   ```

2. Execute the script with the backup mount point:

   ```bash
   ./linux-hardware-helper.sh /mnt/backup
   ```

3. The helper analyzes your hardware inventory and provides:
   - Detection of problematic hardware (NVIDIA/AMD GPUs, Broadcom Wi-Fi, etc.)
   - Distro-specific driver installation commands
   - Color-coded warnings (Red/Yellow/Green) for hardware compatibility
   - Checks if drivers are already installed on your system
   - Detailed compatibility report saved to `~/x0dus/hardware-compatibility-report.txt`

### AI migration assistant helper

Run `linux-ai-prompt-generator.sh` to generate personalized AI chatbot prompts
based on your migration context.

1. Download `linux-ai-prompt-generator.sh` to the Linux machine and make it
   executable:

   ```bash
   chmod +x linux-ai-prompt-generator.sh
   ```

2. Execute the script (it will use remembered paths from previous helpers):

   ```bash
   ./linux-ai-prompt-generator.sh
   ```

3. The helper generates ready-to-use prompts for:
   - **Hardware compatibility** - Driver installation and compatibility issues
   - **Software alternatives** - Finding Linux equivalents for Windows apps
   - **Gaming setup** - Configuring Steam, Proton, Lutris, and Wine (if games detected)
   - **Development environment** - Recreating your dev tools setup (if dev tools detected)
   - **Troubleshooting template** - Customizable template for specific problems
   - **General migration guidance** - Comprehensive beginner-friendly guidance

4. All prompts are saved to `~/x0dus/ai-prompts/` with an index file explaining
   each prompt. Simply copy the prompt text and paste it into ChatGPT, Claude,
   Gemini, or any other AI chatbot for personalized assistance.

## Troubleshooting

### Windows Backup Issues

#### "Access Denied" errors when scanning folders

**Symptoms:** PowerShell reports access denied when scanning certain folders during size estimation.

**Solutions:**
- Run PowerShell as Administrator (right-click PowerShell, select "Run as administrator")
- The script will warn you about inaccessible folders and continue with the backup
- Ensure extra free space at the destination since some folders couldn't be measured

#### Insufficient space error

**Symptoms:** The script reports "INSUFFICIENT SPACE" during pre-flight checks.

**Cause:** The estimated backup size exceeds available space at the destination.

**Solutions:**
- Free up space at the destination drive
- Choose a different destination with more free space
- Reduce backup scope using `-AppDataMode RoamingOnly` or `-AppDataMode EssentialFoldersOnly`
- Skip non-essential folders with `-AppDataMode None` if you only need user files

#### Space utilization warnings (80%+)

**Symptoms:** Yellow or red warnings about space utilization percentage.

**Explanation:** Even if the backup fits mathematically, Robocopy may need temporary space during copying.

**Action:** The script will prompt you to confirm whether to proceed. Review the space summary and decide whether to continue or free up more space.

#### Network share won't mount

**Symptoms:** Error when trying to connect to `-NetworkShare` parameter.

**Solutions for SMB shares:**
- Verify credentials are correct: `$credential = Get-Credential` (enter username and password)
- Test connection manually: `Test-Path "\\server\share"`
- Ensure SMB is enabled on the target server
- Check Windows Firewall isn't blocking SMB traffic

**Solutions for NFS shares:**
- Verify NFS client is installed: `Get-WindowsFeature NFS-Client` (Server) or check "Services for NFS" (Windows 10/11 Pro)
- Check server exports: From Linux server run `showmount -e server-ip`
- Verify network connectivity: `ping server-ip`
- Ensure correct NFS path format: `server:/export/path`

#### Robocopy fails or shows errors

**Symptoms:** Robocopy exits with errors, backup doesn't complete.

**Understanding Robocopy exit codes:**
- **0** - No files copied, no errors (destination already up to date)
- **1** - Files copied successfully
- **2** - Extra files or directories detected (normal)
- **3** - Files copied with some skipped (normal)
- **4-7** - Some files failed (script continues and logs failures)
- **8 or higher** - Critical errors occurred (script will retry automatically)

**Solutions:**
- Check the Robocopy log file at `destination\logs\backup-TIMESTAMP.log` for specific errors
- Check the failed files log at `destination\logs\failed-files-TIMESTAMP.log` to see which files couldn't be copied
- If retries fail, increase retry attempts: `-RobocopyRetries 5`
- For flaky network connections, reduce threads: `-RobocopyThreads 1`
- For permission errors, run PowerShell as Administrator

#### Some files failed to copy (exit codes 4-7)

**Symptoms:** Backup completes but shows warning about failed files.

**Explanation:** This is normal behavior when some files are locked, in use, or inaccessible. The script logs these failures and continues backing up other files.

**Common causes:**
- **Files in use**: Browser databases, Outlook PST files, application lock files
- **Permission issues**: System files or files owned by other users
- **Locked files**: Database files currently being written to
- **Network issues**: Temporary connectivity problems (for network destinations)

**Solutions:**
1. **Review the failed files log**: Check `destination\logs\failed-files-TIMESTAMP.log` to see what failed
2. **Close applications**: Close browsers, Outlook, and other applications that may be locking files
3. **Run as Administrator**: Rerun PowerShell as Administrator for better file access
4. **Manually copy critical files**: If specific important files failed, close the application using them and manually copy
5. **Most files are not critical**: Many failed files are temporary files, caches, or lock files that don't need to be backed up

**When to be concerned:**
- If important documents or pictures failed to copy
- If large numbers of files failed (hundreds or thousands)
- If the failed files log shows errors for entire directories

**When NOT to worry:**
- Browser cache files, lock files, or temporary files
- AppData files from applications you won't use on Linux
- Small numbers of failures (a few dozen files in AppData is normal)

#### Backup runs very slowly

**Symptoms:** Backup takes hours or appears stuck.

**Solutions:**
- For network backups: Reduce thread count `-RobocopyThreads 1` (multi-threading can saturate network)
- For local backups: Increase threads `-RobocopyThreads 16` (faster on modern systems)
- Check destination drive speed (USB 2.0 is slow, USB 3.0+ or internal drives are faster)
- Use `RoamingOnly` or `EssentialFoldersOnly` AppData mode to reduce backup size

#### Hardware/software inventory files not created

**Symptoms:** Missing `hardware-inventory.csv` or `installed-software.csv` in backup destination.

**Cause:** Inventories are only created after successful backup completion, skipped during `-DryRun`.

**Solutions:**
- Ensure backup completed successfully (exit code 0-3)
- Check `logs\` subdirectory in backup destination
- Re-run backup without `-DryRun` flag
- Run PowerShell as Administrator if WMI/registry access is denied

### Linux Restore Issues

#### Python 3 not found (software inventory helper)

**Symptoms:** `linux-software-inventory.sh` reports Python 3 is not installed.

**Solutions:**
- **Debian/Ubuntu:** `sudo apt update && sudo apt install -y python3`
- **Fedora/RHEL:** `sudo dnf install -y python3`
- **Arch Linux:** `sudo pacman -S python`
- **openSUSE:** `sudo zypper install -y python3`
- **Alternative:** Open the CSV file manually with LibreOffice Calc or a text editor

#### Mount point already in use

**Symptoms:** Error when trying to mount backup drive to `/mnt/backup`.

**Cause:** A filesystem is already mounted at that location.

**Solutions:**
- Check existing mounts: `findmnt /mnt/backup` or `mount | grep backup`
- Reuse the existing mount when the helper prompts you
- Choose a different mount point
- Unmount first: `sudo umount /mnt/backup` (ensure no files are in use)

#### Permission denied when accessing backup files

**Symptoms:** Cannot read files from mounted backup drive.

**Solutions:**
- Mount the drive with sudo: The Linux helpers will prompt for sudo when needed
- Check mount permissions: `ls -la /mnt/backup`
- For network shares, verify credentials and permissions on the source
- For NTFS drives, see comprehensive NTFS troubleshooting below

#### NTFS Drive Issues (Windows Backup Drives)

Since Windows uses NTFS for its filesystems, backup drives are typically NTFS-formatted. Linux can read and write NTFS, but requires proper tools and configuration.

##### Installing NTFS Support

**Install required packages:**

```bash
# Debian/Ubuntu/Linux Mint
sudo apt update
sudo apt install ntfs-3g ntfsprogs

# Fedora/RHEL/CentOS
sudo dnf install ntfs-3g ntfsprogs

# Arch Linux
sudo pacman -S ntfs-3g

# openSUSE
sudo zypper install ntfs-3g ntfsprogs
```

**What these packages provide:**
- `ntfs-3g`: Full read/write NTFS support via FUSE
- `ntfsprogs`: NTFS utilities including `ntfsfix`, `ntfsinfo`, `ntfsclone`

##### Read-Only Mount Issues

**Symptoms:** NTFS drive mounts as read-only, cannot write files.

**Common Causes:**

1. **Windows Fast Startup / Hibernation (Most Common)**
   - Windows didn't fully shut down, left filesystem in "dirty" state
   - Metadata kept in Windows cache, preventing Linux writes

2. **Filesystem Errors**
   - Drive has errors that need repair
   - Improper disconnection or power loss

3. **NTFS Journal Issues**
   - NTFS transaction log has pending operations

**Solutions:**

**Option 1: Fix in Windows (Recommended if dual-booting)**
1. Boot into Windows
2. Disable Fast Startup:
   - Control Panel → Power Options → Choose what power buttons do
   - Click "Change settings that are currently unavailable"
   - Uncheck "Turn on fast startup (recommended)"
   - Save changes
3. Shut down Windows properly (not Restart, use Shut Down)
4. Boot into Linux and remount

**Option 2: Use ntfsfix on Linux**

```bash
# First, unmount the drive if mounted
sudo umount /dev/sdX1

# Run ntfsfix to repair filesystem errors
sudo ntfsfix /dev/sdX1

# Example: For a drive at /dev/sdc2
sudo ntfsfix /dev/sdc2

# Remount the drive
sudo mount /dev/sdX1 /mnt/backup
```

**What ntfsfix does:**
- Clears the "dirty" flag that prevents mounting read-write
- Fixes common NTFS inconsistencies
- Resets the NTFS journal
- Does NOT run a full filesystem check (use Windows chkdsk for that)

**Option 3: Force read-write mount (Use with caution)**

```bash
# Mount with remove_hiberfile option
sudo mount -t ntfs-3g -o remove_hiberfile /dev/sdX1 /mnt/backup
```

**Warning:** Only use `remove_hiberfile` if you're certain Windows is not hibernated. Data loss can occur if Windows resumes from hibernation after this.

##### Filesystem Errors and Corruption

**Symptoms:**
- `ntfsfix` reports errors
- Mount fails with "corrupt filesystem" message
- Files or directories inaccessible

**Diagnostic Commands:**

```bash
# Check NTFS filesystem status
sudo ntfsinfo -m /dev/sdX1

# Identify the device (find your drive)
lsblk
# or
sudo fdisk -l
```

**Solutions:**

**For Minor Issues:**
```bash
# Unmount first
sudo umount /dev/sdX1

# Run ntfsfix
sudo ntfsfix /dev/sdX1

# If ntfsfix succeeds, remount
sudo mount -t ntfs-3g /dev/sdX1 /mnt/backup
```

**For Serious Corruption:**
```bash
# Boot into Windows and run chkdsk
# From Windows Command Prompt (Admin):
chkdsk E: /F /R

# /F fixes errors
# /R locates bad sectors and recovers readable data
```

**Emergency Read-Only Access:**
```bash
# If repairs fail but you need to recover data
sudo mount -t ntfs-3g -o ro /dev/sdX1 /mnt/backup
```

##### "Metadata kept in Windows cache" Error

**Full Error:**
```
The disk contains an unclean file system (0, 0).
Metadata kept in Windows cache, refused to mount.
Failed to mount '/dev/sdX1': Operation not permitted
The NTFS partition is in an unsafe state.
```

**Cause:** Windows used Fast Startup or hibernated without fully flushing filesystem metadata.

**Solution:**

```bash
# Clear the dirty bit and Windows cache flag
sudo ntfsfix -d /dev/sdX1

# Then mount normally
sudo mount /dev/sdX1 /mnt/backup
```

##### Proper NTFS Mount Options

**Recommended mount command:**

```bash
# Mount with full permissions for your user
sudo mount -t ntfs-3g -o uid=$(id -u),gid=$(id -g),umask=0022 /dev/sdX1 /mnt/backup
```

**Mount Options Explained:**
- `uid=$(id -u)`: Set owner to current user
- `gid=$(id -g)`: Set group to current user's group
- `umask=0022`: Files readable by all, writable by owner (755 for dirs, 644 for files)

**Alternative for full access:**
```bash
# Mount with full read/write for everyone (less secure)
sudo mount -t ntfs-3g -o permissions /dev/sdX1 /mnt/backup
```

##### Automatic Mounting (fstab)

**To mount NTFS drive automatically at boot:**

1. Find the UUID of your drive:
```bash
sudo blkid /dev/sdX1
```

2. Edit `/etc/fstab`:
```bash
sudo nano /etc/fstab
```

3. Add entry (replace UUID and mount point):
```
UUID=YOUR-UUID-HERE  /mnt/backup  ntfs-3g  uid=1000,gid=1000,umask=0022,nofail  0  0
```

**fstab options explained:**
- `nofail`: System boots even if drive not connected
- `uid=1000,gid=1000`: Replace with your user ID from `id -u` and `id -g`
- `0 0`: Don't fsck NTFS on boot

##### Dual-Boot Considerations

**If you're dual-booting Windows and Linux:**

1. **Always disable Fast Startup in Windows**
   - Prevents "dirty" filesystem issues
   - Allows safe read/write from Linux

2. **Shut down Windows properly**
   - Use Shut Down, not Restart
   - Restart often uses Fast Startup even when disabled

3. **Never mount Windows system drive from Linux while Windows is hibernated**
   - Data corruption risk
   - Use `ntfsfix -n` (no changes mode) to check status first

4. **For shared data drives:**
   - Mount with proper permissions
   - Use consistent uid/gid settings
   - Consider exFAT instead of NTFS for better cross-platform support

##### Quick Reference

**Common Commands:**
```bash
# Install NTFS tools
sudo apt install ntfs-3g ntfsprogs

# Fix read-only issues
sudo ntfsfix /dev/sdX1

# Fix Windows cache issues
sudo ntfsfix -d /dev/sdX1

# Mount with user permissions
sudo mount -t ntfs-3g -o uid=$(id -u),gid=$(id -g) /dev/sdX1 /mnt/backup

# Check for errors (read-only check)
sudo ntfsfix -n /dev/sdX1

# Identify drives
lsblk
sudo blkid
```

**When to use Windows chkdsk instead:**
- Serious filesystem corruption
- Bad sectors detected
- NTFS journal corruption
- ntfsfix fails repeatedly
- Data recovery needed

#### Workspace directory errors

**Symptoms:** Helpers report they cannot create or write to `~/x0dus/`.

**Cause:** Permission issues or disk full.

**Solutions:**
- Check home directory permissions: `ls -ld ~`
- Verify disk space: `df -h ~`
- Manually create directory: `mkdir -p ~/x0dus`
- Check if directory is owned by you: `ls -la ~/x0dus`

#### Helpers don't remember previous values

**Symptoms:** Each helper asks for mount point or profile path again.

**Cause:** Workspace files in `~/x0dus/` are missing or empty.

**Solutions:**
- Check workspace exists: `ls ~/x0dus/`
- Verify workspace files: `cat ~/x0dus/mount-point.txt`
- Re-run helpers in order to rebuild workspace state
- Ensure helpers have write permissions: `ls -la ~/x0dus/`

#### Desktop files not restored correctly

**Symptoms:** Old Windows desktop files not appearing in `~/oldDesktop`.

**Cause:** The helper filters out `.lnk` shortcut files (which don't work on Linux).

**Expected behavior:**
- Windows `.lnk` shortcuts are intentionally skipped
- Other files (documents, images, etc.) are copied to `~/oldDesktop`
- Check `~/x0dus/old-desktop-items.txt` for a list of what was copied

#### Hardware drivers not detected

**Symptoms:** `linux-hardware-helper.sh` doesn't show any hardware or drivers.

**Cause:** Missing `hardware-inventory.csv` from Windows backup.

**Solutions:**
- Verify the file exists: `find /mnt/backup -name "hardware-inventory.csv"`
- Ensure Windows backup completed successfully and created inventories
- Re-run `backup.ps1` on Windows without `-DryRun` flag
- Manually specify the path when the helper prompts you

#### AI prompts seem generic or incomplete

**Symptoms:** Generated prompts don't include specific hardware or software details.

**Cause:** Hardware/software inventory files not found or not accessible.

**Solutions:**
- Ensure `linux-restore-helper.sh` was run first to mount the backup
- Verify inventory files exist: `ls /mnt/backup/logs/*.csv`
- Check workspace has inventory paths: `cat ~/x0dus/installed-software-inventory-path.txt`
- Re-run `linux-software-inventory.sh` and `linux-hardware-helper.sh` first

### General Issues

#### Git clone fails

**Symptoms:** `git clone https://github.com/Hexaxia-Technologies/x0dus.git` fails.

**Solutions:**
- Check internet connection
- Verify Git is installed: `git --version`
- Try HTTPS instead of SSH: Use the HTTPS URL from the README
- Check GitHub status: Visit https://www.githubstatus.com/

#### Scripts show "Permission denied"

**Symptoms:** Cannot execute bash scripts even after `chmod +x`.

**Solutions:**
- Verify execute permission: `ls -l linux-*.sh` (should show `-rwxr-xr-x`)
- Re-apply permissions: `chmod +x linux-*.sh`
- Run with bash explicitly: `bash linux-restore-helper.sh`
- Check if drive is mounted with `noexec` flag: `mount | grep $(df . | tail -1 | awk '{print $1}')`

#### Need to start over or redo a step

**Symptoms:** Made a mistake and want to re-run helpers.

**Solutions:**
- Helpers can be re-run multiple times safely
- To reset workspace state: `rm -rf ~/x0dus/` and start fresh
- To redo data restore: Delete copied files from home directory first
- Workspace files are just text files - you can edit them manually if needed: `nano ~/x0dus/mount-point.txt`

### Recommended workflow

For the smoothest migration experience, run the helpers in this order:

1. **On Windows:** Run `backup.ps1` to create the backup with hardware and software inventories
2. **On Linux:** Run `linux-restore-helper.sh` to mount the backup drive
3. **On Linux:** Run `linux-data-restore.sh` to copy your Windows profile
4. **On Linux:** Run `linux-hardware-helper.sh` to check hardware compatibility
5. **On Linux:** Run `linux-software-inventory.sh` to see software alternatives
6. **On Linux:** Run `linux-ai-prompt-generator.sh` to generate AI assistance prompts
