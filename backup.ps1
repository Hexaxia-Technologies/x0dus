<#
.SYNOPSIS
    Backup important Windows user data before migrating to Linux.

.DESCRIPTION
    This script copies the entire user profile directory (for example C:\Users\Alice)
    to a destination drive or folder by using Robocopy. You can optionally include
    every profile under C:\Users as well as the shared C:\Users\Public directory.
    Additional folders can be specified when invoking the script. The goal is to make
    sure a user's data is safely stored before reinstalling the operating system.

    INTERACTIVE MODE: Run the script without any parameters to launch the interactive
    wizard, which will guide you through selecting backup options including Quick Backup
    (minimal configuration) or Custom Backup (full control over all options).

.PARAMETER DestinationPath
    The folder where the backup will be stored. The folder will be created if necessary.

.PARAMETER AdditionalPaths
    Extra folders that should be included in the backup in addition to the defaults.
    Drive roots (for example C:\) are supported and will be stored with a friendly
    name so they remain separate in the destination.

.PARAMETER IncludeAllUsers
    Include every user profile folder under C:\Users (excluding system templates) in the
    backup. The current user will still be included unless SkipDefaultDirectories is set.

.PARAMETER IncludePublicProfile
    Include the shared C:\Users\Public directory in the backup. This option can be used
    on its own or together with IncludeAllUsers.

.PARAMETER SkipDefaultDirectories
    Do not include the user profile folder in the backup. This switch is preserved for
    backward compatibility.

.PARAMETER DryRun
    Execute Robocopy in list-only mode (/L). Useful to validate what will be copied.

.PARAMETER NoLog
    Disable writing a Robocopy log file to the destination directory.

.PARAMETER LogPath
    Custom path for the Robocopy log file. Overrides the default log location when
    logging is enabled.

.PARAMETER NetworkShare
    Optional network location that should be mounted before the backup begins.
    SMB (\\server\share) and NFS (server:/share) paths are supported.

.PARAMETER NetworkProtocol
    The protocol used for NetworkShare. Defaults to SMB when the share looks like
    a UNC path and NFS when it uses server:/export notation.

.PARAMETER NetworkDriveLetter
    Drive letter that should be used when mapping the network location. Defaults
    to Z.

.PARAMETER NetworkCredential
    Credential that should be used when connecting to an SMB share. Ignored for
    NFS mounts.

.PARAMETER NetworkPersistent
    Keep the mapped drive after the script exits. By default temporary mappings
    are removed once the backup completes.

.PARAMETER NetworkMountOptions
    Extra mount options passed to the underlying command. For SMB this maps to
    the -o parameter of mount.cifs. For NFS it maps to the -o parameter of
    mount.

.PARAMETER ForceCreateDestination
    Automatically create the destination directory without prompting. Useful for
    automation and scripting.

.PARAMETER RobocopyThreads
    Number of threads for multi-threaded copying (1-128). Defaults to 8. Controls
    the Robocopy /MT flag.

.PARAMETER RobocopyRetries
    Number of retry attempts after initial Robocopy failure (0-10). Defaults to 2.
    Uses exponential backoff between retries.

.PARAMETER RobocopyRetryDelaySeconds
    Base delay in seconds for exponential backoff between retries (1-600). Defaults
    to 5 seconds.

.PARAMETER NonInteractive
    Disable interactive mode when DestinationPath is not provided. Script will fail
    if required parameters are missing instead of prompting.

.PARAMETER AppDataMode
    Controls how AppData folders are handled during backup. Valid values:
    - Full (default): Include all AppData (Roaming, Local, LocalLow)
    - RoamingOnly: Include only AppData\Roaming (settings/saves), exclude Local and LocalLow (caches)
    - None: Exclude all AppData folders from the backup
    - EssentialFoldersOnly: Skip entire user profile, backup only essential folders (Documents, Desktop, Pictures, Videos, Music, Downloads, Favorites)

    Note: AppData\Roaming typically contains 1-10 GB of app settings and game saves.
    AppData\Local can contain 5-50+ GB of caches, temp files, and shader caches.

.EXAMPLE
    .\backup.ps1

    Launches interactive mode with a wizard to guide you through backup configuration.
    Choose between Quick Backup (simple) or Custom Backup (advanced options).

.EXAMPLE
    .\backup.ps1 -DestinationPath "E:\UserBackup"

    Copies the entire user profile to E:\UserBackup using Robocopy in non-interactive mode.

.EXAMPLE
    .\backup.ps1 -DestinationPath "E:\UserBackup" -AdditionalPaths "C:\"

    Backs up the default folders and the root of the C: drive with a friendly name.

.EXAMPLE
    .\backup.ps1 -DestinationPath "E:\UserBackup" -AppDataMode RoamingOnly

    Backs up the user profile but excludes AppData\Local and AppData\LocalLow, keeping
    only AppData\Roaming (settings and game saves). This significantly reduces backup size
    by skipping browser caches, temp files, and shader caches.

.EXAMPLE
    .\backup.ps1 -DestinationPath "E:\UserBackup" -AppDataMode EssentialFoldersOnly

    Backs up only essential user folders (Documents, Desktop, Pictures, Videos, Music,
    Downloads, Favorites) and skips all AppData. Best for minimal backups when starting
    fresh on Linux.

.EXAMPLE
    .\backup.ps1 -DestinationPath "E:\UserBackup" -AppDataMode Full -DryRun

    Previews a full backup including all AppData folders without actually copying files.

.NOTES
    Run this script from an elevated PowerShell session if you see access denied errors.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$DestinationPath,

    [string[]]$AdditionalPaths = @(),

    [switch]$SkipDefaultDirectories,

    [switch]$IncludeAllUsers,

    [switch]$IncludePublicProfile,

    [switch]$DryRun,

    [switch]$NoLog,

    [string]$LogPath,

    [string]$NetworkShare,

    [ValidateSet('SMB', 'NFS')]
    [string]$NetworkProtocol,

    [ValidatePattern('^[A-Za-z]$')]
    [string]$NetworkDriveLetter = 'Z',

    [System.Management.Automation.PSCredential]
    $NetworkCredential,

    [switch]$NetworkPersistent,

    [string]$NetworkMountOptions
    ,
    [switch]$ForceCreateDestination
    ,
    [ValidateRange(1,128)]
    [int]
    $RobocopyThreads = 8,

    [ValidateRange(0,10)]
    [int]
    $RobocopyRetries = 2,

    [ValidateRange(1,600)]
    [int]
    $RobocopyRetryDelaySeconds = 5,

    [switch]$NonInteractive,

    [ValidateSet('None', 'RoamingOnly', 'Full', 'EssentialFoldersOnly')]
    [string]$AppDataMode = 'Full'
)

# Script version
$scriptVersion = "1.0.0.RC1"

# Display banner
$banner = @"

                          =======
                       ==============
                    ======        =====
                 ======              =====
              ======                    =====
           ======                          ======
        =====                                 ======
      =====                                      =====
     ===   ++++++++++                  =========    ===
     ===     ++++++++++              ==========     ===
     ===       ++++++++++          ==========       ===
     ===        ++++++++++        ==========        ===
     ===          ++++++++++   ===========          ===
     ===            +++++++++ ==========            ===
     ===              +++++++ ========              ===
     ===                                            ===
     ===              ======= -------               ===
     ===             ======== ---------             ===
     ===           ==========  ----------           ===
     ===         ==========      ----------         ===
     ===       ==========          ----------       ===
     ===     ===========            ----------      ===
     ===    ==========                ----------    ===
     =====   ==                             ==    ====
       ======                                  ======
          ======                            ======
              =====                      =====
                 =====                =====
                    =====         ======
                       ======  ======
                          ========
                             ==

              x0dus Migration Toolkit v$scriptVersion
        Windows to Linux Migration - Data Backup and
                    Restore Utility

              Developed by Hexaxia Technologies
                    https://hexaxia.tech

                     Report issues at:
        https://github.com/Hexaxia-Technologies/x0dus/issues

================================================================

DISCLAIMER: This software is provided "as is" without warranty
of any kind. Use at your own risk. Hexaxia Technologies assumes
no liability for data loss or damages from use of this software.

================================================================

"@

Write-Host $banner -ForegroundColor DarkCyan

$ErrorActionPreference = 'Stop'

function Get-OsVersionInfo {
    try {
        return Get-CimInstance -ClassName Win32_OperatingSystem
    }
    catch {
        Write-Warning 'Unable to determine Windows version via CIM. Continuing without version check.'
        return $null
    }
}

function Test-IsSupportedWindows {
    param(
        [Parameter(Mandatory = $false)]
        $OsInfo
    )

    if (-not $OsInfo) {
        return $true
    }

    $majorVersion = $OsInfo.Version.Split('.')[0]
    if ($majorVersion -ne '10') {
        return $false
    }

    # Windows 10 and 11 share the 10.0 major version. Warn for very old builds.
    $buildNumber = [int]$OsInfo.BuildNumber
    if ($buildNumber -lt 10240) {
        Write-Warning 'Detected a very old Windows build. Robocopy behaviour may differ.'
    }

    return $true
}

function Resolve-NetworkProtocol {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Share,

        [Parameter(Mandatory = $false)]
        [string]$RequestedProtocol
    )

    if ($RequestedProtocol) {
        return $RequestedProtocol.ToUpperInvariant()
    }

    if ($Share -match '^[\\/]{2}') {
        return 'SMB'
    }

    if ($Share -match '^[^:]+:.+') {
        return 'NFS'
    }

    return 'SMB'
}

