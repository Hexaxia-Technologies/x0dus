# Browser Migration Guides

**x0dus v1.0.0.RC1** - Windows-to-Linux Migration Toolkit

This directory contains comprehensive browser migration guides to help you restore browser data after migrating from Windows to Linux.

---

## Overview

After running the x0dus backup on Windows and installing Linux, your Windows browser data appears lost. However, with the backup created by x0dus, you can restore **everything**:

- Bookmarks and bookmark folders
- Browsing history
- Saved passwords and autofill data
- Browser extensions and their settings
- Preferences and site permissions
- Cookies and active sessions (optional)
- Search engines and customizations

These guides provide step-by-step instructions for migrating your browser profile data from your Windows backup to your Linux installation.

---

## When to Use These Guides

**Timing:**
1. After running `backup.ps1` on Windows to create your backup
2. After migrating to Linux and mounting your backup drive
3. After installing your preferred browser on Linux
4. Before configuring your new browser (fresh install recommended)

**Prerequisites:**
- x0dus backup containing Windows user profile
- Backup drive accessible on Linux (see `linux-restore-helper.sh`)
- Browser installed on Linux
- Terminal access with basic command knowledge

---

## Available Guides

### [Firefox Migration Guide](firefox-migration-guide.md)
**42 KB | Comprehensive**

Migrate Mozilla Firefox data from Windows to Linux.

**What's Covered:**
- Complete profile structure explanation
- Full profile copy method (simplest, recommended)
- Selective component migration (advanced)
- Password encryption key handling
- Extension and add-on migration
- Session restore and container tabs
- Verification scripts included

**Key Advantage:** Firefox uses identical cross-platform profile structures, making migration extremely reliable. Single profile folder copy restores everything.

**Best For:**
- Users who value simplicity (complete profile copy)
- Privacy-focused users
- Power users with multiple profiles

---

### [Brave Browser Migration Guide](brave-migration-guide.md)
**31 KB | Comprehensive**

Migrate Brave Browser data from Windows to Linux.

**What's Covered:**
- Chromium-based profile structure
- Full migration and selective component migration
- Brave-specific features (Rewards, Wallet)
- Extension and preference migration
- Password keyring considerations
- Troubleshooting common issues
- Verification checklist

**Key Advantage:** Brave uses cross-platform Chromium format. Includes specialized guidance for Brave Rewards wallet and BAT balance preservation.

**Best For:**
- Privacy-focused Chromium users
- Crypto wallet users (Brave Wallet)
- Users earning BAT via Brave Rewards

---

### [Chrome/Chromium Migration Guide](chrome-chromium-migration-guide.md)
**46 KB | Most Comprehensive**

Migrate Google Chrome or Chromium Browser data from Windows to Linux.

**What's Covered:**
- Chrome vs Chromium differences explained
- Complete migration process for both browsers
- Cross-browser compatibility (Chrome ↔ Chromium)
- Google Sync as alternative migration method
- Extension and PWA migration
- Multiple profile handling
- Comprehensive troubleshooting section
- Automation scripts included

**Key Advantage:** Covers both Chrome and Chromium. Includes Chrome Sync guidance (easiest method if available). Data fully compatible between Chrome and Chromium.

**Best For:**
- Google Chrome users with Sync enabled
- Chromium users
- Users migrating between Chrome and Chromium
- IT administrators managing multiple migrations

---

## Quick Comparison

| Feature | Firefox | Brave | Chrome/Chromium |
|---------|---------|-------|-----------------|
| **Ease of Migration** | ⭐⭐⭐⭐⭐ Easiest | ⭐⭐⭐⭐ Easy | ⭐⭐⭐⭐ Easy |
| **Method** | Copy entire profile folder | Copy files/folders | Copy files/folders |
| **Bookmarks Format** | SQLite database | JSON file | JSON file |
| **Password Migration** | JSON + encryption key | SQLite + OS keyring | SQLite + OS keyring |
| **Cloud Sync Option** | Firefox Sync | Brave Sync | Chrome Sync (Chrome only) |
| **Special Features** | Containers, sync | Rewards, Wallet | Google integration |
| **Guide Size** | 42 KB | 31 KB | 46 KB (most detailed) |

