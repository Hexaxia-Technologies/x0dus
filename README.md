# x0dus

Windows and Linux helper scripts to migrate to Linux.

## Overview

The repository provides four companion scripts:

- A PowerShell helper (`backup.ps1`) that copies the entire user profile on
  Windows 10 and Windows 11 machines to a safe location before replacing the
  operating system with Linux. The script also collects an inventory of
  installed software to help with post-migration setup.
- A Bash helper (`linux-restore-helper.sh`) that runs on Linux after the
  migration, summarizes distro details, and guides you through locating and
  mounting the backup drive so you can restore files.
- A data restoration helper (`linux-data-restore.sh`) that copies a selected
  Windows profile into the current Linux home directory, checks available
  space, and collects Windows desktop files (excluding shortcuts) under
  `~/oldDesktop` so the new desktop remains tidy.
- A follow-up Bash helper (`linux-software-inventory.sh`) that inspects the
  mounted backup, summarizes the Windows software inventory, and prints
  reinstall guidance tailored to the detected Linux distribution.

Both Linux helpers record their activity under `~/x0dus`, a workspace folder
in the current user's home directory that keeps logs, detected system details,
and handy path references so you can resume the migration at any point.

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

After Git is installed, download the helpers to `~/x0dus` (replace
`your-account` with the actual repository owner if it differs):

```bash
cd ~
git clone https://github.com/your-account/x0dus.git
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

### Example: non-interactive creation of the destination

```powershell
.\backup.ps1 -DestinationPath "E:\UserBackup" -ForceCreateDestination -DryRun
```
```

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
When the backup completes, the script exports an `installed-software.csv` file
containing the Display Name, Version, Publisher, Install Date, and Install
Location reported by Windows for each detected program.

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