function Connect-NetworkDestination {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Share,

        [Parameter(Mandatory = $false)]
        [string]$Protocol,

        [Parameter(Mandatory = $true)]
        [string]$DriveLetter,

        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]
        $Credential,

        [string]$MountOptions,

        [switch]$Persistent
    )

    $resolvedProtocol = Resolve-NetworkProtocol -Share $Share -RequestedProtocol $Protocol
    $upperLetter = $DriveLetter.ToUpperInvariant()
    if ($upperLetter.Length -ne 1 -or ($upperLetter -notmatch '^[A-Z]$')) {
        throw "Drive letter '$DriveLetter' is invalid."
    }

    if ($resolvedProtocol -eq 'SMB') {
        $normalized = $Share -replace '/', '\\'
        if ($normalized -notmatch '^[\\]{2}.+\\.+') {
            throw "SMB shares must use the \\server\\share format."
        }

        $existing = Get-PSDrive -Name $upperLetter -ErrorAction SilentlyContinue
        if ($existing) {
            if ($existing.Root.TrimEnd('\') -ne $normalized.TrimEnd('\')) {
                throw "Drive letter $upperLetter is already mapped to $($existing.Root)."
            }

            Write-Verbose "Reusing existing mapping on drive $upperLetter for $normalized."
            return [PSCustomObject]@{
                Protocol = 'SMB'
                DriveLetter = $upperLetter
                ShouldCleanup = $false
                AccessPath = ("{0}:" -f $upperLetter)
            }
        }

        $parameters = @{
            Name = $upperLetter
            PSProvider = 'FileSystem'
            Root = $normalized
            ErrorAction = 'Stop'
        }

        if ($Persistent.IsPresent) {
            $parameters['Persist'] = $true
        }

        if ($Credential) {
            $parameters['Credential'] = $Credential
        }

        try {
            New-PSDrive @parameters | Out-Null
        }
        catch {
            throw "Unable to map SMB share ${normalized}: $($_.Exception.Message)"
        }

    Write-Host "Mapped ${normalized} to drive ${upperLetter}:" -ForegroundColor Cyan
        return [PSCustomObject]@{
            Protocol = 'SMB'
            DriveLetter = $upperLetter
            ShouldCleanup = -not $Persistent.IsPresent
            AccessPath = ("{0}:" -f $upperLetter)
        }
    }

    if ($resolvedProtocol -eq 'NFS') {
        $mountCommand = Get-Command -Name mount -ErrorAction SilentlyContinue
        if (-not $mountCommand) {
            throw 'The mount command was not found. Install the Client for NFS feature to mount NFS shares.'
        }

        $target = ("{0}:" -f $upperLetter)
        $existing = & $mountCommand.Source | Where-Object { $_ -match "^$([regex]::Escape($target))" }
        if ($existing) {
            if ($existing -notmatch [regex]::Escape($Share)) {
                throw "Drive letter $upperLetter is already in use: $existing"
            }

            Write-Verbose "Reusing existing NFS mount for $Share on $target."
            return [PSCustomObject]@{
                Protocol = 'NFS'
                DriveLetter = $upperLetter
                ShouldCleanup = $false
                AccessPath = $target
            }
        }

        $arguments = @()
        if ($MountOptions) {
            $arguments += '-o'
            $arguments += $MountOptions
        }
        $arguments += $Share
        $arguments += $target

        try {
            & $mountCommand.Source @arguments
        }
        catch {
            throw "Unable to mount NFS share ${Share}: $($_.Exception.Message)"
        }

        Write-Host "Mounted NFS export $Share to $target" -ForegroundColor Cyan
        return [PSCustomObject]@{
            Protocol = 'NFS'
            DriveLetter = $upperLetter
            ShouldCleanup = -not $Persistent.IsPresent
            AccessPath = $target
        }
    }

    throw "Unsupported network protocol: $resolvedProtocol"
}

function Disconnect-NetworkDestination {
    param(
        [Parameter(Mandatory = $false)]
        $Context
    )

    if (-not $Context) {
        return
    }

    if (-not $Context.ShouldCleanup) {
        return
    }

    if ($Context.Protocol -eq 'SMB') {
        try {
            Remove-PSDrive -Name $Context.DriveLetter -Force -ErrorAction Stop
            Write-Verbose "Removed temporary SMB mapping on $($Context.DriveLetter):"
        }
        catch {
            Write-Warning "Failed to remove SMB mapping on $($Context.DriveLetter): $($_.Exception.Message)"
        }
        return
    }

    if ($Context.Protocol -eq 'NFS') {
        $mountCommand = Get-Command -Name mount -ErrorAction SilentlyContinue
        if (-not $mountCommand) {
            Write-Warning 'Unable to locate mount command to unmount NFS share. Unmount manually.'
            return
        }

        try {
            & $mountCommand.Source '-u' ("{0}:" -f $Context.DriveLetter)
            Write-Verbose "Unmounted NFS share on $($Context.DriveLetter):"
        }
        catch {
            Write-Warning "Failed to unmount NFS share on $($Context.DriveLetter): $($_.Exception.Message)"
        }
    }
}

function Resolve-DestinationPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        $NetworkContext
    )

    if ($NetworkContext -and -not [System.IO.Path]::IsPathRooted($Path)) {
        return Join-Path $NetworkContext.AccessPath $Path
    }

    return $Path
}

function Initialize-Destination {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    if (-not (Test-Path -LiteralPath $fullPath)) {
        Write-Verbose "Creating destination directory: $fullPath"
        New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
    }

    return $fullPath
}

function Confirm-DestinationInteractive {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    try {
        if (Test-Path -LiteralPath $Path) {
            Write-Host "Destination path exists: $Path" -ForegroundColor Cyan
            return $true
        }

        if ($Force.IsPresent -or $ForceCreateDestination.IsPresent) {
            try {
                Initialize-Destination -Path $Path | Out-Null
                Write-Host "Created destination path: $Path" -ForegroundColor Green
                return $true
            }
            catch {
                Write-Warning "Failed to create destination path '${Path}': $($_.Exception.Message)"
                return $false
            }
        }

        # Prompt the user to create the destination
    $response = Read-Host "Destination path '$Path' does not exist. Create it? (Y/N)"
        if ($response -match '^[Yy]') {
            try {
                Initialize-Destination -Path $Path | Out-Null
                Write-Host "Created destination path: $Path" -ForegroundColor Green
                return $true
            }
            catch {
                Write-Warning "Failed to create destination path '${Path}': $($_.Exception.Message)"
                return $false
            }
        }

        throw "Destination path was not created: $Path"
    }
    catch {
        throw
    }
}

function Get-ScriptLogFilePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Destination
    )

    if ($NoLog.IsPresent) {
        return $null
    }

    $logDirectory = Join-Path $Destination 'logs'
    if (-not (Test-Path -LiteralPath $logDirectory)) {
        try {
            New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
        }
        catch {
            Write-Warning "Unable to create log directory '$logDirectory': $($_.Exception.Message)"
            return $null
        }
    }

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    return Join-Path $logDirectory "script-$timestamp.log"
}

function Start-ScriptLogging {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        Start-Transcript -Path $Path -Append -ErrorAction Stop | Out-Null
        $global:ScriptLogPath = $Path
        $global:ScriptTranscriptStarted = $true
        Write-Host "Script logging started to $Path" -ForegroundColor Yellow
    }
    catch {
        Write-Warning "Start-Transcript failed: $($_.Exception.Message). Continuing without transcript logging."
        $global:ScriptLogPath = $null
        $global:ScriptTranscriptStarted = $false
    }
}

function Stop-ScriptLogging {
    try {
        if ($global:ScriptTranscriptStarted) {
            Stop-Transcript | Out-Null
            Write-Host "Script logging stopped. Log: $($global:ScriptLogPath)" -ForegroundColor Yellow
            $global:ScriptTranscriptStarted = $false
        }
    }
    catch {
        Write-Warning "Failed to stop transcript: $($_.Exception.Message)"
    }
}

function Show-Menu {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,

        [Parameter(Mandatory = $true)]
        [string[]]$Options,

        [int]$DefaultChoice = 1
    )

    Write-Host ""
    Write-Host "---------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor Yellow
    Write-Host "---------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host ""

    for ($i = 0; $i -lt $Options.Count; $i++) {
        Write-Host "  [$($i + 1)] $($Options[$i])" -ForegroundColor White
    }
    Write-Host ""

    do {
        $choice = Read-Host "Enter your choice (1-$($Options.Count)) [default: $DefaultChoice]"
        if ([string]::IsNullOrWhiteSpace($choice)) {
            $choice = $DefaultChoice
            break
        }
        if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $Options.Count) {
            break
        }
        Write-Host "Invalid choice. Please enter a number between 1 and $($Options.Count)." -ForegroundColor Red
    } while ($true)

    return [int]$choice
}

