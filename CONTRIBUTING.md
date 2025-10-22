# Contributing to x0dus

Thank you for your interest in contributing to x0dus! This document provides guidelines for contributing to the Windows-to-Linux migration toolkit.

## Reporting Issues

Please report bugs and feature requests via [GitHub Issues](https://github.com/Hexaxia-Technologies/x0dus/issues).

### When Reporting Bugs

Please include the following information:

- **Operating System:** Windows version (10/11 build) or Linux distribution and version
- **Script Version:** Run `.\backup.ps1 -Version` or `./script-name.sh --version`
- **Complete Error Messages:** Copy the full error text, not just summaries
- **Steps to Reproduce:** Detailed steps that consistently trigger the issue
- **Expected vs Actual Behavior:** What you expected to happen vs what actually happened
- **Log Files:** Include relevant portions of log files from `logs/` directory or `~/x0dus/`

### Feature Requests

When requesting features:
- Explain the use case and why it's valuable
- Provide examples of how it would be used
- Consider if it fits the project's scope (Windows-to-Linux migration)

## Pull Requests

We welcome pull requests! Before submitting substantial changes:

1. **Open an issue first** to discuss the proposed change
2. **Keep changes focused** - one feature or fix per PR
3. **Test thoroughly** on both Windows and Linux where applicable
4. **Update documentation** for any new features or changed behavior

### Before Submitting a PR

- [ ] Test your changes on the target platform (Windows for PowerShell, Linux for Bash)
- [ ] Update README.md if adding features or changing usage
- [ ] Update CLAUDE.md if changing architecture or adding new functions
- [ ] Update CHANGELOG.md under the `[Unreleased]` section
- [ ] Follow existing code style (see below)
- [ ] Ensure all scripts remain compatible with stated requirements
- [ ] Add inline comments for complex logic
- [ ] Test with `-DryRun` mode where applicable

## Code Style Guidelines

### PowerShell (backup.ps1)

- **Function Naming:** Use approved PowerShell Verb-Noun format (e.g., `Get-BackupItems`, `Test-IsValid`)
- **Parameters:** Use `[CmdletBinding()]` and proper parameter validation
- **Error Handling:** Use try/catch blocks, provide helpful error messages
- **Comments:** Use `# Single line` for brief notes, `<# Multi-line #>` for function documentation
- **Formatting:** 4-space indentation, opening braces on same line as statement
- **Help:** Include `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, and `.EXAMPLE` in function headers

Example:
```powershell
function Get-BackupSize {
    <#
    .SYNOPSIS
    Calculates total size of backup items.

    .DESCRIPTION
    Recursively scans directories and sums file sizes.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    # Implementation
}
```

### Bash (Linux helpers)

- **Function Naming:** Use snake_case (e.g., `print_header`, `detect_distro`)
- **Script Header:** Always include `set -euo pipefail` for strict error handling
- **Variables:** Use descriptive UPPERCASE for globals, lowercase for locals
- **Quoting:** Always quote variables: `"$variable"` not `$variable`
- **Error Messages:** Print to stderr: `echo "Error" >&2`
- **Comments:** Use `#` for single-line comments
- **Formatting:** 2-space indentation

Example:
```bash
#!/bin/bash
set -euo pipefail

detect_distro() {
  local name="Unknown"

  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    name=${NAME:-$name}
  fi

  echo "$name"
}
```

### Version Numbers

- Update version in **all** relevant files when bumping versions:
  - `backup.ps1`: `$scriptVersion`
  - All `.sh` files: `SCRIPT_VERSION`
  - `README.md`: `**Version:**` line
  - `CLAUDE.md`: Version history section
  - `CHANGELOG.md`: Add new version section

### Documentation Style

- Use **Markdown** for all documentation
- Use `**bold**` for emphasis, `*italic*` for technical terms on first use
- Use code blocks with language hints: ` ```powershell ` or ` ```bash `
- Use `inline code` for commands, file names, and parameter names
- Structure sections with clear hierarchy (##, ###, ####)
- Keep line length reasonable (wrap around 100 characters for readability)

## Testing

### PowerShell Testing

Test on Windows using the `-DryRun` parameter:

```powershell
# Test with dry run
.\backup.ps1 -DestinationPath "C:\Test" -DryRun

# Test different modes
.\backup.ps1 -DestinationPath "C:\Test" -AppDataMode RoamingOnly -DryRun
.\backup.ps1 -DestinationPath "C:\Test" -AppDataMode EssentialFoldersOnly -DryRun

# Test network shares
.\backup.ps1 -NetworkShare "\\nas\test" -DestinationPath "test" -DryRun
```

### Bash Testing

Test on Linux with various distributions (Debian/Ubuntu, Fedora, Arch recommended):

```bash
# Make executable
chmod +x script-name.sh

# Test help and version
./script-name.sh --help
./script-name.sh --version

# Test dry run if applicable
./script-name.sh --dry-run
```

### Cross-Platform Considerations

- **Line Endings:** Use LF (Unix) line endings for Bash scripts, CRLF (Windows) for PowerShell
- **Paths:** Use platform-appropriate path separators
- **Compatibility:** PowerShell must work on Windows 10/11 with PowerShell 5.1+
- **Dependencies:** Minimize external dependencies, document any required packages

## Project Structure

```
x0dus/
├── backup.ps1                      # Windows backup script
├── linux-restore-helper.sh         # Linux mount helper
├── linux-data-restore.sh           # Linux data restore
├── linux-software-inventory.sh     # Software analysis
├── linux-hardware-helper.sh        # Hardware compatibility
├── linux-ai-prompt-generator.sh    # AI prompt generator
├── README.md                       # User documentation
├── CLAUDE.md                       # Developer documentation
├── CHANGELOG.md                    # Version history
├── CONTRIBUTING.md                 # This file
├── LICENSE                         # MIT License
└── .gitignore                      # Git ignore rules
```

## Development Workflow

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make your changes
4. Test thoroughly
5. Commit with clear messages: `git commit -m "Add feature X"`
6. Push to your fork: `git push origin feature/my-feature`
7. Open a Pull Request with a clear description

## Commit Message Guidelines

- Use present tense: "Add feature" not "Added feature"
- Use imperative mood: "Fix bug" not "Fixes bug"
- First line should be concise (50 characters or less)
- Add detailed description after a blank line if needed
- Reference issue numbers: "Fixes #123" or "Related to #456"

Example:
```
Add NTFS mount troubleshooting guide

- Add comprehensive NTFS troubleshooting section to README
- Cover Fast Startup, dirty flag, and permission issues
- Include distro-specific ntfsfix commands
- Add dual-boot considerations

Fixes #42
```

## Code of Conduct

- Be respectful and constructive in all interactions
- Focus on the technical merits of contributions
- Help newcomers feel welcome
- Accept constructive criticism gracefully

## Questions?

- Open an issue for questions about contributing
- Tag issues with `question` label
- Check existing issues and documentation first

## License

By contributing to x0dus, you agree that your contributions will be licensed under the MIT License.

---

**Thank you for contributing to x0dus!** Your help makes Windows-to-Linux migration easier for everyone.
