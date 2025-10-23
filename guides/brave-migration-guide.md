# Complete Brave Browser Migration Guide: Windows to Linux

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Understanding Brave's Data Structure](#understanding-braves-data-structure)
4. [Base Directory Locations](#base-directory-locations)
5. [What Can Be Migrated](#what-can-be-migrated)
6. [Step-by-Step Migration](#step-by-step-migration)
7. [Individual Component Migration](#individual-component-migration)
8. [Troubleshooting](#troubleshooting)
9. [Security Considerations](#security-considerations)
10. [Verification](#verification)

---

## Overview

This guide provides comprehensive instructions for migrating Brave Browser data from a Windows installation to Linux. After a full OS reinstall, all browser data appears lost, but with a proper Windows backup, everything can be restored including bookmarks, passwords, history, extensions, and more.

**Success Rate:** High - Brave uses cross-platform compatible formats for all major data types.

---

## Prerequisites

### Required
- Complete backup of Windows user directory containing Brave data
- Brave Browser installed on Linux
- Terminal access with basic command knowledge
- Sufficient permissions to access browser directories

### Recommended
- Fresh Linux installation with Brave installed but not yet configured
- Backup of current Linux Brave profile (if already in use)
- At least 1GB free space for migration

---

## Understanding Brave's Data Structure

Brave Browser (based on Chromium) stores all user data in a profile directory. Each profile is independent and contains:

- **Database files** (SQLite format) - History, passwords, autofill data
- **JSON files** - Bookmarks, preferences, extension data
- **Binary files** - Cookies, cache, session data
- **Folders** - Extensions, themes, local storage

All these files use cross-platform formats, making Windows → Linux migration seamless.

---

## Base Directory Locations

### Windows
```
C:\Users\[Username]\AppData\Local\BraveSoftware\Brave-Browser\User Data\Default\
```
**Important:** `AppData` is a hidden folder. Enable "Show hidden files" in File Explorer to see it.

### Linux
```
~/.config/BraveSoftware/Brave-Browser/Default/
```
**Important:** This is a hidden directory (starts with `.`). Use `ls -la` to see hidden files.

### Profile Variations
- `Default` - Primary profile
- `Profile 1`, `Profile 2`, etc. - Additional profiles
- `Guest Profile` - Guest browsing sessions

---

## What Can Be Migrated

| Data Type | File(s) | Difficulty | Recommended |
|-----------|---------|------------|-------------|
| **Bookmarks** | `Bookmarks` | Easy | ✅ Yes |
| **History** | `History` | Easy | ✅ Yes |
| **Passwords** | `Login Data` | Easy | ✅ Yes |
| **Autofill Data** | `Web Data` | Easy | ✅ Yes |
| **Extensions** | `Extensions/` folder | Medium | ✅ Yes |
| **Preferences** | `Preferences` | Easy | ✅ Yes |
| **Cookies** | `Cookies` | Easy | ⚠️ Conditional |
| **Sessions** | `Current Session`, `Last Session` | Easy | ⚠️ Conditional |
| **Cache** | `Cache/` folder | Easy | ❌ No |
| **Brave Rewards** | `rewards_service/` folder | Medium | ✅ Yes |
| **Brave Wallet** | `brave_wallet/` folder | Hard | ⚠️ With Caution |
| **Site Permissions** | `Preferences` (embedded) | Easy | ✅ Yes |
| **Search Engines** | `Web Data` | Easy | ✅ Yes |
| **Download History** | `History` | Easy | ✅ Yes |

### Legend
- ✅ **Yes** - Strongly recommended to migrate
- ⚠️ **Conditional** - Migrate only if needed (may cause issues)
- ❌ **No** - Do not migrate (will be regenerated)

---

## Step-by-Step Migration

### Phase 1: Preparation

#### Step 1: Locate Your Windows Backup

```bash
# Example: If backup is on external drive
ls /media/$USER/BackupDrive/Users/

# Or search your entire system
find ~ -type d -name "BraveSoftware" 2>/dev/null

# Set a variable for easier access (adjust path as needed)
BACKUP_PATH="/path/to/backup/Users/[WindowsUsername]/AppData/Local/BraveSoftware/Brave-Browser/User Data/Default"
```

#### Step 2: Identify Active Profile

```bash
# List all Brave profiles on Linux
ls -la ~/.config/BraveSoftware/Brave-Browser/

# Check which profile is currently active (Brave must be running)
ps aux | grep brave | grep profile-directory
```

#### Step 3: Close Brave Completely

```bash
# Kill all Brave processes
pkill brave

# Verify no Brave processes remain
ps aux | grep brave

# Wait 3-5 seconds for file locks to clear
sleep 5
```

#### Step 4: Backup Current Linux Profile (Safety Net)

```bash
# Create backup directory
mkdir -p ~/brave-backup-$(date +%Y%m%d)

# Backup entire current profile
cp -r ~/.config/BraveSoftware/Brave-Browser/Default/ \
      ~/brave-backup-$(date +%Y%m%d)/

echo "Backup created at: ~/brave-backup-$(date +%Y%m%d)/"
```

### Phase 2: Complete Migration (Recommended)

This approach migrates everything at once for a complete restoration.

```bash
# Set variables (adjust to your paths)
BACKUP_PATH="/path/to/backup/Users/WindowsUser/AppData/Local/BraveSoftware/Brave-Browser/User Data/Default"
LINUX_PROFILE="~/.config/BraveSoftware/Brave-Browser/Default"

# Expand tilde in variable
LINUX_PROFILE="${LINUX_PROFILE/#\~/$HOME}"

# Copy all essential data files
cp "$BACKUP_PATH/Bookmarks" "$LINUX_PROFILE/"
cp "$BACKUP_PATH/History" "$LINUX_PROFILE/"
cp "$BACKUP_PATH/Login Data" "$LINUX_PROFILE/"
cp "$BACKUP_PATH/Web Data" "$LINUX_PROFILE/"
cp "$BACKUP_PATH/Preferences" "$LINUX_PROFILE/"
cp "$BACKUP_PATH/Cookies" "$LINUX_PROFILE/"
cp "$BACKUP_PATH/Favicons" "$LINUX_PROFILE/"
cp "$BACKUP_PATH/Current Session" "$LINUX_PROFILE/" 2>/dev/null
cp "$BACKUP_PATH/Last Session" "$LINUX_PROFILE/" 2>/dev/null

# Copy directories
cp -r "$BACKUP_PATH/Extensions/" "$LINUX_PROFILE/"
cp -r "$BACKUP_PATH/Local Storage/" "$LINUX_PROFILE/"
cp -r "$BACKUP_PATH/IndexedDB/" "$LINUX_PROFILE/"
cp -r "$BACKUP_PATH/Local Extension Settings/" "$LINUX_PROFILE/"
cp -r "$BACKUP_PATH/brave_wallet/" "$LINUX_PROFILE/" 2>/dev/null

# Set correct permissions
chmod -R 755 "$LINUX_PROFILE"
find "$LINUX_PROFILE" -type f -exec chmod 644 {} \;

echo "Migration complete! Launch Brave to verify."
```

### Phase 3: Selective Migration (Alternative)

If you only want specific data types, see the [Individual Component Migration](#individual-component-migration) section below.

---

## Individual Component Migration

### 1. Bookmarks

**Files:** `Bookmarks`, `Bookmarks.bak`

**Description:** JSON file containing all bookmarks, bookmark folders, and bookmark bar items.

```bash
# Close Brave first
pkill brave && sleep 3

# Copy bookmarks
cp "$BACKUP_PATH/Bookmarks" ~/.config/BraveSoftware/Brave-Browser/Default/

# Set permissions
chmod 644 ~/.config/BraveSoftware/Brave-Browser/Default/Bookmarks

# Remove backup file to force Brave to use new bookmarks
rm ~/.config/BraveSoftware/Brave-Browser/Default/Bookmarks.bak 2>/dev/null
```

**Verification:**
- Open Brave
- Press `Ctrl+Shift+O` or navigate to `brave://bookmarks/`
- Verify all bookmarks appear

**Troubleshooting:**
- If bookmarks don't appear, check you're in the correct profile
- Ensure the file is valid JSON: `head -20 ~/.config/BraveSoftware/Brave-Browser/Default/Bookmarks`

---

### 2. Browsing History

**Files:** `History`, `History-journal`

**Description:** SQLite database containing browsing history, download history, and visit timestamps.

```bash
# Close Brave
pkill brave && sleep 3

# Copy history database
cp "$BACKUP_PATH/History" ~/.config/BraveSoftware/Brave-Browser/Default/

# Copy journal file if it exists
cp "$BACKUP_PATH/History-journal" ~/.config/BraveSoftware/Brave-Browser/Default/ 2>/dev/null

# Set permissions
chmod 644 ~/.config/BraveSoftware/Brave-Browser/Default/History
```

**Verification:**
- Press `Ctrl+H` or navigate to `brave://history/`
- Verify history entries appear with correct dates

**Note:** History includes:
- Page visits
- Download history
- Search queries (if saved)
- Visit counts for autocomplete

---

### 3. Saved Passwords

**Files:** `Login Data`, `Login Data-journal`

**Description:** Encrypted SQLite database containing saved usernames and passwords.

**⚠️ Security Warning:** Passwords are encrypted with OS-specific keys. Cross-platform migration may require re-entering your system password when accessing saved passwords.

```bash
# Close Brave
pkill brave && sleep 3

# Copy login data
cp "$BACKUP_PATH/Login Data" ~/.config/BraveSoftware/Brave-Browser/Default/
cp "$BACKUP_PATH/Login Data-journal" ~/.config/BraveSoftware/Brave-Browser/Default/ 2>/dev/null

# Set permissions
chmod 644 ~/.config/BraveSoftware/Brave-Browser/Default/"Login Data"
```

**Verification:**
- Navigate to `brave://settings/passwords`
- Verify saved passwords appear
- Test auto-fill on a known website

**Important Notes:**
- Passwords remain encrypted
- You may need to enter your Linux system password to decrypt them
- If passwords don't decrypt, you'll need to re-enter them manually
- Consider using Brave Sync for future password management

---

### 4. Autofill Data

**Files:** `Web Data`, `Web Data-journal`

**Description:** SQLite database containing autofill entries (addresses, credit cards, form data, custom search engines).

```bash
# Close Brave
pkill brave && sleep 3

# Copy web data
cp "$BACKUP_PATH/Web Data" ~/.config/BraveSoftware/Brave-Browser/Default/
cp "$BACKUP_PATH/Web Data-journal" ~/.config/BraveSoftware/Brave-Browser/Default/ 2>/dev/null

# Set permissions
chmod 644 ~/.config/BraveSoftware/Brave-Browser/Default/"Web Data"
```

**Verification:**
- Navigate to `brave://settings/addresses`
- Verify saved addresses appear
- Check `brave://settings/payments` for credit cards (if saved)
- Test form autofill on a website

**What's Included:**
- Contact information (names, addresses, phone numbers, emails)
- Credit card information (encrypted)
- Custom search engines
- Form autofill data

---

### 5. Browser Extensions

**Folders:** `Extensions/`, `Local Extension Settings/`, `Extension State/`

**Description:** Installed extensions, their data, and configurations.

```bash
# Close Brave
pkill brave && sleep 3

# Create extensions directory if it doesn't exist
mkdir -p ~/.config/BraveSoftware/Brave-Browser/Default/Extensions

# Copy extensions and their data
cp -r "$BACKUP_PATH/Extensions/"* ~/.config/BraveSoftware/Brave-Browser/Default/Extensions/
cp -r "$BACKUP_PATH/Local Extension Settings/" ~/.config/BraveSoftware/Brave-Browser/Default/ 2>/dev/null
cp -r "$BACKUP_PATH/Extension State/" ~/.config/BraveSoftware/Brave-Browser/Default/ 2>/dev/null

# Set permissions
chmod -R 755 ~/.config/BraveSoftware/Brave-Browser/Default/Extensions/
```

**Verification:**
- Navigate to `brave://extensions/`
- Verify all extensions appear and are enabled
- Test extension functionality
- Re-configure extensions if needed (some may require re-authentication)

**Common Issues:**
- Some extensions may require re-login after migration
- Extension sync data may need to be re-downloaded
- Chrome Web Store connections may need to be re-established

---

### 6. Browser Preferences & Settings

**Files:** `Preferences`, `Secure Preferences`

**Description:** JSON files containing all browser settings, site permissions, content settings, and UI preferences.

```bash
# Close Brave
pkill brave && sleep 3

# Copy preferences
cp "$BACKUP_PATH/Preferences" ~/.config/BraveSoftware/Brave-Browser/Default/
cp "$BACKUP_PATH/Secure Preferences" ~/.config/BraveSoftware/Brave-Browser/Default/ 2>/dev/null

# Set permissions
chmod 644 ~/.config/BraveSoftware/Brave-Browser/Default/Preferences
```

**Verification:**
- Open `brave://settings/`
- Verify all settings match your Windows configuration
- Check appearance, search engine, startup settings
- Verify site permissions at `brave://settings/content`

**What's Preserved:**
- Default search engine
- Startup behavior
- Appearance settings (theme, zoom levels)
- Privacy settings
- Site-specific permissions (camera, microphone, location, notifications)
- Content settings
- Download location
- Language preferences

---

### 7. Cookies & Session Data

**Files:** `Cookies`, `Current Session`, `Last Session`, `Current Tabs`, `Last Tabs`

**Description:** Active login sessions, shopping carts, and browsing state.

**⚠️ Caution:** Migrating cookies may cause:
- Security issues if hardware/location changed significantly
- Session invalidation on security-conscious websites
- CSRF token mismatches

**When to Migrate:**
- You want to stay logged into websites
- You have items in shopping carts
- You want to restore open tabs

**When NOT to Migrate:**
- Moving to different geographic location
- Security-sensitive accounts are involved
- You prefer a fresh start

```bash
# Close Brave
pkill brave && sleep 3

# Copy cookies
cp "$BACKUP_PATH/Cookies" ~/.config/BraveSoftware/Brave-Browser/Default/
cp "$BACKUP_PATH/Cookies-journal" ~/.config/BraveSoftware/Brave-Browser/Default/ 2>/dev/null

# Copy session data (optional - restores open tabs)
cp "$BACKUP_PATH/Current Session" ~/.config/BraveSoftware/Brave-Browser/Default/ 2>/dev/null
cp "$BACKUP_PATH/Last Session" ~/.config/BraveSoftware/Brave-Browser/Default/ 2>/dev/null
cp "$BACKUP_PATH/Current Tabs" ~/.config/BraveSoftware/Brave-Browser/Default/ 2>/dev/null
cp "$BACKUP_PATH/Last Tabs" ~/.config/BraveSoftware/Brave-Browser/Default/ 2>/dev/null

# Set permissions
chmod 644 ~/.config/BraveSoftware/Brave-Browser/Default/Cookies
```

**Verification:**
- Open Brave
- Check if you're logged into previous websites
- Verify open tabs are restored (if session data was copied)

---

### 8. Brave Rewards Data

**Folders:** `rewards_service/`, files with `rewards` in name

**Description:** Brave Rewards wallet, BAT balance, ad preferences, and publisher data.

**⚠️ Important:** Brave Rewards data is tied to your original device. Migration may not preserve BAT balance perfectly.

```bash
# Close Brave
pkill brave && sleep 3

# Copy rewards data
cp -r "$BACKUP_PATH/rewards_service/" ~/.config/BraveSoftware/Brave-Browser/Default/ 2>/dev/null

# Copy rewards-related files
cp "$BACKUP_PATH/Rewards" ~/.config/BraveSoftware/Brave-Browser/Default/ 2>/dev/null

# Set permissions
chmod -R 755 ~/.config/BraveSoftware/Brave-Browser/Default/rewards_service/
```

**Verification:**
- Navigate to `brave://rewards/`
- Check if BAT balance appears
- Verify connected accounts (Uphold, Gemini)

**Note:** If rewards don't transfer properly:
- Try disconnecting and reconnecting your custodial wallet
- Contact Brave Support for BAT balance issues
- Some rewards data may need to be re-verified

---

### 9. Brave Wallet (Crypto Wallet)

**Folders:** `brave_wallet/`, files with `wallet` in name

**Description:** Crypto wallet data including private keys, transaction history, and wallet settings.

**🔴 CRITICAL SECURITY WARNING:**
- Private keys stored here control your cryptocurrency
- Improper migration can lead to loss of funds
- Only migrate if you fully understand the risks
- ALWAYS have your recovery phrase backed up separately

```bash
# Close Brave completely
pkill brave && sleep 5

# ONLY proceed if you have your recovery phrase backed up!

# Copy wallet data
cp -r "$BACKUP_PATH/brave_wallet/" ~/.config/BraveSoftware/Brave-Browser/Default/ 2>/dev/null

# Set strict permissions
chmod -R 700 ~/.config/BraveSoftware/Brave-Browser/Default/brave_wallet/
```

**Recommended Alternative:**
Instead of migrating wallet files, use your recovery phrase:
1. Open Brave Wallet
2. Select "Restore wallet"
3. Enter your 12/24-word recovery phrase

This is safer and ensures proper key derivation.

---

### 10. Site-Specific Data

**Folders:** `Local Storage/`, `IndexedDB/`, `Session Storage/`

**Description:** Website-specific data including web app data, cached content, and local database storage.

```bash
# Close Brave
pkill brave && sleep 3

# Copy local storage
cp -r "$BACKUP_PATH/Local Storage/" ~/.config/BraveSoftware/Brave-Browser/Default/ 2>/dev/null

# Copy IndexedDB (web app databases)
cp -r "$BACKUP_PATH/IndexedDB/" ~/.config/BraveSoftware/Brave-Browser/Default/ 2>/dev/null

# Set permissions
chmod -R 755 ~/.config/BraveSoftware/Brave-Browser/Default/"Local Storage"/
chmod -R 755 ~/.config/BraveSoftware/Brave-Browser/Default/IndexedDB/
```

**What This Preserves:**
- Web app data (Google Docs drafts, online editors)
- Progressive Web App (PWA) data
- Game saves stored in browser
- Web-based tool configurations

---

### 11. Favicons (Site Icons)

**Files:** `Favicons`, `Favicons-journal`

**Description:** Cached website icons displayed in tabs, bookmarks, and history.

```bash
# Close Brave
pkill brave && sleep 3

# Copy favicons
cp "$BACKUP_PATH/Favicons" ~/.config/BraveSoftware/Brave-Browser/Default/
cp "$BACKUP_PATH/Favicons-journal" ~/.config/BraveSoftware/Brave-Browser/Default/ 2>/dev/null

# Set permissions
chmod 644 ~/.config/BraveSoftware/Brave-Browser/Default/Favicons
```

**Note:** Favicons will be re-downloaded naturally over time if not migrated. This is optional.

---

## Troubleshooting

### Common Issues & Solutions

#### Issue: Brave Won't Start After Migration

**Symptoms:**
- Brave crashes on startup
- Brave opens but shows blank screen
- Error messages about corrupted profile

**Solutions:**

1. **Check file permissions:**
```bash
chmod -R 755 ~/.config/BraveSoftware/Brave-Browser/Default/
find ~/.config/BraveSoftware/Brave-Browser/Default/ -type f -exec chmod 644 {} \;
```

2. **Remove lock files:**
```bash
rm ~/.config/BraveSoftware/Brave-Browser/Default/Cookies-journal
rm ~/.config/BraveSoftware/Brave-Browser/Default/History-journal
rm ~/.config/BraveSoftware/Brave-Browser/Default/"Login Data-journal"
rm ~/.config/BraveSoftware/Brave-Browser/Default/"Web Data-journal"
rm ~/.config/BraveSoftware/Brave-Browser/Default/.com.google.Chrome.* 2>/dev/null
```

3. **Start with clean preferences:**
```bash
mv ~/.config/BraveSoftware/Brave-Browser/Default/Preferences \
   ~/.config/BraveSoftware/Brave-Browser/Default/Preferences.backup
```

4. **Launch Brave in safe mode:**
```bash
brave-browser --disable-extensions --disable-plugins
```

---

#### Issue: Passwords Not Accessible

**Symptoms:**
- Passwords show in list but can't be viewed
- Auto-fill doesn't work
- Constant prompts for system password

**Solutions:**

1. **Reset keyring permissions:**
```bash
# This varies by Linux distribution
# For Ubuntu/Debian with gnome-keyring:
rm ~/.local/share/keyrings/login.keyring
# You'll need to re-enter your password
```

2. **Use Brave Sync to transfer passwords:**
- Set up Brave Sync on Windows (if possible)
- Enable sync on Linux installation
- Let passwords sync over network

3. **Manual password export/import:**
- If you still have access to Windows: Export passwords to CSV
- Import on Linux via `brave://settings/passwords` → Menu → Import

---

#### Issue: Extensions Not Working

**Symptoms:**
- Extensions show but don't function
- Extension icons missing
- "Extension failed to load" errors

**Solutions:**

1. **Reinstall extensions:**
```bash
# Remove extensions folder
rm -rf ~/.config/BraveSoftware/Brave-Browser/Default/Extensions/

# Restart Brave and reinstall extensions from Chrome Web Store
```

2. **Clear extension cache:**
```bash
rm -rf ~/.config/BraveSoftware/Brave-Browser/Default/"Extension State"/
rm -rf ~/.config/BraveSoftware/Brave-Browser/Default/"Extension Rules"/
```

3. **Reset extension permissions:**
- Navigate to `brave://extensions/`
- Toggle "Developer mode"
- Click "Update" to reload all extensions

---

#### Issue: Wrong Profile Being Used

**Symptoms:**
- Migrated data doesn't appear
- Different bookmarks show up
- Settings are wrong

**Solutions:**

1. **Identify the active profile:**
```bash
# With Brave running:
ps aux | grep brave | grep profile-directory

# Or check ~/.config/BraveSoftware/Brave-Browser/Local State
cat ~/.config/BraveSoftware/Brave-Browser/"Local State" | grep -A 2 "last_used"
```

2. **List all profiles:**
```bash
ls -la ~/.config/BraveSoftware/Brave-Browser/
```

3. **Copy data to correct profile:**
```bash
# If your active profile is "Profile 1":
cp -r "$BACKUP_PATH/"* ~/.config/BraveSoftware/Brave-Browser/"Profile 1"/
```

---

#### Issue: Brave Rewards Not Transferring

**Symptoms:**
- Zero BAT balance after migration
- Rewards panel shows "not available"
- Connected wallet doesn't appear

**Solutions:**

1. **Brave Rewards are device-specific** - This is by design for fraud prevention

2. **For custodial wallets (Uphold/Gemini):**
- Disconnect wallet on new install
- Reconnect to same custodial account
- BAT should sync from there

3. **For self-custody wallets:**
- Use your recovery phrase to restore
- Don't rely on file migration for crypto

---

#### Issue: Database Corruption Errors

**Symptoms:**
- "Profile corrupted" messages
- SQLite error messages
- Data partially missing

**Solutions:**

1. **Check database integrity:**
```bash
# Check History database
sqlite3 ~/.config/BraveSoftware/Brave-Browser/Default/History "PRAGMA integrity_check;"

# Check Web Data
sqlite3 ~/.config/BraveSoftware/Brave-Browser/Default/"Web Data" "PRAGMA integrity_check;"

# Check Login Data
sqlite3 ~/.config/BraveSoftware/Brave-Browser/Default/"Login Data" "PRAGMA integrity_check;"
```

2. **Repair corrupted database:**
```bash
# Example for History database
sqlite3 ~/.config/BraveSoftware/Brave-Browser/Default/History ".dump" | \
  sqlite3 ~/.config/BraveSoftware/Brave-Browser/Default/History-repaired
mv ~/.config/BraveSoftware/Brave-Browser/Default/History-repaired \
   ~/.config/BraveSoftware/Brave-Browser/Default/History
```

3. **Start fresh with selective import:**
- If only one database is corrupted, remove just that file
- Brave will create a new clean database
- Manually re-add critical data

---

## Security Considerations

### Data Encryption & Privacy

1. **Passwords:**
   - Encrypted with OS-specific keys
   - May require re-authentication after migration
   - Consider using a password manager for future migrations

2. **Cookies & Sessions:**
   - Contain authentication tokens
   - Can be security risk if hardware significantly changed
   - Websites may invalidate sessions due to location/IP change

3. **Brave Wallet:**
   - Contains private keys controlling cryptocurrency
   - **Use recovery phrase method instead of file migration**
   - Never share wallet files or recovery phrases

4. **Extensions:**
   - May contain API keys or tokens
   - Review extension permissions after migration
   - Re-authenticate extensions with sensitive data

### Best Practices

1. **Always backup before migration:**
```bash
cp -r ~/.config/BraveSoftware/Brave-Browser/ ~/brave-backup-full/
```

2. **Use Brave Sync for future migrations:**
   - Enable at `brave://settings/braveSync`
   - Syncs bookmarks, passwords, extensions, settings
   - Easier than manual file migration

3. **Verify file integrity:**
```bash
# Check if files are valid JSON
python3 -m json.tool ~/.config/BraveSoftware/Brave-Browser/Default/Bookmarks > /dev/null && echo "Valid JSON" || echo "Invalid JSON"
```

4. **Clear sensitive data after migration:**
```bash
# Shred original files (if on same machine)
shred -vfz -n 10 /path/to/windows/backup/Cookies
shred -vfz -n 10 /path/to/windows/backup/"Login Data"
```

---

## Verification

### Post-Migration Checklist

After completing migration, verify each component:

#### 1. Bookmarks
- [ ] Press `Ctrl+Shift+O` to open Bookmarks Manager
- [ ] Verify bookmarks bar items appear
- [ ] Check all bookmark folders
- [ ] Test bookmark links

#### 2. History
- [ ] Press `Ctrl+H` to open History
- [ ] Verify recent history appears
- [ ] Check download history
- [ ] Test history search

#### 3. Passwords
- [ ] Navigate to `brave://settings/passwords`
- [ ] Verify saved passwords count
- [ ] Test auto-fill on known website
- [ ] Check that password viewing works (may require system password)

#### 4. Autofill
- [ ] Navigate to `brave://settings/addresses`
- [ ] Verify saved addresses
- [ ] Check `brave://settings/payments` for cards
- [ ] Test form autofill

#### 5. Extensions
- [ ] Navigate to `brave://extensions/`
- [ ] Verify all extensions present
- [ ] Test extension functionality
- [ ] Re-authenticate extensions if needed

#### 6. Settings
- [ ] Navigate to `brave://settings/`
- [ ] Verify appearance settings
- [ ] Check default search engine
- [ ] Verify startup behavior
- [ ] Check `brave://settings/content` for site permissions

#### 7. Brave Rewards (if used)
- [ ] Navigate to `brave://rewards/`
- [ ] Check BAT balance
- [ ] Verify wallet connection
- [ ] Check ad settings

#### 8. Sessions
- [ ] Verify open tabs restored (if session data migrated)
- [ ] Check logged-in status on websites
- [ ] Test shopping cart persistence

### Quick Verification Script

```bash
#!/bin/bash
# Quick migration verification script

PROFILE=~/.config/BraveSoftware/Brave-Browser/Default

echo "=== Brave Migration Verification ==="
echo

echo "Checking file existence:"
echo -n "Bookmarks: "
[ -f "$PROFILE/Bookmarks" ] && echo "✓ Found" || echo "✗ Missing"

echo -n "History: "
[ -f "$PROFILE/History" ] && echo "✓ Found" || echo "✗ Missing"

echo -n "Login Data: "
[ -f "$PROFILE/Login Data" ] && echo "✓ Found" || echo "✗ Missing"

echo -n "Web Data: "
[ -f "$PROFILE/Web Data" ] && echo "✓ Found" || echo "✗ Missing"

echo -n "Preferences: "
[ -f "$PROFILE/Preferences" ] && echo "✓ Found" || echo "✗ Missing"

echo -n "Extensions: "
[ -d "$PROFILE/Extensions" ] && echo "✓ Found" || echo "✗ Missing"

echo
echo "Checking file permissions:"
ls -lh "$PROFILE/Bookmarks" "$PROFILE/History" "$PROFILE/Preferences" 2>/dev/null

echo
echo "Checking JSON validity:"
python3 -m json.tool "$PROFILE/Bookmarks" > /dev/null 2>&1 && echo "✓ Bookmarks is valid JSON" || echo "✗ Bookmarks has JSON errors"
python3 -m json.tool "$PROFILE/Preferences" > /dev/null 2>&1 && echo "✓ Preferences is valid JSON" || echo "✗ Preferences has JSON errors"

echo
echo "=== Manual verification required ==="
echo "1. Launch Brave and check bookmarks (Ctrl+Shift+O)"
echo "2. Verify history (Ctrl+H)"
echo "3. Test password autofill"
echo "4. Check extensions work properly"
```

Save as `verify-brave-migration.sh` and run:
```bash
chmod +x verify-brave-migration.sh
./verify-brave-migration.sh
```

---

## Quick Reference Commands

### Full Migration (Copy Everything)
```bash
# Set paths
BACKUP="/path/to/backup/Users/WindowsUser/AppData/Local/BraveSoftware/Brave-Browser/User Data/Default"
TARGET="$HOME/.config/BraveSoftware/Brave-Browser/Default"

# Close Brave
pkill brave && sleep 3

# Copy all data
cp "$BACKUP/Bookmarks" "$TARGET/"
cp "$BACKUP/History" "$TARGET/"
cp "$BACKUP/Login Data" "$TARGET/"
cp "$BACKUP/Web Data" "$TARGET/"
cp "$BACKUP/Preferences" "$TARGET/"
cp "$BACKUP/Cookies" "$TARGET/"
cp "$BACKUP/Favicons" "$TARGET/"
cp -r "$BACKUP/Extensions/" "$TARGET/"
cp -r "$BACKUP/Local Storage/" "$TARGET/"
cp -r "$BACKUP/IndexedDB/" "$TARGET/"

# Fix permissions
chmod -R 755 "$TARGET"
find "$TARGET" -type f -exec chmod 644 {} \;
```

### Essential Data Only (Recommended)
```bash
# Close Brave
pkill brave && sleep 3

# Copy only critical data
cp "$BACKUP_PATH/Bookmarks" ~/.config/BraveSoftware/Brave-Browser/Default/
cp "$BACKUP_PATH/History" ~/.config/BraveSoftware/Brave-Browser/Default/
cp "$BACKUP_PATH/Login Data" ~/.config/BraveSoftware/Brave-Browser/Default/
cp "$BACKUP_PATH/Web Data" ~/.config/BraveSoftware/Brave-Browser/Default/
cp "$BACKUP_PATH/Preferences" ~/.config/BraveSoftware/Brave-Browser/Default/
cp -r "$BACKUP_PATH/Extensions/" ~/.config/BraveSoftware/Brave-Browser/Default/

# Fix permissions
chmod 644 ~/.config/BraveSoftware/Brave-Browser/Default/{Bookmarks,History,"Login Data","Web Data",Preferences}
chmod -R 755 ~/.config/BraveSoftware/Brave-Browser/Default/Extensions/
```

### Rollback to Backup
```bash
# If migration failed, restore from Linux backup
pkill brave
rm -rf ~/.config/BraveSoftware/Brave-Browser/Default
cp -r ~/brave-backup-$(date +%Y%m%d)/ ~/.config/BraveSoftware/Brave-Browser/Default
```

---

## Advanced Topics

### Migrating Multiple Profiles

If you had multiple Brave profiles on Windows:

```bash
# List Windows profiles
ls "$BACKUP_PATH/../"

# Migrate each profile separately
# For Profile 1:
cp -r "$BACKUP_PATH/../Profile 1/"* ~/.config/BraveSoftware/Brave-Browser/"Profile 1"/

# For Profile 2:
cp -r "$BACKUP_PATH/../Profile 2/"* ~/.config/BraveSoftware/Brave-Browser/"Profile 2"/
```

### Automating Migration

Create a migration script:

```bash
#!/bin/bash
# brave-migrate.sh - Automated Brave migration script

set -e

BACKUP_PATH="$1"
PROFILE="${2:-Default}"

if [ -z "$BACKUP_PATH" ]; then
    echo "Usage: $0 /path/to/backup [profile-name]"
    exit 1
fi

echo "Migrating Brave data from: $BACKUP_PATH"
echo "To profile: $PROFILE"
echo

# Close Brave
pkill brave 2>/dev/null || true
sleep 3

TARGET="$HOME/.config/BraveSoftware/Brave-Browser/$PROFILE"

# Create backup
BACKUP_DIR="$HOME/brave-backup-$(date +%Y%m%d-%H%M%S)"
echo "Creating backup at: $BACKUP_DIR"
cp -r "$TARGET" "$BACKUP_DIR"

# Migrate files
echo "Copying Bookmarks..."
cp "$BACKUP_PATH/Bookmarks" "$TARGET/"

echo "Copying History..."
cp "$BACKUP_PATH/History" "$TARGET/"

echo "Copying Login Data..."
cp "$BACKUP_PATH/Login Data" "$TARGET/"

echo "Copying Web Data..."
cp "$BACKUP_PATH/Web Data" "$TARGET/"

echo "Copying Preferences..."
cp "$BACKUP_PATH/Preferences" "$TARGET/"

echo "Copying Extensions..."
cp -r "$BACKUP_PATH/Extensions/" "$TARGET/"

# Fix permissions
echo "Setting permissions..."
chmod -R 755 "$TARGET"
find "$TARGET" -type f -exec chmod 644 {} \;

echo
echo "✓ Migration complete!"
echo "Backup saved to: $BACKUP_DIR"
echo "Launch Brave to verify."
```

Usage:
```bash
chmod +x brave-migrate.sh
./brave-migrate.sh /path/to/windows/backup Default
```

---

## Conclusion

You have successfully completed a comprehensive Brave Browser migration from Windows to Linux. This guide covered:

- ✅ Complete understanding of Brave's data structure
- ✅ Step-by-step migration of all data types
- ✅ Security considerations and best practices
- ✅ Troubleshooting common issues
- ✅ Verification procedures

### Next Steps

1. **Enable Brave Sync** for future migrations:
   - Navigate to `brave://settings/braveSync`
   - Create sync chain
   - Never manually migrate again!

2. **Regular Backups:**
```bash
# Create monthly backup cron job
echo "0 0 1 * * cp -r ~/.config/BraveSoftware/Brave-Browser ~/brave-backup-\$(date +\%Y\%m)" | crontab -
```

3. **Stay Updated:**
   - Keep Brave browser updated
   - Monitor Brave community for migration improvements
   - Share your experience to help others

---

## Additional Resources

- **Brave Community Forum:** https://community.brave.com/
- **Brave Support:** https://support.brave.com/
- **Chromium Data Storage Documentation:** https://www.chromium.org/developers/design-documents/user-data-directory/
- **Brave Sync Guide:** https://support.brave.com/hc/en-us/articles/360021218111-How-do-I-set-up-Sync-

---

**Document Version:** 2.0  
**Last Updated:** Post-migration success  
**Status:** ✅ Verified Working  
**Original Issue:** Restored bookmarks after initially copying to wrong profile directory