function Get-DestinationPathInteractive {
    param(
        [bool]$AllowNetworkShare = $true
    )

    Write-Host ""
    Write-Host "---------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host " Destination Selection" -ForegroundColor Yellow
    Write-Host "---------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host ""

    if ($AllowNetworkShare) {
        Write-Host "Choose destination type:" -ForegroundColor White
        Write-Host "  [1] Local path (e.g., E:\UserBackup)" -ForegroundColor White
        Write-Host "  [2] Network share (SMB/NFS)" -ForegroundColor White
        Write-Host ""

        $choice = Read-Host "Enter your choice (1-2) [default: 1]"
        if ([string]::IsNullOrWhiteSpace($choice)) {
            $choice = "1"
        }

        if ($choice -eq "2") {
            return Get-NetworkShareInteractive
        }
    }

    do {
        Write-Host ""
        $path = Read-Host "Enter the destination path (e.g., E:\UserBackup)"
        if (-not [string]::IsNullOrWhiteSpace($path)) {
            return @{
                DestinationPath = $path
                NetworkShare = $null
                NetworkProtocol = $null
                NetworkCredential = $null
                NetworkDriveLetter = 'Z'
            }
        }
        Write-Host "Path cannot be empty. Please try again." -ForegroundColor Red
    } while ($true)
}

function Get-NetworkShareInteractive {
    Write-Host ""
    Write-Host "---------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host " Network Share Configuration" -ForegroundColor Yellow
    Write-Host "---------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Enter network share path:" -ForegroundColor White
    Write-Host "  SMB format: \\server\share" -ForegroundColor Gray
    Write-Host "  NFS format: server:/export" -ForegroundColor Gray
    Write-Host ""

    do {
        $share = Read-Host "Network share path"
        if (-not [string]::IsNullOrWhiteSpace($share)) {
            break
        }
        Write-Host "Share path cannot be empty." -ForegroundColor Red
    } while ($true)

    $protocol = Resolve-NetworkProtocol -Share $share -RequestedProtocol $null
    Write-Host "Detected protocol: $protocol" -ForegroundColor Cyan

    $credential = $null
    if ($protocol -eq 'SMB') {
        Write-Host ""
        $needsCreds = Read-Host "Does this share require credentials? (Y/N) [default: N]"
        if ($needsCreds -match '^[Yy]') {
            $credential = Get-Credential -Message "Enter credentials for $share"
        }
    }

    Write-Host ""
    $destPath = Read-Host "Enter destination folder name on the share (e.g., Workstation-Backup)"

    return @{
        DestinationPath = $destPath
        NetworkShare = $share
        NetworkProtocol = $protocol
        NetworkCredential = $credential
        NetworkDriveLetter = 'Z'
    }
}

function Get-UserProfileSelectionInteractive {
    Write-Host ""
    Write-Host "---------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host " User Profile Selection" -ForegroundColor Yellow
    Write-Host "---------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host ""

    $currentUser = [Environment]::UserName
    Write-Host "Current user: $currentUser" -ForegroundColor Cyan
    Write-Host ""

    $options = @(
        "Current user only ($currentUser)",
        "All user profiles",
        "All user profiles + Public folder",
        "Skip user profiles (backup only additional folders)"
    )

    $choice = Show-Menu -Title "Select User Profiles to Backup" -Options $options -DefaultChoice 1

    return @{
        IncludeAllUsers = ($choice -eq 2 -or $choice -eq 3)
        IncludePublicProfile = ($choice -eq 3)
        SkipDefaultDirectories = ($choice -eq 4)
    }
}

function Get-AdditionalPathsInteractive {
    Write-Host ""
    Write-Host "---------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host " Additional Folders" -ForegroundColor Yellow
    Write-Host "---------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Enter additional folders to backup (one per line)." -ForegroundColor White
    Write-Host "Examples: C:\Projects, D:\VMs, C:\ (entire drive)" -ForegroundColor Gray
    Write-Host "Press Enter on empty line when done." -ForegroundColor White
    Write-Host ""

    $paths = @()
    $index = 1
    do {
        $path = Read-Host "Additional folder $index (or press Enter to finish)"
        if ([string]::IsNullOrWhiteSpace($path)) {
            break
        }
        $paths += $path
        $index++
    } while ($true)

    return $paths
}

function Get-AppDataModeInteractive {
    Write-Host ""
    Write-Host "---------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host " AppData Handling" -ForegroundColor Yellow
    Write-Host "---------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "AppData contains application settings, caches, and temporary files." -ForegroundColor White
    Write-Host ""

    $options = @(
        "Skip all AppData (smallest backup, no app settings)",
        "Include AppData\Roaming only (settings & saves, skip caches)",
        "Include all AppData (largest backup, everything preserved)"
    )

    $choice = Show-Menu -Title "Select AppData Handling" -Options $options -DefaultChoice 2

    switch ($choice) {
        1 { return 'None' }
        2 { return 'RoamingOnly' }
        3 { return 'Full' }
    }

    return 'Full'  # Default fallback
}

function Get-RobocopyOptionsInteractive {
    Write-Host ""
    Write-Host "---------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host " Robocopy Tuning Options" -ForegroundColor Yellow
    Write-Host "---------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Configure advanced Robocopy options? (Y/N) [default: N]" -ForegroundColor White
    $configure = Read-Host

    if ($configure -notmatch '^[Yy]') {
        return @{
            Threads = 8
            Retries = 2
            RetryDelaySeconds = 5
        }
    }

    Write-Host ""
    Write-Host "Number of threads for multi-threaded copying (1-128) [default: 8]" -ForegroundColor White
    $threads = Read-Host
    if ([string]::IsNullOrWhiteSpace($threads)) {
        $threads = 8
    }

    Write-Host "Number of retry attempts (0-10) [default: 2]" -ForegroundColor White
    $retries = Read-Host
    if ([string]::IsNullOrWhiteSpace($retries)) {
        $retries = 2
    }

    Write-Host "Retry delay in seconds (1-600) [default: 5]" -ForegroundColor White
    $delay = Read-Host
    if ([string]::IsNullOrWhiteSpace($delay)) {
        $delay = 5
    }

    return @{
        Threads = [int]$threads
        Retries = [int]$retries
        RetryDelaySeconds = [int]$delay
    }
}

function Get-InteractiveConfiguration {
    param(
        [bool]$QuickMode = $false,
        [int]$ModeChoice = 2
    )

    Write-Host ""
    Write-Host "+-------------------------------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host "|                         Interactive Backup Configuration                      |" -ForegroundColor Cyan
    Write-Host "+-------------------------------------------------------------------------------+" -ForegroundColor Cyan

    $config = @{}

    # Destination
    $destConfig = Get-DestinationPathInteractive -AllowNetworkShare:(-not $QuickMode)
    $config += $destConfig

    # User profiles - ask for all modes
    $profileConfig = Get-UserProfileSelectionInteractive
    $config += $profileConfig

    # Additional paths
    if (-not $QuickMode) {
        Write-Host ""
        $addMore = Read-Host "Do you want to add additional folders? (Y/N) [default: N]"
        if ($addMore -match '^[Yy]') {
            $config.AdditionalPaths = Get-AdditionalPathsInteractive
        }
        else {
            $config.AdditionalPaths = @()
        }

        # AppData mode selection (only for Custom mode = ModeChoice 4)
        if ($ModeChoice -eq 4) {
            $config.AppDataMode = Get-AppDataModeInteractive
        }

        # Robocopy options
        $robocopyConfig = Get-RobocopyOptionsInteractive
        $config += $robocopyConfig
    }
    else {
        $config.AdditionalPaths = @()
        $config.Threads = 8
        $config.Retries = 2
        $config.RetryDelaySeconds = 5
        $config.AppDataMode = $null  # Will be set by mode choice
    }

    # Confirmation
    Write-Host ""
    Write-Host "---------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host " Configuration Summary" -ForegroundColor Yellow
    Write-Host "---------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host ""

    if ($config.NetworkShare) {
        Write-Host "Network Share: $($config.NetworkShare)" -ForegroundColor White
        Write-Host "Protocol: $($config.NetworkProtocol)" -ForegroundColor White
    }
    Write-Host "Destination: $($config.DestinationPath)" -ForegroundColor White

    if ($config.SkipDefaultDirectories) {
        Write-Host "User Profiles: None (skip user profiles)" -ForegroundColor White
    }
    elseif ($config.IncludeAllUsers -and $config.IncludePublicProfile) {
        Write-Host "User Profiles: All users + Public folder" -ForegroundColor White
    }
    elseif ($config.IncludeAllUsers) {
        Write-Host "User Profiles: All users" -ForegroundColor White
    }
    else {
        Write-Host "User Profiles: Current user only" -ForegroundColor White
    }

    if ($config.AdditionalPaths -and $config.AdditionalPaths.Count -gt 0) {
        Write-Host "Additional Folders: $($config.AdditionalPaths.Count)" -ForegroundColor White
        foreach ($path in $config.AdditionalPaths) {
            Write-Host "  - $path" -ForegroundColor Gray
        }
    }

    # Show AppData handling mode
    $appDataModeToShow = if ($config.AppDataMode) { $config.AppDataMode } else { "Full (default)" }
    if ($ModeChoice -eq 1) {
        Write-Host "AppData Handling: Essential Folders Only (no AppData)" -ForegroundColor White
    }
    elseif ($ModeChoice -eq 2) {
        Write-Host "AppData Handling: Roaming only (settings/saves)" -ForegroundColor White
    }
    elseif ($ModeChoice -eq 3) {
        Write-Host "AppData Handling: Full (all AppData included)" -ForegroundColor White
    }
    elseif ($config.AppDataMode) {
        Write-Host "AppData Handling: $($config.AppDataMode)" -ForegroundColor White
    }

    Write-Host ""
    Write-Host "---------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host ""

    $confirm = Read-Host "Continue with this configuration? (Y/N) [default: Y]"
    if ($confirm -match '^[Nn]') {
        throw "Backup cancelled by user."
    }

    # Dry run option
    Write-Host ""
    Write-Host "Dry Run Mode allows you to preview what will be backed up without" -ForegroundColor Yellow
    Write-Host "actually copying any files. This is useful to verify the configuration." -ForegroundColor Yellow
    Write-Host ""
    $dryRunChoice = Read-Host "Do you want to run in DRY RUN mode (preview only)? (Y/N) [default: N]"
    if ($dryRunChoice -match '^[Yy]') {
        $config.DryRun = $true
        Write-Host ""
        Write-Host "DRY RUN MODE ENABLED - No files will be copied!" -ForegroundColor Cyan
        Write-Host ""
    }
    else {
        $config.DryRun = $false
    }

    return $config
}