---

## Migration Workflow

### Step 1: Locate Your Windows Browser Data
All guides include instructions for finding your Windows backup profile:

**Firefox:**
```
/path/to/backup/Users/[Username]/AppData/Roaming/Mozilla/Firefox/Profiles/[id].default-release/
```

**Brave:**
```
/path/to/backup/Users/[Username]/AppData/Local/BraveSoftware/Brave-Browser/User Data/Default/
```

**Chrome:**
```
/path/to/backup/Users/[Username]/AppData/Local/Google/Chrome/User Data/Default/
```

**Chromium:**
```
/path/to/backup/Users/[Username]/AppData/Local/Chromium/User Data/Default/
```

### Step 2: Choose Your Migration Strategy

**Complete Profile Copy (Recommended for most users):**
- Copies all browser data at once
- Simplest and fastest method
- Restores everything including settings, extensions, and data
- Best success rate

**Selective Component Migration (Advanced users):**
- Choose specific data types to migrate (bookmarks, passwords, etc.)
- More control over what gets migrated
- Skip unwanted data (cookies, cache, etc.)
- Useful for troubleshooting or partial migrations

### Step 3: Follow the Guide

Each guide provides:
- **Pre-flight checks** - Close browser, backup current profile
- **Step-by-step commands** - Copy-paste ready bash commands
- **Permission fixes** - Ensure correct file ownership
- **Verification steps** - Confirm successful migration
- **Troubleshooting** - Solutions for common issues

### Step 4: Verify Migration

All guides include verification checklists and optional verification scripts:
- Test bookmarks and history
- Verify password autofill works
- Check extension functionality
- Confirm settings preserved
- Review site permissions

---

## Common Issues & Solutions

### All Browsers

**Issue: Browser won't start after migration**
- Check file permissions (should be 644 for files, 755 for directories)
- Remove lock files (`.parentlock`, `SingletonLock`, etc.)
- Start browser in safe mode to diagnose
- See guide-specific troubleshooting sections

**Issue: Passwords not accessible**
- Ensure encryption key files were copied (Firefox: `key4.db`, Chrome/Brave: `Login Data`)
- OS-specific encryption may require re-entry
- Consider using browser sync or password manager for future migrations
- See password-specific sections in each guide

**Issue: Extensions not working**
- Extension compatibility varies by platform
- Some may require re-authentication
- Try reinstalling problematic extensions
- See extension migration sections in each guide

---

## Migration Tips

### Before Migration
- **Close the browser completely** before copying files
- **Backup your current Linux profile** in case you need to rollback
- **Free up space** - Ensure sufficient disk space for profile data
- **Review what to migrate** - You may not need everything (caches, etc.)

### During Migration
- **Follow commands exactly** - Copy-paste to avoid typos
- **Check paths carefully** - Ensure source and destination are correct
- **Watch for errors** - Read terminal output for copy failures
- **Be patient** - Large profiles may take several minutes

### After Migration
- **Verify all critical data** before deleting backups
- **Test major functionality** - Bookmarks, passwords, extensions
- **Re-authenticate extensions** if needed
- **Set up cloud sync** to avoid manual migration in the future

---

## Cloud Sync Alternatives

Consider using cloud sync for future migrations (much easier than file migration):

**Firefox Sync:**
- Navigate to `about:preferences#sync`
- Sign in with Firefox Account
- Select data types to sync
- Works on any Firefox installation

**Brave Sync:**
- Navigate to `brave://settings/braveSync`
- Create sync chain
- Syncs bookmarks, extensions, settings
- No Google account required

**Chrome Sync:**
- Navigate to `chrome://settings/syncSetup`
- Sign in with Google Account
- Syncs all data types
- **Note:** Only available in Chrome, not Chromium

