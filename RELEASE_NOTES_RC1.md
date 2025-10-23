# x0dus v1.0.0.RC1 - Release Candidate 1

**Release Date:** October 22, 2025

**Note:** This is a maintenance release containing critical bug fixes discovered shortly after the v1.0.0 release. RC1 designation indicates thorough testing is recommended before production use.

## What's New in RC1

### Critical Bug Fixes

**Robocopy Error Handling**
- Fixed issue where robocopy errors (especially locked files in AppData) would cause the entire backup script to quit prematurely
- Script now continues backing up remaining files when some files fail to copy
- Added comprehensive failed files logging and reporting

### New Features

**Failed Files Logging**
- Creates `logs/failed-files-<timestamp>.log` with detailed list of files that couldn't be copied
- Logs are organized by source path with timestamps and file counts
- Helps identify which files need manual backup or are safe to skip

**Backup Completion Summary**
- Shows comprehensive report at end of backup indicating success or failures
- Provides remediation guidance for common failure scenarios
- Lists common reasons: files in use, permissions, locked files, network errors

**Improved Error Handling**
- Exit codes 4-7 (warnings): Script logs failures and continues with remaining backup items
- Exit codes 8+ (critical errors): Script logs failures, displays warnings, and continues instead of throwing error
- Removed `throw` statement that was causing script termination on robocopy errors

### New Functions

- `Get-FailedFilesLogPath`: Generates timestamped path for failed files log
- `Parse-FailedFiles`: Parses robocopy logs to extract failed file paths and writes them to dedicated log
- Modified `Invoke-RobocopyBackup`: Added `$FailedFilesLog` parameter and changed error handling

## Installation

### Windows (Backup Script)

1. Download `backup.ps1` from this release
2. Run PowerShell and execute:
   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   .\backup.ps1
   ```
3. Follow the interactive wizard

### Linux (Migration Helpers)

```bash
# Clone or download the repository
git clone https://github.com/Hexaxia-Technologies/x0dus.git
cd x0dus

# Make scripts executable
chmod +x *.sh

# Run the helpers in order
./linux-restore-helper.sh
./linux-data-restore.sh
./linux-software-inventory.sh
./linux-hardware-helper.sh
./linux-ai-prompt-generator.sh
```

## What's Included

### Scripts
- `backup.ps1` - Windows backup script (PowerShell)
- `linux-restore-helper.sh` - Mount backup drive helper
- `linux-data-restore.sh` - Restore Windows data to Linux
- `linux-software-inventory.sh` - Analyze Windows software
- `linux-hardware-helper.sh` - Check hardware compatibility
- `linux-ai-prompt-generator.sh` - Generate AI assistance prompts

### Documentation
- `README.md` - Comprehensive user guide with examples
- `CONTRIBUTING.md` - Contribution guidelines
- `CHANGELOG.md` - Version history
- `LICENSE` - MIT License

## System Requirements

**Windows:**
- Windows 10 or Windows 11
- PowerShell 5.1 or newer (included with Windows)
- Sufficient free space for backup

**Linux:**
- Any modern Linux distribution
- Bash shell
- Python 3 (for software inventory parsing)
- Git (recommended)

## Known Issues

- None reported for RC1

## Upgrade Notes

If upgrading from v1.0.0:
- No breaking changes to command-line parameters
- New failed files logging is automatic, no configuration needed
- Review failed files log after backup to identify any missed files

## Documentation

Full documentation available in [README.md](https://github.com/Hexaxia-Technologies/x0dus/blob/main/README.md)

### Quick Links
- [Quick Start Guide](https://github.com/Hexaxia-Technologies/x0dus#quick-start)
- [Troubleshooting](https://github.com/Hexaxia-Technologies/x0dus#troubleshooting)
- [NTFS Drive Issues](https://github.com/Hexaxia-Technologies/x0dus#ntfs-drive-issues-windows-backup-drives)
- [Contributing](https://github.com/Hexaxia-Technologies/x0dus/blob/main/CONTRIBUTING.md)

## Support

- Report issues: [GitHub Issues](https://github.com/Hexaxia-Technologies/x0dus/issues)
- View source: [GitHub Repository](https://github.com/Hexaxia-Technologies/x0dus)
- Organization: [Hexaxia Technologies](https://hexaxia.tech)

## License

MIT License - See [LICENSE](https://github.com/Hexaxia-Technologies/x0dus/blob/main/LICENSE) for details

Copyright (c) 2025 Hexaxia Technologies

---

**Thank you for using x0dus!** We hope this toolkit makes your Windows-to-Linux migration smooth and straightforward.