function Get-UserProfileBackupPath {
    $userProfile = [Environment]::GetFolderPath('UserProfile')
    $name = Split-Path -Path $userProfile -Leaf
    return @{ Name = $name; Path = $userProfile }
}

function Get-EssentialFoldersBackupPaths {
    <#
    .SYNOPSIS
    Returns only essential user folders (Documents, Desktop, Pictures, etc.) without AppData.
    #>
    $userProfile = [Environment]::GetFolderPath('UserProfile')
    $userName = Split-Path -Path $userProfile -Leaf

    $essentialFolders = @(
        @{ SpecialFolder = 'Desktop'; FallbackName = 'Desktop' },
        @{ SpecialFolder = 'MyDocuments'; FallbackName = 'Documents' },
        @{ SpecialFolder = 'MyPictures'; FallbackName = 'Pictures' },
        @{ SpecialFolder = 'MyVideos'; FallbackName = 'Videos' },
        @{ SpecialFolder = 'MyMusic'; FallbackName = 'Music' },
        @{ SpecialFolder = 'Downloads'; FallbackName = 'Downloads' },
        @{ SpecialFolder = 'Favorites'; FallbackName = 'Favorites' }
    )

    $items = @()
    foreach ($folder in $essentialFolders) {
        try {
            $folderPath = [Environment]::GetFolderPath($folder.SpecialFolder)
            if ([string]::IsNullOrWhiteSpace($folderPath)) {
                # Try manual path construction
                $folderPath = Join-Path $userProfile $folder.FallbackName
            }

            if (Test-Path -LiteralPath $folderPath) {
                $folderName = Split-Path -Path $folderPath -Leaf
                # Use format: Username-FolderName for clarity in backup
                $items += @{ Name = "$userName-$folderName"; Path = $folderPath }
                Write-Verbose "Added essential folder: $folderPath"
            }
            else {
                Write-Verbose "Skipping non-existent essential folder: $folderPath"
            }
        }
        catch {
            Write-Verbose "Unable to process essential folder $($folder.SpecialFolder): $($_.Exception.Message)"
        }
    }

    return $items
}

function Format-ByteSize {
    param(
        [Parameter(Mandatory = $true)]
        [double]$Bytes
    )

    if ($Bytes -lt 0) {
        $Bytes = 0
    }

    $units = @('B', 'KB', 'MB', 'GB', 'TB', 'PB')
    $index = 0
    while ($Bytes -ge 1024 -and $index -lt ($units.Count - 1)) {
        $Bytes = $Bytes / 1024
        $index++
    }

    return "{0:N2} {1}" -f $Bytes, $units[$index]
}

function Get-PublicProfileBackupPath {
    $systemDrive = [Environment]::GetEnvironmentVariable('SystemDrive')
    if ([string]::IsNullOrWhiteSpace($systemDrive)) {
        $systemDrive = 'C:'
    }

    $publicPath = Join-Path $systemDrive 'Users\Public'
    return @{ Name = 'Public'; Path = $publicPath }
}

function Get-AllUserProfileBackupPaths {
    param(
        [switch]$IncludePublic
    )

    $systemDrive = [Environment]::GetEnvironmentVariable('SystemDrive')
    if ([string]::IsNullOrWhiteSpace($systemDrive)) {
        $systemDrive = 'C:'
    }

    $usersRoot = Join-Path $systemDrive 'Users'
    if (-not (Test-Path -LiteralPath $usersRoot)) {
        Write-Warning "Unable to locate the Users directory at $usersRoot."
        return @()
    }

    try {
        $directories = Get-ChildItem -Path $usersRoot -Directory -ErrorAction Stop
    }
        catch {
        Write-Warning "Unable to enumerate user profiles in ${usersRoot}: $($_.Exception.Message)"
        return @()
    }

    $excluded = @('Default', 'Default User', 'All Users', 'DefaultAppPool', 'Public', 'WDAGUtilityAccount')
    $items = @()
    foreach ($directory in $directories) {
        if ($directory.Name -eq 'Public') {
            if ($IncludePublic.IsPresent) {
                $items += @{ Name = $directory.Name; Path = $directory.FullName }
            }
            continue
        }

        if ($excluded -contains $directory.Name) {
            continue
        }

        $items += @{ Name = $directory.Name; Path = $directory.FullName }
    }

    return $items
}

function Get-BackupItemName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $leaf = Split-Path -Path $Path -Leaf
    if (-not [string]::IsNullOrWhiteSpace($leaf)) {
        return $leaf
    }

    $root = [System.IO.Path]::GetPathRoot($Path)
    if (-not [string]::IsNullOrWhiteSpace($root)) {
        $sanitized = ($root.TrimEnd([System.IO.Path]::DirectorySeparatorChar)) -replace '[:\\]', ''
        if (-not [string]::IsNullOrWhiteSpace($sanitized)) {
            return "Drive-$sanitized"
        }
    }

    return 'BackupItem'
}

function Resolve-BackupItems {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Destination,

        [Parameter(Mandatory = $false)]
        [bool]$IncludeCurrentUser,

        [Parameter(Mandatory = $false)]
        [bool]$IncludeAllUsers,

        [Parameter(Mandatory = $false)]
        [bool]$IncludePublicProfile,

        [Parameter(Mandatory = $false)]
        [string[]]$ExtraPaths,

        [ValidateSet('None', 'RoamingOnly', 'Full', 'EssentialFoldersOnly')]
        [string]$AppDataMode = 'Full'
    )

    $items = @()
    if ($IncludeCurrentUser) {
        if ($AppDataMode -eq 'EssentialFoldersOnly') {
            # Only backup essential folders (Documents, Desktop, etc.) without AppData
            $items += Get-EssentialFoldersBackupPaths
            Write-Verbose "Using EssentialFoldersOnly mode - backing up individual folders"
        }
        else {
            # Backup entire user profile (AppData filtering happens in Invoke-RobocopyBackup)
            $items += Get-UserProfileBackupPath
        }
    }

    if ($IncludeAllUsers) {
        $items += Get-AllUserProfileBackupPaths -IncludePublic:$IncludePublicProfile
    }
    elseif ($IncludePublicProfile) {
        $items += Get-PublicProfileBackupPath
    }

    foreach ($path in $ExtraPaths) {
        if (-not [string]::IsNullOrWhiteSpace($path)) {
            try {
                $normalized = [System.IO.Path]::GetFullPath($path)
            }
            catch {
                Write-Warning "Skipping invalid path: $path"
                continue
            }

            $name = Get-BackupItemName -Path $normalized
            $items += @{ Name = $name; Path = $normalized }
        }
    }

    $existing = @()
    $addedSources = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($item in $items) {
        if (Test-Path -LiteralPath $item.Path) {
            if ($addedSources.Add($item.Path)) {
                $existing += @{ Name = $item.Name; Source = $item.Path; Target = Join-Path $Destination $item.Name }
            }
        }
        else {
            Write-Warning "Skipping missing path: $($item.Path)"
        }
    }

    return $existing
}

function Get-PathSizeInfo {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        $item = Get-Item -LiteralPath $Path -ErrorAction Stop
    }
    catch {
        throw "Unable to access '$Path': $($_.Exception.Message)"
    }

    if (-not $item.PSIsContainer) {
        return [PSCustomObject]@{
            Path = $Path
            SizeBytes = [int64]$item.Length
            HadErrors = $false
            ErrorMessages = @()
        }
    }

    $errors = @()
    $measurement = Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction SilentlyContinue -ErrorVariable +errors |
        Measure-Object -Property Length -Sum

    $size = 0
    if ($measurement -and $measurement.Sum) {
        $size = [int64]$measurement.Sum
    }

    $messages = @()
    foreach ($err in $errors) {
        if ($err -and $err.Exception -and -not [string]::IsNullOrWhiteSpace($err.Exception.Message)) {
            $messages += $err.Exception.Message
        }
    }

    if ($messages.Count -gt 0) {
        $messages = $messages | Sort-Object -Unique
    }

    return [PSCustomObject]@{
        Path = $Path
        SizeBytes = $size
        HadErrors = $messages.Count -gt 0
        ErrorMessages = $messages
    }
}

function Get-BackupSizeEstimate {
    param(
        [Parameter(Mandatory = $true)]
        $Items
    )

    $total = [int64]0
    $hadErrors = $false
    $details = @()

    foreach ($item in $Items) {
        $info = Get-PathSizeInfo -Path $item.Source
        $total += $info.SizeBytes
        if ($info.HadErrors) {
            $hadErrors = $true
        }
        $details += $info
    }

    return [PSCustomObject]@{
        TotalSizeBytes = $total
        HadErrors = $hadErrors
        Details = $details
    }
}

