# Complete Firefox Browser Migration Guide: Windows to Linux

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Understanding Firefox's Data Structure](#understanding-firefoxs-data-structure)
4. [Base Directory Locations](#base-directory-locations)
5. [What Can Be Migrated](#what-can-be-migrated)
6. [Step-by-Step Migration](#step-by-step-migration)
7. [Individual Component Migration](#individual-component-migration)
8. [Troubleshooting](#troubleshooting)
9. [Security Considerations](#security-considerations)
10. [Verification](#verification)

---

## Overview

This guide provides comprehensive instructions for migrating Firefox Browser data from a Windows installation to Linux. After a full OS reinstall, all browser data appears lost, but with a proper Windows backup, everything can be restored including bookmarks, passwords, history, extensions, and more.

**Success Rate:** Very High - Firefox uses identical profile structures across all platforms, making cross-platform migration seamless.

**Key Difference from Chromium Browsers:** Firefox uses a profile-based system with a unique profile identifier (random string), making the migration process slightly different but often more reliable.

---

## Prerequisites

### Required
- Complete backup of Windows user directory containing Firefox data
- Firefox installed on Linux
- Terminal access with basic command knowledge
- Sufficient permissions to access browser directories

### Recommended
- Fresh Linux installation with Firefox installed but not yet configured
- Backup of current Linux Firefox profile (if already in use)
- At least 500MB free space for migration
- Knowledge of your Firefox profile name (optional but helpful)

---

## Understanding Firefox's Data Structure

Firefox uses a unique profile system different from Chromium-based browsers:

### Profile Structure
- Each Firefox installation can have multiple **profiles**
- Each profile has a **unique random identifier** (e.g., `abc12def.default-release`)
- Profile name format: `[random-string].[profile-name]`
- Default profile name: `default-release` (Firefox 67+) or `default` (older versions)

### What's in a Profile?
- **SQLite databases** - Bookmarks, history, passwords, cookies, form data
- **JSON files** - Preferences, extensions, add-on data
- **Binary files** - Encryption keys, session data
- **Folders** - Extensions, themes, cache

**Key Advantage:** All Firefox profile data is stored in a single directory, making complete migration extremely simple.

---

## Base Directory Locations

### Windows
```
C:\Users\[Username]\AppData\Roaming\Mozilla\Firefox\Profiles\[profile-id].default-release\
```

Example:
```
C:\Users\JohnDoe\AppData\Roaming\Mozilla\Firefox\Profiles\abc12def.default-release\
```

**Important:** 
- `AppData\Roaming` is a hidden folder
- The profile folder name includes a random string
- You may have multiple profiles

### Linux
```
~/.mozilla/firefox/[profile-id].default-release/
```

Example:
```
/home/johndoe/.mozilla/firefox/xyz98ghi.default-release/
```

**Important:**
- `.mozilla` is a hidden directory (starts with `.`)
- Profile ID will be different from Windows
- Use `ls -la ~/.mozilla/firefox/` to see profiles

### Configuration Files

**profiles.ini** - Located one level up from profiles:
- Windows: `C:\Users\[Username]\AppData\Roaming\Mozilla\Firefox\profiles.ini`
- Linux: `~/.mozilla/firefox/profiles.ini`

This file tells Firefox which profiles exist and which is default.

---

## What Can Be Migrated

| Data Type | File(s) | Difficulty | Recommended |
|-----------|---------|------------|-------------|
| **Bookmarks** | `places.sqlite` | Easy | ✅ Yes |
| **History** | `places.sqlite` | Easy | ✅ Yes |
| **Passwords** | `logins.json`, `key4.db` | Easy | ✅ Yes |
| **Cookies** | `cookies.sqlite` | Easy | ⚠️ Conditional |
| **Form Data** | `formhistory.sqlite` | Easy | ✅ Yes |
| **Preferences** | `prefs.js` | Easy | ✅ Yes |
| **Extensions** | `extensions.json`, `addons/` | Easy | ✅ Yes |
| **Search Engines** | `search.json.mozlz4` | Easy | ✅ Yes |
| **Permissions** | `permissions.sqlite` | Easy | ✅ Yes |
| **Site Settings** | `content-prefs.sqlite` | Easy | ✅ Yes |
| **Sessions** | `sessionstore.jsonlz4` | Easy | ⚠️ Conditional |
| **Favicons** | `favicons.sqlite` | Easy | ✅ Optional |
| **Cache** | `cache2/` folder | Easy | ❌ No |
| **Thumbnails** | `thumbnails/` | Easy | ❌ No |
| **Extension Storage** | `storage/` folder | Medium | ✅ Yes |
| **Certificates** | `cert9.db` | Easy | ✅ Yes |

### Legend
- ✅ **Yes** - Strongly recommended to migrate
- ⚠️ **Conditional** - Migrate only if needed (may cause issues)
- ❌ **No** - Do not migrate (will be regenerated)

---

## Step-by-Step Migration

### Method 1: Complete Profile Copy (Recommended - Easiest)

This is the simplest and most reliable method - copy the entire profile directory.

#### Step 1: Locate Windows Firefox Profile

```bash
# If backup is mounted at /media/backup
find /media/backup -type d -name "Firefox" 2>/dev/null

# Or search for profiles.ini
find /media/backup -name "profiles.ini" 2>/dev/null

# Set variable for easier access
WINDOWS_PROFILE="/media/backup/Users/[WindowsUsername]/AppData/Roaming/Mozilla/Firefox/Profiles/[profile-id].default-release"
```

**Finding Your Profile:**
1. Navigate to your Windows backup
2. Go to `Users/[YourUsername]/AppData/Roaming/Mozilla/Firefox/Profiles/`
3. Look for folder ending in `.default-release` or `.default`
4. This is your profile folder

#### Step 2: Close Firefox Completely

```bash
# Kill all Firefox processes
pkill firefox

# Verify no Firefox processes remain
ps aux | grep firefox

# Wait for file locks to clear
sleep 5
```

#### Step 3: Backup Current Linux Profile (Safety)

```bash
# Create backup directory
mkdir -p ~/firefox-backup-$(date +%Y%m%d)

# Find current Linux profile
LINUX_PROFILE=$(find ~/.mozilla/firefox/ -maxdepth 1 -type d -name "*.default*" | head -1)

# Backup it
cp -r "$LINUX_PROFILE" ~/firefox-backup-$(date +%Y%m%d)/

echo "Backup created at: ~/firefox-backup-$(date +%Y%m%d)/"
```

#### Step 4: Copy Entire Windows Profile

```bash
# Method A: Replace Linux profile completely (RECOMMENDED)
# This preserves the Linux profile name but uses Windows data

WINDOWS_PROFILE="/path/to/backup/Profiles/abc12def.default-release"
LINUX_PROFILE=$(find ~/.mozilla/firefox/ -maxdepth 1 -type d -name "*.default*" | head -1)

# Remove current Linux profile contents (already backed up)
rm -rf "$LINUX_PROFILE"/*

# Copy all Windows profile data
cp -r "$WINDOWS_PROFILE"/* "$LINUX_PROFILE"/

# Fix permissions
chmod -R 755 "$LINUX_PROFILE"
find "$LINUX_PROFILE" -type f -exec chmod 644 {} \;

echo "Migration complete! Launch Firefox to verify."
```

```bash
# Method B: Alternative - Create new profile with Windows data
# Use this if Method A causes issues

WINDOWS_PROFILE="/path/to/backup/Profiles/abc12def.default-release"

# Create a new profile directory (Firefox will detect it)
PROFILE_NAME="migrated-$(date +%Y%m%d)"
NEW_PROFILE=~/.mozilla/firefox/migrated.default

mkdir -p "$NEW_PROFILE"
cp -r "$WINDOWS_PROFILE"/* "$NEW_PROFILE"/

# Add profile to profiles.ini
echo "" >> ~/.mozilla/firefox/profiles.ini
echo "[Profile1]" >> ~/.mozilla/firefox/profiles.ini
echo "Name=$PROFILE_NAME" >> ~/.mozilla/firefox/profiles.ini
echo "IsRelative=1" >> ~/.mozilla/firefox/profiles.ini
echo "Path=migrated.default" >> ~/.mozilla/firefox/profiles.ini
echo "Default=1" >> ~/.mozilla/firefox/profiles.ini

chmod -R 755 "$NEW_PROFILE"
find "$NEW_PROFILE" -type f -exec chmod 644 {} \;

echo "New profile created! Launch Firefox to verify."
```

#### Step 5: Launch Firefox

```bash
firefox
```

Firefox should start with all your Windows data restored!

---

### Method 2: Selective File Migration (Advanced)

If you only want specific data types, see the [Individual Component Migration](#individual-component-migration) section.

---

## Individual Component Migration

### 1. Bookmarks and History

**File:** `places.sqlite`

**Description:** Single SQLite database containing both bookmarks (with tags, folders) and complete browsing history.

```bash
# Close Firefox
pkill firefox && sleep 5

# Find your Linux profile
LINUX_PROFILE=$(find ~/.mozilla/firefox/ -maxdepth 1 -type d -name "*.default*" | head -1)

# Backup current database
cp "$LINUX_PROFILE/places.sqlite" "$LINUX_PROFILE/places.sqlite.backup" 2>/dev/null

# Copy Windows database
cp "$WINDOWS_PROFILE/places.sqlite" "$LINUX_PROFILE/"

# Set permissions
chmod 644 "$LINUX_PROFILE/places.sqlite"

# Remove journal files to force Firefox to use new database
rm "$LINUX_PROFILE/places.sqlite-wal" 2>/dev/null
rm "$LINUX_PROFILE/places.sqlite-shm" 2>/dev/null
```

**Verification:**
- Press `Ctrl+Shift+O` to open Library
- Click "Bookmarks" in sidebar
- Check "History" in sidebar
- Verify both bookmarks and history appear

**What's Included:**
- All bookmarks with folder structure
- Bookmark tags and keywords
- Complete browsing history with visit counts
- Download history
- Favicon associations

**Troubleshooting:**
- If bookmarks don't appear, check database integrity:
```bash
sqlite3 "$LINUX_PROFILE/places.sqlite" "PRAGMA integrity_check;"
```

---

### 2. Saved Passwords

**Files:** `logins.json`, `key4.db` (encryption key)

**Description:** Passwords are stored encrypted in `logins.json`, with encryption keys in `key4.db`. **Both files must be copied together**.

**⚠️ Important:** 
- Master password (if set on Windows) must be remembered
- If master password was set, you'll need it on Linux too
- Passwords cannot be decrypted without proper key file

```bash
# Close Firefox
pkill firefox && sleep 5

LINUX_PROFILE=$(find ~/.mozilla/firefox/ -maxdepth 1 -type d -name "*.default*" | head -1)

# Backup current files
cp "$LINUX_PROFILE/logins.json" "$LINUX_PROFILE/logins.json.backup" 2>/dev/null
cp "$LINUX_PROFILE/key4.db" "$LINUX_PROFILE/key4.db.backup" 2>/dev/null

# Copy both password files (MUST copy both!)
cp "$WINDOWS_PROFILE/logins.json" "$LINUX_PROFILE/"
cp "$WINDOWS_PROFILE/key4.db" "$LINUX_PROFILE/"

# Also copy key3.db if it exists (older Firefox versions)
cp "$WINDOWS_PROFILE/key3.db" "$LINUX_PROFILE/" 2>/dev/null

# Set permissions
chmod 644 "$LINUX_PROFILE/logins.json"
chmod 644 "$LINUX_PROFILE/key4.db"
```

**Verification:**
- Navigate to `about:logins`
- Verify saved passwords appear
- Test auto-fill on a known website
- If master password was set, you'll be prompted to enter it

**Security Notes:**
- Passwords remain encrypted
- Master password (if set) is required to access them
- Consider using Firefox Sync or a password manager for future migrations

---

### 3. Form Autofill Data

**File:** `formhistory.sqlite`

**Description:** Contains form field history (previously entered values in text boxes).

```bash
# Close Firefox
pkill firefox && sleep 5

LINUX_PROFILE=$(find ~/.mozilla/firefox/ -maxdepth 1 -type d -name "*.default*" | head -1)

# Copy form history
cp "$WINDOWS_PROFILE/formhistory.sqlite" "$LINUX_PROFILE/"

# Set permissions
chmod 644 "$LINUX_PROFILE/formhistory.sqlite"
```

**Verification:**
- Visit a website with a form
- Start typing in a text field
- Verify autocomplete suggestions appear

**What's Included:**
- Search box history
- Form field entries (names, addresses, etc.)
- Text input history across websites

**Note:** Firefox Autofill for addresses/credit cards is stored in `autofill-profiles.json` (if present).

---

### 4. Browser Preferences & Settings

**File:** `prefs.js`

**Description:** Plain text JavaScript file containing all Firefox preferences and settings.

**⚠️ Caution:** Some preferences are OS-specific (paths, fonts). Consider manual review.

```bash
# Close Firefox
pkill firefox && sleep 5

LINUX_PROFILE=$(find ~/.mozilla/firefox/ -maxdepth 1 -type d -name "*.default*" | head -1)

# Backup current preferences
cp "$LINUX_PROFILE/prefs.js" "$LINUX_PROFILE/prefs.js.backup" 2>/dev/null

# Copy preferences
cp "$WINDOWS_PROFILE/prefs.js" "$LINUX_PROFILE/"

# Set permissions
chmod 644 "$LINUX_PROFILE/prefs.js"
```

**What's Preserved:**
- Default search engine
- Homepage and new tab settings
- Privacy & security settings
- Downloads folder location (may need adjustment for Linux)
- Zoom levels
- Language preferences
- Network settings
- Content settings

**Manual Adjustment Needed:**
If you have custom download paths or other OS-specific settings, edit `prefs.js`:

```bash
# Example: Change Windows download path to Linux path
sed -i 's|C:\\\\Users\\\\.*\\\\Downloads|/home/'$USER'/Downloads|g' "$LINUX_PROFILE/prefs.js"
```

**Verification:**
- Navigate to `about:preferences`
- Check all settings tabs
- Verify settings match your expectations

---

### 5. Extensions (Add-ons)

**Files/Folders:** `extensions.json`, `extensions/` folder, `extension-data/`, `browser-extension-data/`

**Description:** Installed extensions, their settings, and local data.

```bash
# Close Firefox
pkill firefox && sleep 5

LINUX_PROFILE=$(find ~/.mozilla/firefox/ -maxdepth 1 -type d -name "*.default*" | head -1)

# Copy extension metadata
cp "$WINDOWS_PROFILE/extensions.json" "$LINUX_PROFILE/"
cp "$WINDOWS_PROFILE/extension-settings.json" "$LINUX_PROFILE/" 2>/dev/null

# Copy extensions folder
cp -r "$WINDOWS_PROFILE/extensions/" "$LINUX_PROFILE/" 2>/dev/null

# Copy extension data
cp -r "$WINDOWS_PROFILE/extension-data/" "$LINUX_PROFILE/" 2>/dev/null
cp -r "$WINDOWS_PROFILE/browser-extension-data/" "$LINUX_PROFILE/" 2>/dev/null

# Copy storage (extension local storage)
cp -r "$WINDOWS_PROFILE/storage/" "$LINUX_PROFILE/" 2>/dev/null

# Set permissions
chmod -R 755 "$LINUX_PROFILE/extensions/" 2>/dev/null
chmod -R 755 "$LINUX_PROFILE/extension-data/" 2>/dev/null
chmod -R 755 "$LINUX_PROFILE/browser-extension-data/" 2>/dev/null
chmod 644 "$LINUX_PROFILE/extensions.json"
```

**Verification:**
- Navigate to `about:addons`
- Verify all extensions appear
- Check extension settings/configurations
- Test extension functionality

**Common Issues:**
- Some extensions may require re-authentication
- Extension sync data may need to be re-downloaded
- System extensions (OS-specific) won't work across platforms

**Alternative Method:**
If extension migration fails, you can:
1. Export list of extensions from Windows (manually note them down)
2. Fresh install on Linux
3. Copy only `browser-extension-data/` for extension settings

---

### 6. Search Engines

**File:** `search.json.mozlz4`

**Description:** Compressed JSON file containing custom search engines and their settings.

**Note:** `.mozlz4` is a Mozilla-specific LZ4 compression format.

```bash
# Close Firefox
pkill firefox && sleep 5

LINUX_PROFILE=$(find ~/.mozilla/firefox/ -maxdepth 1 -type d -name "*.default*" | head -1)

# Copy search engines
cp "$WINDOWS_PROFILE/search.json.mozlz4" "$LINUX_PROFILE/"

# Set permissions
chmod 644 "$LINUX_PROFILE/search.json.mozlz4"
```

**Verification:**
- Click address bar
- Type a search
- Check search engine dropdown (bottom of address bar)
- Verify custom search engines appear

**What's Preserved:**
- Custom search engines
- Search engine order
- One-click search engines
- Search shortcuts/keywords

---

### 7. Cookies & Session Data

**Files:** `cookies.sqlite`, `sessionstore.jsonlz4`

**Description:** Active login sessions and browsing state.

**⚠️ Caution:** Migrating cookies may cause:
- Security issues if hardware/location changed
- Session invalidation on security-conscious websites
- Potential tracking concerns

```bash
# Close Firefox
pkill firefox && sleep 5

LINUX_PROFILE=$(find ~/.mozilla/firefox/ -maxdepth 1 -type d -name "*.default*" | head -1)

# Copy cookies
cp "$WINDOWS_PROFILE/cookies.sqlite" "$LINUX_PROFILE/"
cp "$WINDOWS_PROFILE/cookies.sqlite-wal" "$LINUX_PROFILE/" 2>/dev/null
cp "$WINDOWS_PROFILE/cookies.sqlite-shm" "$LINUX_PROFILE/" 2>/dev/null

# Copy session (restores open tabs)
cp "$WINDOWS_PROFILE/sessionstore.jsonlz4" "$LINUX_PROFILE/"
cp "$WINDOWS_PROFILE/sessionstore-backups/" "$LINUX_PROFILE/" -r 2>/dev/null

# Set permissions
chmod 644 "$LINUX_PROFILE/cookies.sqlite"
chmod 644 "$LINUX_PROFILE/sessionstore.jsonlz4" 2>/dev/null
```

**Verification:**
- Launch Firefox
- Check if you're logged into websites
- Verify open tabs restored (if sessionstore was copied)

**When to Skip:**
- Moving to different geographic location
- Security-sensitive accounts involved
- Prefer fresh start with logins

---

### 8. Site Permissions & Settings

**Files:** `permissions.sqlite`, `content-prefs.sqlite`

**Description:** Site-specific permissions (camera, microphone, location, notifications) and preferences (zoom levels, character encoding).

```bash
# Close Firefox
pkill firefox && sleep 5

LINUX_PROFILE=$(find ~/.mozilla/firefox/ -maxdepth 1 -type d -name "*.default*" | head -1)

# Copy permissions
cp "$WINDOWS_PROFILE/permissions.sqlite" "$LINUX_PROFILE/"

# Copy site-specific preferences
cp "$WINDOWS_PROFILE/content-prefs.sqlite" "$LINUX_PROFILE/"

# Set permissions
chmod 644 "$LINUX_PROFILE/permissions.sqlite"
chmod 644 "$LINUX_PROFILE/content-prefs.sqlite"
```

**Verification:**
- Navigate to `about:preferences#privacy`
- Scroll to "Permissions" sections
- Check site permissions for camera, location, notifications
- Visit sites and verify zoom levels preserved

**What's Included:**
- Camera/microphone permissions
- Location permissions
- Notification permissions
- Autoplay settings per site
- Site-specific zoom levels
- Site-specific character encoding

---

### 9. Security Certificates

**Files:** `cert9.db`, `cert_override.txt`

**Description:** Imported certificates and certificate exceptions.

```bash
# Close Firefox
pkill firefox && sleep 5

LINUX_PROFILE=$(find ~/.mozilla/firefox/ -maxdepth 1 -type d -name "*.default*" | head -1)

# Copy certificate database
cp "$WINDOWS_PROFILE/cert9.db" "$LINUX_PROFILE/"

# Copy certificate exceptions
cp "$WINDOWS_PROFILE/cert_override.txt" "$LINUX_PROFILE/" 2>/dev/null

# Set permissions
chmod 644 "$LINUX_PROFILE/cert9.db"
```

**What's Preserved:**
- Imported CA certificates
- Personal certificates
- Certificate exceptions for self-signed certs

---

### 10. Favicons (Site Icons)

**File:** `favicons.sqlite`

**Description:** Cached website icons displayed in tabs, bookmarks, and history.

```bash
# Close Firefox
pkill firefox && sleep 5

LINUX_PROFILE=$(find ~/.mozilla/firefox/ -maxdepth 1 -type d -name "*.default*" | head -1)

# Copy favicons
cp "$WINDOWS_PROFILE/favicons.sqlite" "$LINUX_PROFILE/"

# Set permissions
chmod 644 "$LINUX_PROFILE/favicons.sqlite"
```

**Note:** Favicons are optional - they'll be re-downloaded automatically if not migrated.

---

### 11. Container Tabs (Multi-Account Containers)

**Files:** `containers.json`

**Description:** Container tab definitions (if you use Firefox Multi-Account Containers extension).

```bash
# Close Firefox
pkill firefox && sleep 5

LINUX_PROFILE=$(find ~/.mozilla/firefox/ -maxdepth 1 -type d -name "*.default*" | head -1)

# Copy containers
cp "$WINDOWS_PROFILE/containers.json" "$LINUX_PROFILE/" 2>/dev/null

# Set permissions
chmod 644 "$LINUX_PROFILE/containers.json"
```

**Verification:**
- If you use Multi-Account Containers extension
- Click the container icon in the toolbar
- Verify all containers appear with correct colors

---

## Troubleshooting

### Common Issues & Solutions

#### Issue: Firefox Won't Start After Migration

**Symptoms:**
- Firefox crashes immediately
- "Profile cannot be loaded" error
- Blank window appears

**Solutions:**

1. **Check profile paths in profiles.ini:**
```bash
cat ~/.mozilla/firefox/profiles.ini
```
Ensure the `Path=` line points to an existing profile directory.

2. **Reset profile to default:**
```bash
# Remove profiles.ini
rm ~/.mozilla/firefox/profiles.ini

# Let Firefox recreate it
firefox --ProfileManager
```
Then select your migrated profile or create new one.

3. **Check file permissions:**
```bash
LINUX_PROFILE=$(find ~/.mozilla/firefox/ -maxdepth 1 -type d -name "*.default*" | head -1)
chmod -R 755 "$LINUX_PROFILE"
find "$LINUX_PROFILE" -type f -exec chmod 644 {} \;
```

4. **Remove lock files:**
```bash
rm "$LINUX_PROFILE/.parentlock" 2>/dev/null
rm "$LINUX_PROFILE/lock" 2>/dev/null
```

5. **Start in Safe Mode:**
```bash
firefox -safe-mode
```

---

#### Issue: Bookmarks Not Appearing

**Symptoms:**
- Empty bookmarks menu
- Bookmarks toolbar is blank
- Library shows no bookmarks

**Solutions:**

1. **Check places.sqlite integrity:**
```bash
LINUX_PROFILE=$(find ~/.mozilla/firefox/ -maxdepth 1 -type d -name "*.default*" | head -1)
sqlite3 "$LINUX_PROFILE/places.sqlite" "PRAGMA integrity_check;"
```

2. **Remove Write-Ahead Log files:**
```bash
rm "$LINUX_PROFILE/places.sqlite-wal" 2>/dev/null
rm "$LINUX_PROFILE/places.sqlite-shm" 2>/dev/null
```

3. **Check if bookmarks are actually there:**
```bash
sqlite3 "$LINUX_PROFILE/places.sqlite" "SELECT COUNT(*) FROM moz_bookmarks;"
```
If this returns a number > 0, bookmarks exist but aren't displaying.

4. **Restore from backup:**
```bash
# Firefox keeps automatic backups
ls -la "$LINUX_PROFILE/bookmarkbackups/"

# Restore from backup: Bookmarks Menu → Show All Bookmarks → Import and Backup → Restore → Choose File
```

5. **Import from HTML:**
If you have an HTML bookmark export:
- Bookmarks Menu → Show All Bookmarks
- Import and Backup → Import Bookmarks from HTML
- Select your backup HTML file

---

#### Issue: Passwords Not Accessible

**Symptoms:**
- Passwords show but can't be viewed
- "Authentication required" appears repeatedly
- Auto-fill doesn't work

**Solutions:**

1. **Verify key4.db was copied:**
```bash
LINUX_PROFILE=$(find ~/.mozilla/firefox/ -maxdepth 1 -type d -name "*.default*" | head -1)
ls -la "$LINUX_PROFILE/key4.db"
```
Without this file, passwords cannot be decrypted.

2. **If master password was set on Windows:**
- You MUST remember and enter it on Linux
- Go to `about:logins` and enter master password when prompted

3. **Check file integrity:**
```bash
# logins.json should be valid JSON
python3 -c "import json; json.load(open('$LINUX_PROFILE/logins.json'))" && echo "Valid" || echo "Corrupted"
```

4. **Remove and re-copy password files:**
```bash
pkill firefox
rm "$LINUX_PROFILE/logins.json" "$LINUX_PROFILE/key4.db"
cp "$WINDOWS_PROFILE/logins.json" "$LINUX_PROFILE/"
cp "$WINDOWS_PROFILE/key4.db" "$LINUX_PROFILE/"
```

5. **Last resort - Manual password migration:**
- Use Firefox Password Exporter extension (if still on Windows)
- Export to CSV
- Import on Linux

---

#### Issue: Extensions Not Working

**Symptoms:**
- Extensions appear but don't function
- Extension icons missing/greyed out
- "Extension could not be loaded" errors

**Solutions:**

1. **Check extension compatibility:**
Some extensions may not be available on Linux or may have compatibility issues.

2. **Re-sync extensions:**
```bash
# Remove extension metadata and let Firefox re-download
rm "$LINUX_PROFILE/extensions.json"
rm "$LINUX_PROFILE/extension-settings.json"
# Keep the extensions/ folder
```

3. **Reinstall problematic extensions:**
- Go to `about:addons`
- Remove problematic extension
- Reinstall from Firefox Add-ons store

4. **Check extension data permissions:**
```bash
chmod -R 755 "$LINUX_PROFILE/extensions/"
chmod -R 755 "$LINUX_PROFILE/browser-extension-data/"
```

5. **Clear extension storage and reconfigure:**
```bash
rm -rf "$LINUX_PROFILE/storage/default/moz-extension*/"
```
Then reconfigure your extensions.

---

#### Issue: Session Not Restoring (Open Tabs Lost)

**Symptoms:**
- Firefox opens with no tabs or homepage
- Previous session not restored
- "Restore Previous Session" doesn't appear

**Solutions:**

1. **Check sessionstore files:**
```bash
LINUX_PROFILE=$(find ~/.mozilla/firefox/ -maxdepth 1 -type d -name "*.default*" | head -1)
ls -la "$LINUX_PROFILE/sessionstore*"
```

2. **Look for backup sessions:**
```bash
ls -la "$LINUX_PROFILE/sessionstore-backups/"
```
Copy the most recent one:
```bash
cp "$LINUX_PROFILE/sessionstore-backups/recovery.jsonlz4" "$LINUX_PROFILE/sessionstore.jsonlz4"
```

3. **Decompress and inspect session (advanced):**
You'll need a tool to decompress `.mozlz4` files:
```bash
# Install lz4 tool
sudo apt-get install liblz4-tool  # Ubuntu/Debian
# or
sudo dnf install lz4  # Fedora

# Note: Standard lz4 may not work with Firefox's format
# Consider using dejsonlz4 tool from GitHub
```

4. **Manually enable session restore:**
- Go to `about:preferences`
- Under "Startup", check "Restore previous session"

---

#### Issue: Database Corruption Errors

**Symptoms:**
- "The bookmarks and history system will not be functional"
- SQLite error messages
- Data missing or incomplete

**Solutions:**

1. **Check all database files:**
```bash
LINUX_PROFILE=$(find ~/.mozilla/firefox/ -maxdepth 1 -type d -name "*.default*" | head -1)

# Check each critical database
for db in places.sqlite cookies.sqlite formhistory.sqlite permissions.sqlite favicons.sqlite; do
  echo "Checking $db..."
  sqlite3 "$LINUX_PROFILE/$db" "PRAGMA integrity_check;" 2>/dev/null || echo "$db is corrupted"
done
```

2. **Repair corrupted database:**
```bash
# Example: Repair places.sqlite
cd "$LINUX_PROFILE"
sqlite3 places.sqlite ".dump" | sqlite3 places-repaired.sqlite
mv places.sqlite places.sqlite.corrupted
mv places-repaired.sqlite places.sqlite
```

3. **Remove WAL files and let Firefox rebuild:**
```bash
rm "$LINUX_PROFILE/"*.sqlite-wal
rm "$LINUX_PROFILE/"*.sqlite-shm
```

4. **Use Firefox Safe Mode to repair:**
```bash
firefox -safe-mode
```
Choose "Refresh Firefox" if prompted.

---

#### Issue: Firefox Using Wrong Profile

**Symptoms:**
- Different data appears than expected
- Multiple Firefox profiles exist
- Migration data not visible

**Solutions:**

1. **List all profiles:**
```bash
ls -la ~/.mozilla/firefox/
cat ~/.mozilla/firefox/profiles.ini
```

2. **Launch specific profile:**
```bash
firefox -P "ProfileName"
# or
firefox --ProfileManager
```

3. **Set migrated profile as default:**
Edit `~/.mozilla/firefox/profiles.ini`:
```ini
[Profile0]
Name=migrated
IsRelative=1
Path=abc123def.default-release
Default=1   ← Make sure this is set to 1
```

4. **Delete unused profiles:**
```bash
# Backup first!
rm -rf ~/.mozilla/firefox/[unused-profile-id].profile-name/
```
Then remove entries from `profiles.ini`.

---

## Security Considerations

### Data Encryption & Privacy

1. **Passwords:**
   - Encrypted with `key4.db`
   - Master password (if set) must be remembered
   - Consider using Firefox Sync or password manager

2. **Cookies & Sessions:**
   - Contain authentication tokens
   - May be invalidated by websites due to location/IP change
   - Clear if moving to significantly different location

3. **Certificates:**
   - Personal certificates migrate
   - Certificate exceptions migrate
   - Review security exceptions after migration

4. **Extension Data:**
   - May contain API keys or tokens
   - Review extension permissions post-migration
   - Re-authenticate extensions with sensitive data

### Best Practices

1. **Always backup before migration:**
```bash
mkdir -p ~/firefox-backup-$(date +%Y%m%d)
cp -r ~/.mozilla/firefox/ ~/firefox-backup-$(date +%Y%m%d)/
```

2. **Use Firefox Sync for future migrations:**
   - Navigate to `about:preferences#sync`
   - Create Firefox Account
   - Enable sync for desired data types
   - Much easier than manual file migration

3. **Verify database integrity:**
```bash
# Check all SQLite databases
LINUX_PROFILE=$(find ~/.mozilla/firefox/ -maxdepth 1 -type d -name "*.default*" | head -1)
for db in "$LINUX_PROFILE"/*.sqlite; do
  echo "Checking $(basename $db)..."
  sqlite3 "$db" "PRAGMA integrity_check;"
done
```

4. **Set proper permissions:**
```bash
# Profile directory should be readable only by user
chmod 700 ~/.mozilla/firefox/*.default*/
chmod 600 ~/.mozilla/firefox/*.default*/*.sqlite
chmod 600 ~/.mozilla/firefox/*.default*/key4.db
chmod 600 ~/.mozilla/firefox/*.default*/logins.json
```

5. **Review and update paths in prefs.js:**
```bash
# Check for Windows-specific paths
grep -i "C:\\\\" ~/.mozilla/firefox/*.default*/prefs.js
```

---

## Verification

### Post-Migration Checklist

After completing migration, verify each component:

#### 1. Bookmarks
- [ ] Press `Ctrl+Shift+O` to open Library
- [ ] Verify all bookmark folders appear
- [ ] Check bookmarks toolbar
- [ ] Test bookmark links
- [ ] Verify bookmark tags (if used)

#### 2. History
- [ ] Press `Ctrl+H` to open History
- [ ] Verify history appears
- [ ] Check history search functionality
- [ ] Verify download history

#### 3. Passwords
- [ ] Navigate to `about:logins`
- [ ] Verify password count
- [ ] Test viewing a password (may require master password)
- [ ] Test auto-fill on known website
- [ ] Verify password search works

#### 4. Form Data
- [ ] Visit a site with forms
- [ ] Start typing in a text field
- [ ] Verify autocomplete suggestions appear

#### 5. Extensions
- [ ] Navigate to `about:addons`
- [ ] Verify all extensions present
- [ ] Check extension settings/configurations
- [ ] Test extension functionality
- [ ] Re-authenticate if needed

#### 6. Settings
- [ ] Navigate to `about:preferences`
- [ ] Check General settings (homepage, startup)
- [ ] Verify Home settings
- [ ] Check Search engine settings
- [ ] Verify Privacy & Security settings
- [ ] Check site permissions

#### 7. Search Engines
- [ ] Click address bar
- [ ] Check search engine dropdown
- [ ] Verify custom search engines present
- [ ] Test search shortcuts

#### 8. Sessions (if migrated)
- [ ] Verify open tabs restored
- [ ] Check tab groups (if used)
- [ ] Verify window positions

#### 9. Containers (if used)
- [ ] Click container icon
- [ ] Verify all containers present
- [ ] Check container colors/icons
- [ ] Test container functionality

#### 10. Site Settings
- [ ] Visit previously visited sites
- [ ] Verify zoom levels preserved
- [ ] Check login status (if cookies migrated)
- [ ] Verify site permissions

### Quick Verification Script

```bash
#!/bin/bash
# firefox-migration-verify.sh - Quick verification script

PROFILE=$(find ~/.mozilla/firefox/ -maxdepth 1 -type d -name "*.default*" | head -1)

echo "=== Firefox Migration Verification ==="
echo
echo "Profile: $PROFILE"
echo

echo "=== Critical Files ==="
echo -n "places.sqlite (Bookmarks/History): "
[ -f "$PROFILE/places.sqlite" ] && echo "✓ Found" || echo "✗ Missing"

echo -n "logins.json (Passwords): "
[ -f "$PROFILE/logins.json" ] && echo "✓ Found" || echo "✗ Missing"

echo -n "key4.db (Password encryption): "
[ -f "$PROFILE/key4.db" ] && echo "✓ Found" || echo "✗ Missing"

echo -n "prefs.js (Settings): "
[ -f "$PROFILE/prefs.js" ] && echo "✓ Found" || echo "✗ Missing"

echo -n "extensions.json (Extensions): "
[ -f "$PROFILE/extensions.json" ] && echo "✓ Found" || echo "✗ Missing"

echo -n "formhistory.sqlite (Form data): "
[ -f "$PROFILE/formhistory.sqlite" ] && echo "✓ Found" || echo "✗ Missing"

echo -n "cookies.sqlite (Cookies): "
[ -f "$PROFILE/cookies.sqlite" ] && echo "✓ Found" || echo "✗ Missing"

echo

echo "=== Database Integrity ==="
for db in places.sqlite cookies.sqlite formhistory.sqlite permissions.sqlite; do
  if [ -f "$PROFILE/$db" ]; then
    echo -n "$db: "
    result=$(sqlite3 "$PROFILE/$db" "PRAGMA integrity_check;" 2>&1)
    if [ "$result" = "ok" ]; then
      echo "✓ OK"
    else
      echo "✗ Corrupted"
    fi
  fi
done

echo

echo "=== Data Counts ==="
if [ -f "$PROFILE/places.sqlite" ]; then
  bookmarks=$(sqlite3 "$PROFILE/places.sqlite" "SELECT COUNT(*) FROM moz_bookmarks WHERE type=1;" 2>/dev/null)
  echo "Bookmarks: $bookmarks"
  
  history=$(sqlite3 "$PROFILE/places.sqlite" "SELECT COUNT(*) FROM moz_historyvisits;" 2>/dev/null)
  echo "History entries: $history"
fi

if [ -f "$PROFILE/logins.json" ]; then
  passwords=$(python3 -c "import json; data=json.load(open('$PROFILE/logins.json')); print(len(data.get('logins', [])))" 2>/dev/null)
  echo "Saved passwords: $passwords"
fi

if [ -f "$PROFILE/cookies.sqlite" ]; then
  cookies=$(sqlite3 "$PROFILE/cookies.sqlite" "SELECT COUNT(*) FROM moz_cookies;" 2>/dev/null)
  echo "Cookies: $cookies"
fi

echo

echo "=== File Permissions ==="
ls -la "$PROFILE/places.sqlite" "$PROFILE/logins.json" "$PROFILE/key4.db" 2>/dev/null | awk '{print $1, $9}'

echo

echo "=== Manual Verification Required ==="
echo "1. Launch Firefox and check bookmarks (Ctrl+Shift+O)"
echo "2. Verify history (Ctrl+H)"
echo "3. Test password autofill"
echo "4. Check extensions (about:addons)"
echo "5. Verify settings (about:preferences)"
```

Save as `firefox-migration-verify.sh` and run:
```bash
chmod +x firefox-migration-verify.sh
./firefox-migration-verify.sh
```

---

## Quick Reference Commands

### Complete Profile Migration (Simplest Method)
```bash
# Close Firefox
pkill firefox && sleep 5

# Set paths (adjust to your setup)
WINDOWS_PROFILE="/path/to/backup/Users/WindowsUser/AppData/Roaming/Mozilla/Firefox/Profiles/abc123def.default-release"
LINUX_PROFILE=$(find ~/.mozilla/firefox/ -maxdepth 1 -type d -name "*.default*" | head -1)

# Backup current profile
mkdir -p ~/firefox-backup-$(date +%Y%m%d)
cp -r "$LINUX_PROFILE" ~/firefox-backup-$(date +%Y%m%d)/

# Copy entire Windows profile
rm -rf "$LINUX_PROFILE"/*
cp -r "$WINDOWS_PROFILE"/* "$LINUX_PROFILE"/

# Fix permissions
chmod -R 755 "$LINUX_PROFILE"
find "$LINUX_PROFILE" -type f -exec chmod 644 {} \;

# Launch Firefox
firefox
```

### Essential Data Only (Selective Migration)
```bash
# Close Firefox
pkill firefox && sleep 5

# Set paths
WINDOWS_PROFILE="/path/to/backup/Profiles/abc123.default-release"
LINUX_PROFILE=$(find ~/.mozilla/firefox/ -maxdepth 1 -type d -name "*.default*" | head -1)

# Copy critical files
cp "$WINDOWS_PROFILE/places.sqlite" "$LINUX_PROFILE/"
cp "$WINDOWS_PROFILE/logins.json" "$LINUX_PROFILE/"
cp "$WINDOWS_PROFILE/key4.db" "$LINUX_PROFILE/"
cp "$WINDOWS_PROFILE/prefs.js" "$LINUX_PROFILE/"
cp "$WINDOWS_PROFILE/formhistory.sqlite" "$LINUX_PROFILE/"
cp "$WINDOWS_PROFILE/extensions.json" "$LINUX_PROFILE/"
cp -r "$WINDOWS_PROFILE/extensions/" "$LINUX_PROFILE/"

# Fix permissions
chmod 644 "$LINUX_PROFILE"/*.sqlite "$LINUX_PROFILE"/*.json "$LINUX_PROFILE"/*.js
chmod -R 755 "$LINUX_PROFILE/extensions/"

# Launch Firefox
firefox
```

### Find Your Profile
```bash
# List all Firefox profiles
ls -la ~/.mozilla/firefox/

# Show profiles.ini content
cat ~/.mozilla/firefox/profiles.ini

# Find active profile directory
find ~/.mozilla/firefox/ -maxdepth 1 -type d -name "*.default*"
```

### Rollback to Backup
```bash
# If migration failed, restore from backup
pkill firefox
rm -rf ~/.mozilla/firefox/*.default*/
cp -r ~/firefox-backup-YYYYMMDD/* ~/.mozilla/firefox/
```

---

## Advanced Topics

### Migrating Multiple Profiles

If you had multiple Firefox profiles on Windows:

```bash
# List all Windows profiles
ls "$BACKUP_PATH/../Profiles/"

# Create new profile on Linux for each Windows profile
firefox --ProfileManager
# Create profiles manually via GUI

# Then copy each profile's data
PROFILE1_WIN="$BACKUP_PATH/../Profiles/abc123.default-release"
PROFILE1_LIN=~/.mozilla/firefox/xyz789.profile1

cp -r "$PROFILE1_WIN"/* "$PROFILE1_LIN"/
chmod -R 755 "$PROFILE1_LIN"
```

### Merging Profiles

If you want to merge bookmarks from multiple profiles:

```bash
# Option 1: Export/Import HTML bookmarks
# In Firefox with profile 1:
# Bookmarks → Show All Bookmarks → Import and Backup → Export Bookmarks to HTML

# In Firefox with profile 2:
# Bookmarks → Show All Bookmarks → Import and Backup → Import Bookmarks from HTML

# Option 2: Merge places.sqlite databases (advanced)
# This requires SQLite knowledge and careful query crafting
```

### Automating Migration

Create a migration script:

```bash
#!/bin/bash
# firefox-migrate.sh - Automated Firefox migration

set -e

BACKUP_PROFILE="$1"
PROFILE_NAME="${2:-default-release}"

if [ -z "$BACKUP_PROFILE" ]; then
    echo "Usage: $0 /path/to/windows/profile [linux-profile-name]"
    exit 1
fi

if [ ! -d "$BACKUP_PROFILE" ]; then
    echo "Error: Backup profile not found: $BACKUP_PROFILE"
    exit 1
fi

echo "=== Firefox Migration Tool ==="
echo "Source: $BACKUP_PROFILE"
echo "Target profile: $PROFILE_NAME"
echo

# Find or create target profile
LINUX_PROFILE=$(find ~/.mozilla/firefox/ -maxdepth 1 -type d -name "*.$PROFILE_NAME" | head -1)

if [ -z "$LINUX_PROFILE" ]; then
    echo "Creating new profile: $PROFILE_NAME"
    # Generate random profile ID
    PROFILE_ID=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 8 | head -n 1)
    LINUX_PROFILE=~/.mozilla/firefox/$PROFILE_ID.$PROFILE_NAME
    mkdir -p "$LINUX_PROFILE"
    
    # Add to profiles.ini
    echo "" >> ~/.mozilla/firefox/profiles.ini
    echo "[Profile$(date +%s)]" >> ~/.mozilla/firefox/profiles.ini
    echo "Name=$PROFILE_NAME" >> ~/.mozilla/firefox/profiles.ini
    echo "IsRelative=1" >> ~/.mozilla/firefox/profiles.ini
    echo "Path=$PROFILE_ID.$PROFILE_NAME" >> ~/.mozilla/firefox/profiles.ini
fi

echo "Target directory: $LINUX_PROFILE"
echo

# Close Firefox
echo "Closing Firefox..."
pkill firefox 2>/dev/null || true
sleep 3

# Backup current profile
BACKUP_DIR=~/firefox-backup-$(date +%Y%m%d-%H%M%S)
echo "Creating backup: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"
cp -r "$LINUX_PROFILE" "$BACKUP_DIR/"

# Migrate data
echo
echo "Migrating data..."

# Critical files
echo "  ✓ Bookmarks & History (places.sqlite)"
cp "$BACKUP_PROFILE/places.sqlite" "$LINUX_PROFILE/" 2>/dev/null || echo "    ✗ Not found"

echo "  ✓ Passwords (logins.json, key4.db)"
cp "$BACKUP_PROFILE/logins.json" "$LINUX_PROFILE/" 2>/dev/null || echo "    ✗ logins.json not found"
cp "$BACKUP_PROFILE/key4.db" "$LINUX_PROFILE/" 2>/dev/null || echo "    ✗ key4.db not found"

echo "  ✓ Form Data (formhistory.sqlite)"
cp "$BACKUP_PROFILE/formhistory.sqlite" "$LINUX_PROFILE/" 2>/dev/null || echo "    ✗ Not found"

echo "  ✓ Preferences (prefs.js)"
cp "$BACKUP_PROFILE/prefs.js" "$LINUX_PROFILE/" 2>/dev/null || echo "    ✗ Not found"

echo "  ✓ Cookies (cookies.sqlite)"
cp "$BACKUP_PROFILE/cookies.sqlite" "$LINUX_PROFILE/" 2>/dev/null || echo "    ✗ Not found"

echo "  ✓ Extensions"
cp "$BACKUP_PROFILE/extensions.json" "$LINUX_PROFILE/" 2>/dev/null || echo "    ✗ extensions.json not found"
cp -r "$BACKUP_PROFILE/extensions/" "$LINUX_PROFILE/" 2>/dev/null || echo "    ✗ extensions/ not found"
cp -r "$BACKUP_PROFILE/browser-extension-data/" "$LINUX_PROFILE/" 2>/dev/null || true

echo "  ✓ Additional data"
cp "$BACKUP_PROFILE/permissions.sqlite" "$LINUX_PROFILE/" 2>/dev/null || true
cp "$BACKUP_PROFILE/content-prefs.sqlite" "$LINUX_PROFILE/" 2>/dev/null || true
cp "$BACKUP_PROFILE/favicons.sqlite" "$LINUX_PROFILE/" 2>/dev/null || true
cp "$BACKUP_PROFILE/cert9.db" "$LINUX_PROFILE/" 2>/dev/null || true
cp "$BACKUP_PROFILE/search.json.mozlz4" "$LINUX_PROFILE/" 2>/dev/null || true

# Fix permissions
echo
echo "Setting permissions..."
chmod -R 755 "$LINUX_PROFILE"
find "$LINUX_PROFILE" -type f -exec chmod 644 {} \;

# Remove lock files
rm "$LINUX_PROFILE/.parentlock" 2>/dev/null || true
rm "$LINUX_PROFILE/lock" 2>/dev/null || true

echo
echo "=== Migration Complete! ==="
echo "Backup saved: $BACKUP_DIR"
echo
echo "Launch Firefox to verify:"
echo "  firefox -P \"$PROFILE_NAME\""
echo
```

Save as `firefox-migrate.sh` and run:
```bash
chmod +x firefox-migrate.sh
./firefox-migrate.sh /path/to/windows/profile
```

---

## Differences from Chromium/Brave Migration

For those familiar with Chromium-based browser migration:

| Aspect | Firefox | Chromium/Brave |
|--------|---------|----------------|
| **Profile Structure** | Single folder with random ID | `Default`, `Profile 1`, etc. |
| **Bookmarks** | SQLite database (`places.sqlite`) | JSON file (`Bookmarks`) |
| **History** | Same as bookmarks (`places.sqlite`) | Separate database (`History`) |
| **Passwords** | JSON + key file | SQLite database |
| **Preferences** | JavaScript file (`prefs.js`) | JSON file (`Preferences`) |
| **Session Storage** | Compressed JSON (`.mozlz4`) | JSON files |
| **Extension Format** | WebExtensions (XPI) | Chrome extensions (CRX) |
| **Complete Migration** | Copy entire profile folder | Copy individual files/folders |
| **Ease of Migration** | Easier (single folder) | More complex (multiple files) |

---

## Conclusion

You have successfully completed a comprehensive Firefox Browser migration from Windows to Linux. This guide covered:

- ✅ Complete understanding of Firefox's profile structure
- ✅ Simple complete profile migration method
- ✅ Detailed individual component migration
- ✅ Security considerations and best practices
- ✅ Troubleshooting common issues
- ✅ Verification procedures and scripts

### Next Steps

1. **Enable Firefox Sync** for future migrations:
   - Navigate to `about:preferences#sync`
   - Create or sign in to Firefox Account
   - Select what to sync
   - Never manually migrate again!

2. **Regular Backups:**
```bash
# Create monthly backup cron job
echo "0 0 1 * * cp -r ~/.mozilla/firefox ~/firefox-backup-\$(date +\%Y\%m)" | crontab -
```

3. **Profile Management:**
   - Use Firefox Profile Manager for multiple profiles: `firefox --ProfileManager`
   - Keep profiles organized
   - Consider separate profiles for work/personal

4. **Stay Updated:**
   - Keep Firefox updated
   - Monitor Mozilla support for migration improvements
   - Share your experience in the community

---

## Additional Resources

- **Mozilla Support:** https://support.mozilla.org/
- **Firefox Profile Documentation:** https://support.mozilla.org/kb/profiles-where-firefox-stores-user-data
- **Firefox Sync:** https://www.mozilla.org/firefox/sync/
- **Backup and Restore:** https://support.mozilla.org/kb/back-and-restore-information-firefox-profiles
- **Profile Manager:** https://support.mozilla.org/kb/profile-manager-create-remove-switch-firefox-profiles

---

**Document Version:** 1.0  
**Last Updated:** Initial creation  
**Status:** ✅ Ready for Use  
**Related:** See also Brave Browser Migration Guide for Chromium-based browser migration
