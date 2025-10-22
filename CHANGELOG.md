# Changelog

All notable changes to x0dus will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

No unreleased changes. See [GitHub Issues](https://github.com/Hexaxia-Technologies/x0dus/issues) for planned enhancements.

## [1.0.0.RC1] - 2025-10-22

**Note:** This is a maintenance release containing critical bug fixes discovered shortly after the v1.0.0 release. RC1 designation indicates thorough testing is recommended before production use.

### Added

**PowerShell Backup Script (backup.ps1):**
- Failed files logging: Creates `logs/failed-files-<timestamp>.log` with detailed list of files that couldn't be copied
- New function `Get-FailedFilesLogPath`: Generates timestamped path for failed files log
- New function `Parse-FailedFiles`: Parses robocopy logs to extract failed file paths and writes them to dedicated log with session headers, source path sections, and file counts
- Backup completion summary: Shows comprehensive report at end of backup indicating success or failures with remediation guidance

### Changed

**PowerShell Backup Script (backup.ps1):**
- **BREAKING BEHAVIOR CHANGE**: Robocopy errors no longer cause script to quit
  - Exit codes 4-7 (warnings): Script logs failures and continues with remaining backup items
  - Exit codes 8+ (critical errors): Script logs failures, displays warnings, and continues instead of throwing error
  - Failed files are logged to dedicated log file for each source path
  - Users receive comprehensive summary at end showing what failed and why
- Modified `Invoke-RobocopyBackup`: Added `$FailedFilesLog` parameter and changed error handling to continue on failures instead of quitting
- Error handling: Removed `throw` statement that was causing script termination on robocopy errors

### Fixed

- Issue where robocopy errors (especially in AppData with locked files) would cause entire backup script to quit prematurely, preventing backup of remaining important data

## [1.0.0] - 2025-10-20

### Added

**PowerShell Backup Script (backup.ps1):**
- Interactive backup wizard with 4 modes: Essential Files Only, Essential + Settings (recommended), Full User Profile, and Custom Backup
- Granular AppData filtering modes: Full, RoamingOnly, None, and EssentialFoldersOnly
- Hardware inventory export (`hardware-inventory.csv`) for Linux driver compatibility analysis
- Software inventory export (`installed-software.csv`) for application migration planning
- Pre-flight space checks with color-coded utilization warnings
- User confirmation prompts for tight space situations and before backup execution
- Robocopy retry logic with exponential backoff (configurable retries and delays)
- Progress visualization showing current item, total items, and progress percentage
- Network share support for both SMB and NFS destinations
- Script transcript logging to `logs/script-*.log` alongside Robocopy logs
- Professional branding with Hexaxia Technologies hexagonal logo and disclaimer
- Comprehensive error handling and validation
- Command-line parameters: `-NonInteractive`, `-ForceCreateDestination`, `-RobocopyThreads`, `-RobocopyRetries`, `-RobocopyRetryDelaySeconds`

**Linux Helper Scripts:**
- `linux-restore-helper.sh` - Locate and mount backup drives (local or network SMB/NFS)
- `linux-data-restore.sh` - Restore Windows profile to Linux home directory with desktop file handling
- `linux-software-inventory.sh` - Parse Windows software inventory and provide distro-specific package manager guidance
- `linux-hardware-helper.sh` - Analyze hardware inventory for Linux compatibility with color-coded warnings (Red/Yellow/Green)
- `linux-ai-prompt-generator.sh` - Generate contextual AI chatbot prompts for migration assistance (6 prompt types)
- Shared workspace at `~/x0dus/` for state persistence across helper runs
- Consistent branding with hexagonal ASCII logo (cyan color approximating #77bfab)
- Version management with `--version` and `--help` flags on all scripts
- Distribution detection for 8+ Linux families (Debian, Fedora, Arch, openSUSE, Gentoo, Alpine, Void, etc.)

### Documentation
- Comprehensive README.md with 11+ usage examples
- Contributing guidelines (CONTRIBUTING.md) with code style and PR requirements
- MIT License
- Professional disclaimers in all script banners

### Security
- Credential handling for SMB network shares
- Privilege escalation support (sudo/doas) in Linux helpers
- Safe AppData filtering to reduce sensitive cache data in backups