function Get-DestinationFreeSpace {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        $destinationInfo = Get-Item -LiteralPath $Path -ErrorAction Stop
    }
    catch {
        throw "Unable to access destination '$Path': $($_.Exception.Message)"
    }

    $psDrive = $destinationInfo.PSDrive
    if ($psDrive -and $psDrive.Free -ge 0) {
        return [int64]$psDrive.Free
    }

    try {
        $root = $destinationInfo.Root.FullName
        $driveInfo = New-Object System.IO.DriveInfo($root)
        return [int64]$driveInfo.AvailableFreeSpace
    }
    catch {
        throw "Unable to determine available space for '$Path': $($_.Exception.Message)"
    }
}

function Test-IsDestinationWithinSource {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source,

        [Parameter(Mandatory = $true)]
        [string]$Destination
    )

    try {
        $resolvedSource = ([System.IO.Path]::GetFullPath($Source)).TrimEnd([System.IO.Path]::DirectorySeparatorChar)
        $resolvedDestination = ([System.IO.Path]::GetFullPath($Destination)).TrimEnd([System.IO.Path]::DirectorySeparatorChar)
    }
    catch {
        return $false
    }

    if ($resolvedDestination.Equals($resolvedSource, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }

    if ($resolvedDestination.Length -le $resolvedSource.Length) {
        return $false
    }

    return $resolvedDestination.StartsWith($resolvedSource + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)
}

function Export-InstalledSoftwareInventory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DestinationDirectory
    )

    $inventoryPath = Join-Path $DestinationDirectory 'installed-software.csv'
    $registryPaths = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    $entries = @()
    foreach ($registryPath in $registryPaths) {
        try {
            $entries += Get-ItemProperty -Path $registryPath -ErrorAction Stop | Where-Object {
                -not [string]::IsNullOrWhiteSpace($_.DisplayName)
            } | Select-Object @{ Name = 'DisplayName'; Expression = { $_.DisplayName } },
                @{ Name = 'DisplayVersion'; Expression = { $_.DisplayVersion } },
                @{ Name = 'Publisher'; Expression = { $_.Publisher } },
                @{ Name = 'InstallDate'; Expression = {
                        if ($_.InstallDate) {
                            $_.InstallDate
                        }
                        else {
                            $null
                        }
                    } },
                @{ Name = 'InstallLocation'; Expression = { $_.InstallLocation } }
        }
        catch {
            Write-Verbose "Unable to read installed software from ${registryPath}: $($_.Exception.Message)"
        }
    }

    if ($entries.Count -eq 0) {
        Write-Warning 'No installed software entries were found to export.'
        return
    }

    $uniqueEntries = $entries | Sort-Object DisplayName, DisplayVersion, Publisher -Unique
    try {
        $uniqueEntries | Export-Csv -Path $inventoryPath -NoTypeInformation -Encoding UTF8
        Write-Host "Installed software inventory saved to $inventoryPath" -ForegroundColor Cyan
    }
    catch {
        Write-Warning "Failed to write installed software inventory: $($_.Exception.Message)"
    }
}

function Export-HardwareInventory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DestinationDirectory
    )

    $inventoryPath = Join-Path $DestinationDirectory 'hardware-inventory.csv'
    $hardwareData = @()

    Write-Host "Collecting hardware inventory..." -ForegroundColor Yellow

    try {
        # Computer System Info
        $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
        if ($computerSystem) {
            $hardwareData += [PSCustomObject]@{
                Category = 'System'
                Name = $computerSystem.Model
                Manufacturer = $computerSystem.Manufacturer
                Model = $computerSystem.Model
                DeviceID = 'N/A'
                DriverVersion = 'N/A'
                Status = 'N/A'
                AdditionalInfo = "TotalRAM: $([math]::Round($computerSystem.TotalPhysicalMemory / 1GB, 2)) GB"
            }
        }

        # CPU
        $processors = Get-CimInstance -ClassName Win32_Processor -ErrorAction SilentlyContinue
        foreach ($cpu in $processors) {
            $hardwareData += [PSCustomObject]@{
                Category = 'CPU'
                Name = $cpu.Name
                Manufacturer = $cpu.Manufacturer
                Model = $cpu.Name
                DeviceID = $cpu.DeviceID
                DriverVersion = 'N/A'
                Status = $cpu.Status
                AdditionalInfo = "Cores: $($cpu.NumberOfCores), Threads: $($cpu.NumberOfLogicalProcessors)"
            }
        }

        # GPU/Video Controllers
        $videoControllers = Get-CimInstance -ClassName Win32_VideoController -ErrorAction SilentlyContinue
        foreach ($gpu in $videoControllers) {
            $hardwareData += [PSCustomObject]@{
                Category = 'GPU'
                Name = $gpu.Name
                Manufacturer = $gpu.AdapterCompatibility
                Model = $gpu.Name
                DeviceID = $gpu.DeviceID
                DriverVersion = $gpu.DriverVersion
                Status = $gpu.Status
                AdditionalInfo = "RAM: $([math]::Round($gpu.AdapterRAM / 1GB, 2)) GB"
            }
        }

        # Network Adapters (physical only)
        $networkAdapters = Get-CimInstance -ClassName Win32_NetworkAdapter -ErrorAction SilentlyContinue |
            Where-Object { $_.PhysicalAdapter -eq $true }
        foreach ($adapter in $networkAdapters) {
            $hardwareData += [PSCustomObject]@{
                Category = 'Network'
                Name = $adapter.Name
                Manufacturer = $adapter.Manufacturer
                Model = $adapter.ProductName
                DeviceID = $adapter.DeviceID
                DriverVersion = 'N/A'
                Status = $adapter.Status
                AdditionalInfo = "MAC: $($adapter.MACAddress)"
            }
        }

        # Audio Devices
        $soundDevices = Get-CimInstance -ClassName Win32_SoundDevice -ErrorAction SilentlyContinue
        foreach ($audio in $soundDevices) {
            $hardwareData += [PSCustomObject]@{
                Category = 'Audio'
                Name = $audio.Name
                Manufacturer = $audio.Manufacturer
                Model = $audio.ProductName
                DeviceID = $audio.DeviceID
                DriverVersion = 'N/A'
                Status = $audio.Status
                AdditionalInfo = 'N/A'
            }
        }

        # Motherboard
        $baseBoard = Get-CimInstance -ClassName Win32_BaseBoard -ErrorAction SilentlyContinue
        if ($baseBoard) {
            $hardwareData += [PSCustomObject]@{
                Category = 'Motherboard'
                Name = $baseBoard.Product
                Manufacturer = $baseBoard.Manufacturer
                Model = $baseBoard.Product
                DeviceID = 'N/A'
                DriverVersion = 'N/A'
                Status = $baseBoard.Status
                AdditionalInfo = "SerialNumber: $($baseBoard.SerialNumber)"
            }
        }

        # BIOS
        $bios = Get-CimInstance -ClassName Win32_BIOS -ErrorAction SilentlyContinue
        if ($bios) {
            $hardwareData += [PSCustomObject]@{
                Category = 'BIOS'
                Name = $bios.Name
                Manufacturer = $bios.Manufacturer
                Model = $bios.Version
                DeviceID = 'N/A'
                DriverVersion = $bios.SMBIOSBIOSVersion
                Status = $bios.Status
                AdditionalInfo = "Release: $($bios.ReleaseDate)"
            }
        }

        # Physical Memory
        $memory = Get-CimInstance -ClassName Win32_PhysicalMemory -ErrorAction SilentlyContinue
        foreach ($ram in $memory) {
            $hardwareData += [PSCustomObject]@{
                Category = 'RAM'
                Name = "Memory Module"
                Manufacturer = $ram.Manufacturer
                Model = $ram.PartNumber
                DeviceID = $ram.DeviceLocator
                DriverVersion = 'N/A'
                Status = 'N/A'
                AdditionalInfo = "Capacity: $([math]::Round($ram.Capacity / 1GB, 2)) GB, Speed: $($ram.Speed) MHz"
            }
        }

        # Disk Drives
        $diskDrives = Get-CimInstance -ClassName Win32_DiskDrive -ErrorAction SilentlyContinue
        foreach ($disk in $diskDrives) {
            $hardwareData += [PSCustomObject]@{
                Category = 'Storage'
                Name = $disk.Model
                Manufacturer = $disk.Manufacturer
                Model = $disk.Model
                DeviceID = $disk.DeviceID
                DriverVersion = 'N/A'
                Status = $disk.Status
                AdditionalInfo = "Size: $([math]::Round($disk.Size / 1GB, 2)) GB, Interface: $($disk.InterfaceType)"
            }
        }

        # USB Controllers
        $usbControllers = Get-CimInstance -ClassName Win32_USBController -ErrorAction SilentlyContinue
        foreach ($usb in $usbControllers) {
            $hardwareData += [PSCustomObject]@{
                Category = 'USB'
                Name = $usb.Name
                Manufacturer = $usb.Manufacturer
                Model = $usb.Name
                DeviceID = $usb.DeviceID
                DriverVersion = 'N/A'
                Status = $usb.Status
                AdditionalInfo = 'N/A'
            }
        }

        if ($hardwareData.Count -eq 0) {
            Write-Warning 'No hardware information could be collected.'
            return
        }

        # Export to CSV
        $hardwareData | Export-Csv -Path $inventoryPath -NoTypeInformation -Encoding UTF8
        Write-Host "Hardware inventory saved to $inventoryPath" -ForegroundColor Cyan
    }
    catch {
        Write-Warning "Failed to collect hardware inventory: $($_.Exception.Message)"
    }
}