---

## File Format Reference

Understanding browser data formats:

| Data Type | Firefox | Brave/Chrome |
|-----------|---------|--------------|
| **Bookmarks** | SQLite database | JSON file |
| **History** | SQLite database | SQLite database |
| **Passwords** | JSON + encryption key | SQLite + encryption |
| **Preferences** | JavaScript file | JSON file |
| **Extensions** | WebExtensions (XPI) | Chrome extensions (CRX) |
| **Sessions** | Compressed JSON (.mozlz4) | JSON files |

All formats are cross-platform compatible when migrating from Windows to Linux.

---

## Security Considerations

**Password Migration:**
- Passwords remain encrypted during migration
- Encryption keys are OS-specific - may require re-authentication
- Consider password manager (Bitwarden, 1Password) for future migrations
- Never share encryption key files

**Cookie Migration:**
- Cookies contain authentication tokens
- May be invalidated by websites due to IP/location change
- Consider skipping if security-sensitive accounts involved
- Fresh login may be more secure

**Extension Data:**
- Extensions may store API keys or tokens
- Review extension permissions after migration
- Re-authenticate extensions with sensitive data
- Remove unused extensions

**Best Practice:** Set restrictive file permissions after migration (600 for sensitive files, 700 for profile directory).

---

## Support & Resources

**x0dus Project:**
- GitHub: https://github.com/Hexaxia/x0dus (check CLAUDE.md for development notes)
- Version: 1.0.0.RC1
- Maintained by: Hexaxia Systems

**Browser-Specific Resources:**

**Firefox:**
- Mozilla Support: https://support.mozilla.org/
- Profile Documentation: https://support.mozilla.org/kb/profiles-where-firefox-stores-user-data
- Firefox Sync: https://www.mozilla.org/firefox/sync/

**Brave:**
- Brave Community: https://community.brave.com/
- Brave Support: https://support.brave.com/
- Brave Sync Guide: https://support.brave.com/hc/en-us/articles/360021218111

**Chrome:**
- Chrome Help: https://support.google.com/chrome/
- Chrome Sync: https://support.google.com/chrome/answer/185277
- Chrome on Linux: https://support.google.com/chrome/a/answer/9025903

**Chromium:**
- Chromium Project: https://www.chromium.org/
- Chromium Documentation: https://chromium.googlesource.com/chromium/src/+/master/docs/linux/

---

## Contributing

Found an issue or have a suggestion? These guides are part of the x0dus migration toolkit.

**Reporting Issues:**
- Check existing GitHub issues first
- Provide browser version, Linux distribution, and error details
- Include relevant log output or error messages

**Guide Improvements:**
- Typo fixes and clarity improvements welcome
- Additional troubleshooting scenarios appreciated
- Platform-specific edge cases valuable

---

## License

These guides are part of the x0dus Windows-to-Linux migration toolkit.

See the main x0dus repository for license information.

---

**Last Updated:** 2025-10-22
**Guide Versions:** All guides v1.0 (production-ready)
**Status:** Production release as part of x0dus v1.0.0.RC1

---

## Quick Start

**Choose your browser and follow the guide:**

1. **Firefox users:** [firefox-migration-guide.md](firefox-migration-guide.md) - Simplest migration (copy entire profile folder)
2. **Brave users:** [brave-migration-guide.md](brave-migration-guide.md) - Includes Rewards/Wallet guidance
3. **Chrome/Chromium users:** [chrome-chromium-migration-guide.md](chrome-chromium-migration-guide.md) - Most comprehensive, covers both browsers

**All guides follow the same general pattern:**
- Locate Windows backup
- Close browser
- Backup current Linux profile
- Copy data (complete or selective)
- Fix permissions
- Launch and verify

**Average migration time:** 5-15 minutes (depending on profile size and method chosen)

**Success rate:** Very high - browsers use cross-platform compatible data formats

---

**Happy migrating!**