function Get-LogFilePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Destination,

        [string]$RequestedLogPath
    )

    if ($NoLog.IsPresent) {
        return $null
    }

    if ($RequestedLogPath) {
        $directory = Split-Path -Path $RequestedLogPath -Parent
        if ($directory -and -not (Test-Path -LiteralPath $directory)) {
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
        }
        return [System.IO.Path]::GetFullPath($RequestedLogPath)
    }

    $logDirectory = Join-Path $Destination 'logs'
    if (-not (Test-Path -LiteralPath $logDirectory)) {
        New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
    }

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    return Join-Path $logDirectory "backup-$timestamp.log"
}

function Get-FailedFilesLogPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Destination
    )

    if ($NoLog.IsPresent) {
        return $null
    }

    $logDirectory = Join-Path $Destination 'logs'
    if (-not (Test-Path -LiteralPath $logDirectory)) {
        New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
    }

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    return Join-Path $logDirectory "failed-files-$timestamp.log"
}

function Parse-FailedFiles {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RobocopyLogPath,

        [Parameter(Mandatory = $true)]
        [string]$FailedFilesLogPath,

        [Parameter(Mandatory = $true)]
        [string]$SourcePath
    )

    try {
        if (-not (Test-Path -LiteralPath $RobocopyLogPath)) {
            Write-Verbose "Robocopy log not found at $RobocopyLogPath, skipping failed file parsing"
            return
        }

        $logContent = Get-Content -Path $RobocopyLogPath -ErrorAction Stop
        $failedFiles = @()

        # Robocopy log patterns for failed files:
        # - Lines with ERROR followed by file path
        # - Lines starting with file path followed by error code/reason
        # Common patterns: "ERROR 5 (0x00000005)", "ERROR 32 (0x00000020)", etc.
        foreach ($line in $logContent) {
            # Match lines with ERROR and extract file paths
            if ($line -match 'ERROR\s+\d+\s+\(0x[0-9A-Fa-f]+\)\s+(.+)') {
                $filePath = $matches[1].Trim()
                if (-not [string]::IsNullOrWhiteSpace($filePath)) {
                    $failedFiles += $filePath
                }
            }
            # Also match lines that start with timestamp and contain errors
            elseif ($line -match '^\s+\d+\s+(.+\.(txt|log|dat|ini|cfg|xml|json|db|sys|dll|exe|tmp|bak|old|cache|lock|journal|etl|evtx).*)$' -and $line -match '(ERROR|Access is denied|The process cannot access|sharing violation)') {
                $filePath = $matches[1].Trim()
                if (-not [string]::IsNullOrWhiteSpace($filePath)) {
                    $failedFiles += $filePath
                }
            }
        }

        if ($failedFiles.Count -gt 0) {
            # Write header for this source if file doesn't exist yet
            $needsHeader = -not (Test-Path -LiteralPath $FailedFilesLogPath)

            if ($needsHeader) {
                Add-Content -Path $FailedFilesLogPath -Value "================================================"
                Add-Content -Path $FailedFilesLogPath -Value "Failed Files Log - Backup Session $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
                Add-Content -Path $FailedFilesLogPath -Value "================================================"
                Add-Content -Path $FailedFilesLogPath -Value ""
            }

            # Write section header for this source
            Add-Content -Path $FailedFilesLogPath -Value "------------------------------------------------"
            Add-Content -Path $FailedFilesLogPath -Value "Source: $SourcePath"
            Add-Content -Path $FailedFilesLogPath -Value "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
            Add-Content -Path $FailedFilesLogPath -Value "Failed file count: $($failedFiles.Count)"
            Add-Content -Path $FailedFilesLogPath -Value "------------------------------------------------"

            # Write failed files
            foreach ($file in $failedFiles) {
                Add-Content -Path $FailedFilesLogPath -Value $file
            }

            Add-Content -Path $FailedFilesLogPath -Value ""

            Write-Warning "Found $($failedFiles.Count) file(s) that could not be copied from $SourcePath"
            Write-Host "Failed files logged to: $FailedFilesLogPath" -ForegroundColor Yellow
        }
        else {
            Write-Verbose "No failed files detected in Robocopy log for $SourcePath"
        }
    }
    catch {
        Write-Warning "Unable to parse failed files from Robocopy log: $($_.Exception.Message)"
    }
}

function Show-RobocopyProgress {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath,

        [Parameter(Mandatory = $true)]
        [int]$CurrentItem,

        [Parameter(Mandatory = $true)]
        [int]$TotalItems
    )

    $percentOverall = [math]::Round(($CurrentItem / $TotalItems) * 100, 1)
    $progressBar = "=" * [math]::Floor($percentOverall / 5)
    $spaces = " " * (20 - $progressBar.Length)

    Write-Host ""
    Write-Host "+-------------------------------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host "|  Item $CurrentItem of $TotalItems - Overall Progress: $percentOverall%".PadRight(79) + "|" -ForegroundColor Cyan
    Write-Host "|  [$progressBar$spaces]".PadRight(79) + "|" -ForegroundColor Yellow
    Write-Host "+-------------------------------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host "|  Source: $SourcePath".PadRight(79).Substring(0,79) + "|" -ForegroundColor White
    Write-Host "|  Destination: $DestinationPath".PadRight(79).Substring(0,79) + "|" -ForegroundColor White
    Write-Host "+-------------------------------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host ""
}

function Invoke-RobocopyBackup {
    param(
        [Parameter(Mandatory = $true)]
        $Item,

        [string]$LogFile,

        [string]$FailedFilesLog,

        [switch]$IsDryRun,
        [ValidateRange(1,128)]
        [int]
        $Threads = 8,

        [ValidateRange(0,10)]
        [int]
        $Retries = 2,

        [ValidateRange(1,600)]
        [int]
        $RetryDelaySeconds = 5,

        [int]$CurrentItem = 1,

        [int]$TotalItems = 1,

        [ValidateSet('None', 'RoamingOnly', 'Full', 'EssentialFoldersOnly')]
        [string]$AppDataMode = 'Full'
    )

    # Show progress indicator
    Show-RobocopyProgress -SourcePath $Item.Source -DestinationPath $Item.Target -CurrentItem $CurrentItem -TotalItems $TotalItems

    if (-not (Test-Path -LiteralPath $Item.Target)) {
        New-Item -ItemType Directory -Path $Item.Target -Force | Out-Null
    }

    $arguments = @(
        $Item.Source,
        $Item.Target,
        '/E',
        '/COPY:DAT',
        '/DCOPY:DAT',
        '/R:2',
        '/W:5',
        ("/MT:{0}" -f $Threads),
        '/XJ',
        '/V',
        '/TEE'
    )

    if ($IsDryRun) {
        $arguments += '/L'
    }

    if ($LogFile) {
        $arguments += "/LOG+:$LogFile"
    }

    # Add AppData exclusions based on mode
    if ($AppDataMode -eq 'RoamingOnly') {
        # Exclude AppData\Local and AppData\LocalLow, keep AppData\Roaming
        $arguments += '/XD'
        $arguments += 'AppData\Local'
        $arguments += 'AppData\LocalLow'
        Write-Verbose "AppDataMode: RoamingOnly - Excluding AppData\Local and AppData\LocalLow"
    }
    elseif ($AppDataMode -eq 'None') {
        # Exclude all AppData
        $arguments += '/XD'
        $arguments += 'AppData'
        Write-Verbose "AppDataMode: None - Excluding all AppData"
    }
    # EssentialFoldersOnly is handled at the Resolve-BackupItems level, not here
    # Full mode has no exclusions

    Write-Host "Starting Robocopy operation..." -ForegroundColor Cyan
    $command = "robocopy $($arguments -join ' ')"
    Write-Verbose "Executing: $command"

    $attempt = 0
    do {
        $attempt++
        Write-Verbose "Robocopy attempt $attempt of $($Retries + 1)"
        & robocopy @arguments
        $exitCode = $LASTEXITCODE

        if ($exitCode -le 3) {
            Write-Host "Completed with exit code $exitCode" -ForegroundColor Green

            # Parse failed files from log if available
            if ($LogFile -and $FailedFilesLog -and (Test-Path -LiteralPath $LogFile)) {
                Parse-FailedFiles -RobocopyLogPath $LogFile -FailedFilesLogPath $FailedFilesLog -SourcePath $Item.Source
            }
            return
        }

        # Exit codes 4-7 indicate some files failed but operation can continue
        if ($exitCode -ge 4 -and $exitCode -le 7) {
            Write-Warning "Robocopy completed with warnings (exit code $exitCode). Some files may have failed to copy."

            # Parse failed files from log
            if ($LogFile -and $FailedFilesLog -and (Test-Path -LiteralPath $LogFile)) {
                Parse-FailedFiles -RobocopyLogPath $LogFile -FailedFilesLogPath $FailedFilesLog -SourcePath $Item.Source
            }

            Write-Host "Continuing with next backup item..." -ForegroundColor Yellow
            return
        }

        Write-Warning "Robocopy attempt $attempt failed with exit code $exitCode."

        if ($attempt -le $Retries) {
            $delay = [int]([Math]::Pow(2, $attempt - 1) * $RetryDelaySeconds)
            Write-Host "Waiting $delay seconds before retrying..." -ForegroundColor Yellow
            Start-Sleep -Seconds $delay
        }
    }
    while ($attempt -le $Retries)

    # If we reach here all attempts failed with serious errors (exit code >= 8)
    Write-Host "Robocopy failed for $($Item.Source) after $attempt attempt(s) with exit code $exitCode." -ForegroundColor Red

    if ($LogFile) {
        Write-Host "Robocopy log: $LogFile" -ForegroundColor Yellow
        try {
            Write-Host "Last 200 lines of Robocopy log (searching for ERROR/failed lines):" -ForegroundColor Yellow
            $lines = Get-Content -Path $LogFile -ErrorAction SilentlyContinue -Tail 200
            $failureLines = $lines | Where-Object { $_ -match '\b(ERROR|failed|Failed|ERRORS)\b' }
            if ($failureLines -and $failureLines.Count -gt 0) {
                $failureLines | ForEach-Object { Write-Host $_ }
            }
            else {
                $lines | ForEach-Object { Write-Host $_ }
            }
        }
        catch {
            Write-Warning "Unable to read Robocopy log at ${LogFile}: $($_.Exception.Message)"
        }

        # Parse failed files even on critical failure
        if ($FailedFilesLog) {
            Parse-FailedFiles -RobocopyLogPath $LogFile -FailedFilesLogPath $FailedFilesLog -SourcePath $Item.Source
        }
    }

    Write-Host "Common causes: insufficient permissions, files in use, network/share errors, or serious I/O errors." -ForegroundColor Yellow
    Write-Host "Try: re-running PowerShell as Administrator, disabling interfering antivirus, or running Robocopy manually using the shown log path to inspect details." -ForegroundColor Yellow
    Write-Host "Consider reducing threads (use -RobocopyThreads 1) or increasing retries." -ForegroundColor Yellow
    Write-Warning "Continuing with remaining backup items, but this item may be incomplete."
}

$osInfo = Get-OsVersionInfo
if (-not (Test-IsSupportedWindows -OsInfo $osInfo)) {
    throw 'This script is intended for Windows 10 or Windows 11 systems.'
}

# Detect if we should run in interactive mode
$isInteractive = (-not $NonInteractive.IsPresent) -and ([string]::IsNullOrWhiteSpace($DestinationPath))

if ($isInteractive) {
    Write-Host ""
    Write-Host "+-------------------------------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host "|                              Interactive Backup Mode                          |" -ForegroundColor Cyan
    Write-Host "+-------------------------------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Welcome to the x0dus interactive backup wizard!" -ForegroundColor Yellow
    Write-Host "This wizard will guide you through configuring your backup." -ForegroundColor White
    Write-Host ""

    # Display detailed backup mode explanations
    Write-Host "Understanding Backup Modes:" -ForegroundColor Yellow
    Write-Host "----------------------------" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "[1] Essential Files Only" -ForegroundColor Green
    Write-Host "    - Backs up: Documents, Desktop, Pictures, Videos, Music, Downloads" -ForegroundColor White
    Write-Host "    - Skips: All AppData (no application settings or caches)" -ForegroundColor Gray
    Write-Host "    - Size: Smallest (typically 5-50 GB per user)" -ForegroundColor White
    Write-Host "    - Best for: Fresh Linux start, you'll reconfigure applications" -ForegroundColor White
    Write-Host ""
    Write-Host "[2] Essential + Settings (Recommended)" -ForegroundColor Green
    Write-Host "    - Backs up: Essential files + AppData\Roaming" -ForegroundColor White
    Write-Host "    - Includes: App settings, game saves, browser bookmarks/passwords" -ForegroundColor White
    Write-Host "    - Skips: AppData\Local (caches, temp files, shader caches)" -ForegroundColor Gray
    Write-Host "    - Size: Medium (typically 10-80 GB per user)" -ForegroundColor White
    Write-Host "    - Best for: Preserve settings without bloat" -ForegroundColor White
    Write-Host ""
    Write-Host "[3] Full User Profile" -ForegroundColor Green
    Write-Host "    - Backs up: Everything in user folder(s)" -ForegroundColor White
    Write-Host "    - Includes: ALL AppData (Roaming + Local + LocalLow)" -ForegroundColor White
    Write-Host "    - Warning: AppData\Local can be 10GB+ with browser/Steam caches!" -ForegroundColor Yellow
    Write-Host "    - Size: Largest (can exceed 100+ GB per user)" -ForegroundColor White
    Write-Host "    - Best for: Maximum preservation, forensics, unsure what you need" -ForegroundColor White
    Write-Host ""
    Write-Host "[4] Custom Backup" -ForegroundColor Green
    Write-Host "    - Full control: Additional folders, network shares, custom AppData handling" -ForegroundColor White
    Write-Host "    - Best for: Advanced users with specific requirements" -ForegroundColor White
    Write-Host ""
    Write-Host "Note: AppData\Roaming stores app settings/saves (~1-10 GB)" -ForegroundColor Cyan
    Write-Host "      AppData\Local stores caches/temp files (~5-50 GB, often unnecessary)" -ForegroundColor Cyan
    Write-Host ""

    $options = @(
        "Essential Files Only (No AppData)",
        "Essential + Settings (AppData\Roaming only) [RECOMMENDED]",
        "Full User Profile (All AppData)",
        "Custom Backup (Full control)"
    )

    $modeChoice = Show-Menu -Title "Select Backup Mode" -Options $options -DefaultChoice 2
    $quickMode = ($modeChoice -le 3)

    Write-Host ""
    Write-Host "Note: You will be asked which user profiles to backup in the next step." -ForegroundColor Cyan
    Write-Host ""

    # Map mode choice to AppDataMode
    switch ($modeChoice) {
        1 { $AppDataMode = 'EssentialFoldersOnly' }
        2 { $AppDataMode = 'RoamingOnly' }
        3 { $AppDataMode = 'Full' }
        4 { $AppDataMode = 'Full' }  # Custom mode - user can override via interactive menu
    }

    $interactiveConfig = Get-InteractiveConfiguration -QuickMode $quickMode -ModeChoice $modeChoice

    # Apply interactive configuration to script variables
    $DestinationPath = $interactiveConfig.DestinationPath

    # Only set network parameters if a network share was configured
    if ($interactiveConfig.NetworkShare) {
        $NetworkShare = $interactiveConfig.NetworkShare
        $NetworkProtocol = $interactiveConfig.NetworkProtocol
        $NetworkCredential = $interactiveConfig.NetworkCredential
        $NetworkDriveLetter = $interactiveConfig.NetworkDriveLetter
    }

    if ($interactiveConfig.IncludeAllUsers) {
        $IncludeAllUsers = $true
    }
    if ($interactiveConfig.IncludePublicProfile) {
        $IncludePublicProfile = $true
    }
    if ($interactiveConfig.SkipDefaultDirectories) {
        $SkipDefaultDirectories = $true
    }

    $AdditionalPaths = $interactiveConfig.AdditionalPaths
    $RobocopyThreads = $interactiveConfig.Threads
    $RobocopyRetries = $interactiveConfig.Retries
    $RobocopyRetryDelaySeconds = $interactiveConfig.RetryDelaySeconds

    # Override AppDataMode if Custom mode provided a different selection
    if ($interactiveConfig.AppDataMode) {
        $AppDataMode = $interactiveConfig.AppDataMode
    }

    # Apply dry run setting from interactive config
    if ($interactiveConfig.DryRun) {
        $DryRun = $true
    }
}

# Validate that DestinationPath is set (either via parameter or interactive mode)
if ([string]::IsNullOrWhiteSpace($DestinationPath)) {
    throw "DestinationPath is required. Run the script without parameters for interactive mode, or provide -DestinationPath."
}

$networkContext = $null
try {
    if ($NetworkShare) {
        $networkContext = Connect-NetworkDestination -Share $NetworkShare -Protocol $NetworkProtocol -DriveLetter $NetworkDriveLetter -Credential $NetworkCredential -MountOptions $NetworkMountOptions -Persistent:$NetworkPersistent
    }

    $resolvedDestination = Resolve-DestinationPath -Path $DestinationPath -NetworkContext $networkContext

    # Ensure destination exists or prompt to create it
    if (-not (Confirm-DestinationInteractive -Path $resolvedDestination -Force:$ForceCreateDestination)) {
        throw "Destination path unavailable: $resolvedDestination"
    }

    $destination = Initialize-Destination -Path $resolvedDestination

    # Start script-level logging (transcript) into the destination logs folder
    $scriptLog = Get-ScriptLogFilePath -Destination $destination
    if ($scriptLog) {
        Start-ScriptLogging -Path $scriptLog
    }

    $logFile = Get-LogFilePath -Destination $destination -RequestedLogPath $LogPath
    if ($logFile) {
        Write-Host "Logging Robocopy output to $logFile" -ForegroundColor Yellow
    }
    elseif (-not $NoLog.IsPresent) {
        Write-Warning 'Logging disabled because the log path could not be created.'
    }

    $failedFilesLog = Get-FailedFilesLogPath -Destination $destination
    if ($failedFilesLog) {
        Write-Verbose "Failed files will be logged to $failedFilesLog"
    }

    $includeCurrentUser = -not $SkipDefaultDirectories.IsPresent
    $backupItems = Resolve-BackupItems -Destination $destination -IncludeCurrentUser:$includeCurrentUser -IncludeAllUsers:$IncludeAllUsers.IsPresent -IncludePublicProfile:$IncludePublicProfile.IsPresent -ExtraPaths $AdditionalPaths -AppDataMode $AppDataMode

    if ($backupItems.Count -eq 0) {
        throw 'No valid source directories were found to back up.'
    }

    foreach ($item in $backupItems) {
        if (Test-IsDestinationWithinSource -Source $item.Source -Destination $item.Target) {
            throw "The destination '$($item.Target)' is inside the source '$($item.Source)'. Choose a different destination to avoid infinite recursion."
        }
    }

    Write-Host ""
    Write-Host "+===============================================================================+" -ForegroundColor Cyan
    Write-Host "|                         BACKUP SIZE ESTIMATION                                |" -ForegroundColor Cyan
    Write-Host "+===============================================================================+" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Analyzing source directories and calculating total size..." -ForegroundColor Yellow
    Write-Host "This may take several minutes for large directories." -ForegroundColor Gray
    Write-Host ""

    $sizeEstimate = Get-BackupSizeEstimate -Items $backupItems
    $totalBytes = [int64]$sizeEstimate.TotalSizeBytes

    Write-Host "Size estimation completed!" -ForegroundColor Green
    Write-Host ""

    if ($sizeEstimate.HadErrors) {
        Write-Host "WARNINGS DURING SIZE ESTIMATION:" -ForegroundColor Yellow
        foreach ($detail in $sizeEstimate.Details) {
            if ($detail.HadErrors) {
                Write-Warning "Some contents under '$($detail.Path)' could not be scanned: $($detail.ErrorMessages -join '; ')"
            }
        }
        Write-Warning 'The size estimate excludes items that could not be scanned due to access restrictions. Ensure additional free space is available or rerun with elevated permissions.'
        Write-Host ""
    }

    Write-Host "+===============================================================================+" -ForegroundColor Cyan
    Write-Host "|                         SPACE AVAILABILITY CHECK                              |" -ForegroundColor Cyan
    Write-Host "+===============================================================================+" -ForegroundColor Cyan
    Write-Host ""

    $availableBytes = Get-DestinationFreeSpace -Path $destination
    $spaceUtilizationPercent = 0
    if ($availableBytes -gt 0) {
        $spaceUtilizationPercent = [math]::Round(($totalBytes / $availableBytes) * 100, 1)
    }

    Write-Host "Estimated backup size: " -NoNewline -ForegroundColor White
    Write-Host "$(Format-ByteSize -Bytes $totalBytes)" -ForegroundColor Cyan
    Write-Host "Available space:       " -NoNewline -ForegroundColor White
    Write-Host "$(Format-ByteSize -Bytes $availableBytes)" -ForegroundColor Cyan
    Write-Host "Space utilization:     " -NoNewline -ForegroundColor White

    # Color-code space utilization
    if ($spaceUtilizationPercent -gt 100) {
        Write-Host "$spaceUtilizationPercent% " -NoNewline -ForegroundColor Red
        Write-Host "(INSUFFICIENT SPACE!)" -ForegroundColor Red
    }
    elseif ($spaceUtilizationPercent -gt 90) {
        Write-Host "$spaceUtilizationPercent% " -NoNewline -ForegroundColor Red
        Write-Host "(WARNING: Very tight!)" -ForegroundColor Yellow
    }
    elseif ($spaceUtilizationPercent -gt 80) {
        Write-Host "$spaceUtilizationPercent% " -NoNewline -ForegroundColor Yellow
        Write-Host "(Caution: Limited space)" -ForegroundColor Yellow
    }
    elseif ($spaceUtilizationPercent -gt 50) {
        Write-Host "$spaceUtilizationPercent%" -ForegroundColor Yellow
    }
    else {
        Write-Host "$spaceUtilizationPercent% " -NoNewline -ForegroundColor Green
        Write-Host "(Good)" -ForegroundColor Green
    }

    Write-Host ""

    # Handle insufficient space
    if ($totalBytes -gt $availableBytes) {
        Write-Host "+===============================================================================+" -ForegroundColor Red
        Write-Host "|                           INSUFFICIENT SPACE                                  |" -ForegroundColor Red
        Write-Host "+===============================================================================+" -ForegroundColor Red
        Write-Host ""
        Write-Host "ERROR: The estimated backup size exceeds available destination space!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Shortfall: " -NoNewline -ForegroundColor White
        Write-Host "$(Format-ByteSize -Bytes ($totalBytes - $availableBytes))" -ForegroundColor Red
        Write-Host ""
        Write-Host "Options:" -ForegroundColor Yellow
        Write-Host "  1. Free up space at the destination" -ForegroundColor White
        Write-Host "  2. Choose a different destination" -ForegroundColor White
        Write-Host "  3. Reduce backup scope (exclude users, skip AppData, etc.)" -ForegroundColor White
        Write-Host ""
        throw "Backup cannot proceed: Insufficient space at destination."
    }

    # Warn if space is tight (>80% utilization) and ask for confirmation
    if ($spaceUtilizationPercent -gt 80) {
        Write-Host "WARNING: Backup will use more than 80% of available space!" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Robocopy may require additional temporary space during operation." -ForegroundColor Yellow
        Write-Host "Consider having at least 10-20% free space buffer for safety." -ForegroundColor Yellow
        Write-Host ""

        $proceed = Read-Host "Do you want to proceed anyway? (Y/N) [default: N]"
        if ($proceed -notmatch '^[Yy]') {
            throw "Backup cancelled by user due to space concerns."
        }
        Write-Host ""
    }

    Write-Host "+===============================================================================+" -ForegroundColor Green
    Write-Host "|                         READY TO BEGIN BACKUP                                 |" -ForegroundColor Green
    Write-Host "+===============================================================================+" -ForegroundColor Green
    Write-Host ""
    Write-Host "Backup items: " -NoNewline -ForegroundColor White
    Write-Host "$($backupItems.Count)" -ForegroundColor Cyan
    Write-Host "Total size:   " -NoNewline -ForegroundColor White
    Write-Host "$(Format-ByteSize -Bytes $totalBytes)" -ForegroundColor Cyan
    if ($DryRun) {
        Write-Host "Mode:         " -NoNewline -ForegroundColor White
        Write-Host "DRY RUN (preview only, no files will be copied)" -ForegroundColor Yellow
    }
    Write-Host ""

    # Final confirmation before starting backup
    Write-Host "Review the information above carefully." -ForegroundColor Yellow
    Read-Host "Press Enter to start the backup (or Ctrl+C to cancel)"
    Write-Host ""

    Write-Host "Starting backup of $($backupItems.Count) item(s)..." -ForegroundColor Magenta
    $itemIndex = 0
    foreach ($item in $backupItems) {
        $itemIndex++
        Invoke-RobocopyBackup -Item $item -LogFile $logFile -FailedFilesLog $failedFilesLog -IsDryRun:$DryRun -Threads $RobocopyThreads -Retries $RobocopyRetries -RetryDelaySeconds $RobocopyRetryDelaySeconds -CurrentItem $itemIndex -TotalItems $backupItems.Count -AppDataMode $AppDataMode
    }

    Write-Host ""
    Write-Host "+===============================================================================+" -ForegroundColor Cyan
    Write-Host "|                         BACKUP COMPLETION SUMMARY                             |" -ForegroundColor Cyan
    Write-Host "+===============================================================================+" -ForegroundColor Cyan
    Write-Host ""

    # Check if failed files log exists and has content
    if ($failedFilesLog -and (Test-Path -LiteralPath $failedFilesLog)) {
        $failedFilesContent = Get-Content -Path $failedFilesLog -ErrorAction SilentlyContinue
        if ($failedFilesContent -and $failedFilesContent.Count -gt 0) {
            Write-Host "WARNING: Some files could not be backed up!" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "A log of failed files has been created at:" -ForegroundColor White
            Write-Host "  $failedFilesLog" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "Common reasons for backup failures:" -ForegroundColor White
            Write-Host "  - Files in use by running applications" -ForegroundColor Gray
            Write-Host "  - Insufficient permissions (try running as Administrator)" -ForegroundColor Gray
            Write-Host "  - System files locked by Windows" -ForegroundColor Gray
            Write-Host "  - Network errors (for network destinations)" -ForegroundColor Gray
            Write-Host ""
            Write-Host "Review the failed files log to determine if any critical files were missed." -ForegroundColor Yellow
            Write-Host "You may want to:" -ForegroundColor White
            Write-Host "  1. Close applications that might be using the files" -ForegroundColor Gray
            Write-Host "  2. Re-run the backup with Administrator privileges" -ForegroundColor Gray
            Write-Host "  3. Manually copy critical files from the failed files list" -ForegroundColor Gray
            Write-Host ""
        }
        else {
            Write-Host "Status: All files backed up successfully!" -ForegroundColor Green
        }
    }
    else {
        Write-Host "Status: Backup completed!" -ForegroundColor Green
    }

    if ($DryRun) {
        Write-Host ""
        Write-Host 'NOTE: Dry run mode was enabled. No files were actually copied.' -ForegroundColor Yellow
    }
    else {
        Write-Host ""
        Export-InstalledSoftwareInventory -DestinationDirectory $destination
        Export-HardwareInventory -DestinationDirectory $destination
    }

    Write-Host ""
    Write-Host "+===============================================================================+" -ForegroundColor Cyan
    Write-Host ""
}
finally {
    Disconnect-NetworkDestination -Context $networkContext
    Stop-ScriptLogging
}
