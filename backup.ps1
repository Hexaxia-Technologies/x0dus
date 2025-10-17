<#
.SYNOPSIS
    Backup important Windows user data before migrating to Linux.

.DESCRIPTION
    This script copies the entire user profile directory (for example C:\Users\Alice)
    to a destination drive or folder by using Robocopy. You can optionally include
    every profile under C:\Users as well as the shared C:\Users\Public directory.
    Additional folders can be specified when invoking the script. The goal is to make
    sure a user's data is safely stored before reinstalling the operating system.

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

.EXAMPLE
    .\backup.ps1 -DestinationPath "E:\UserBackup"

    Copies the entire user profile to E:\UserBackup using Robocopy.

.EXAMPLE
    .\backup.ps1 -DestinationPath "E:\UserBackup" -AdditionalPaths "C:\"

    Backs up the default folders and the root of the C: drive with a friendly name.

.NOTES
    Run this script from an elevated PowerShell session if you see access denied errors.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
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
)

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
            throw "Unable to map SMB share $normalized: $($_.Exception.Message)"
        }

        Write-Host "Mapped $normalized to drive $upperLetter:" -ForegroundColor Cyan
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
            throw "Unable to mount NFS share $Share: $($_.Exception.Message)"
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
        [Parameter(Mandatory = $true)]
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

function Get-UserProfileBackupPath {
    $userProfile = [Environment]::GetFolderPath('UserProfile')
    $name = Split-Path -Path $userProfile -Leaf
    return @{ Name = $name; Path = $userProfile }
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
        Write-Warning "Unable to enumerate user profiles in $usersRoot: $($_.Exception.Message)"
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
        [string[]]$ExtraPaths
    )

    $items = @()
    if ($IncludeCurrentUser) {
        $items += Get-UserProfileBackupPath()
    }

    if ($IncludeAllUsers) {
        $items += Get-AllUserProfileBackupPaths -IncludePublic:$IncludePublicProfile
    }
    elseif ($IncludePublicProfile) {
        $items += Get-PublicProfileBackupPath()
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
    foreach ($error in $errors) {
        if ($error -and $error.Exception -and -not [string]::IsNullOrWhiteSpace($error.Exception.Message)) {
            $messages += $error.Exception.Message
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
            Write-Verbose "Unable to read installed software from $registryPath: $($_.Exception.Message)"
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

function Invoke-RobocopyBackup {
    param(
        [Parameter(Mandatory = $true)]
        $Item,

        [string]$LogFile,

        [switch]$IsDryRun
    )

    if (-not (Test-Path -LiteralPath $Item.Target)) {
        New-Item -ItemType Directory -Path $Item.Target -Force | Out-Null
    }

    $arguments = @(
        '"' + $Item.Source + '"',
        '"' + $Item.Target + '"',
        '/E',
        '/COPY:DAT',
        '/DCOPY:DAT',
        '/R:2',
        '/W:5',
        '/MT:8',
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

    Write-Host "Backing up '$($Item.Source)' to '$($Item.Target)'" -ForegroundColor Cyan
    $command = "robocopy $($arguments -join ' ')"
    Write-Verbose "Executing: $command"

    & robocopy @arguments
    $exitCode = $LASTEXITCODE

    if ($exitCode -le 3) {
        Write-Host "Completed with exit code $exitCode" -ForegroundColor Green
    }
    else {
        throw "Robocopy failed for $($Item.Source) with exit code $exitCode."
    }
}

$osInfo = Get-OsVersionInfo
if (-not (Test-IsSupportedWindows -OsInfo $osInfo)) {
    throw 'This script is intended for Windows 10 or Windows 11 systems.'
}

$networkContext = $null
try {
    if ($NetworkShare) {
        $networkContext = Connect-NetworkDestination -Share $NetworkShare -Protocol $NetworkProtocol -DriveLetter $NetworkDriveLetter -Credential $NetworkCredential -MountOptions $NetworkMountOptions -Persistent:$NetworkPersistent
    }

    $resolvedDestination = Resolve-DestinationPath -Path $DestinationPath -NetworkContext $networkContext
    $destination = Initialize-Destination -Path $resolvedDestination
    $logFile = Get-LogFilePath -Destination $destination -RequestedLogPath $LogPath
    if ($logFile) {
        Write-Host "Logging Robocopy output to $logFile" -ForegroundColor Yellow
    }
    elseif (-not $NoLog.IsPresent) {
        Write-Warning 'Logging disabled because the log path could not be created.'
    }

    $includeCurrentUser = -not $SkipDefaultDirectories.IsPresent
    $backupItems = Resolve-BackupItems -Destination $destination -IncludeCurrentUser:$includeCurrentUser -IncludeAllUsers:$IncludeAllUsers.IsPresent -IncludePublicProfile:$IncludePublicProfile.IsPresent -ExtraPaths $AdditionalPaths

    if ($backupItems.Count -eq 0) {
        throw 'No valid source directories were found to back up.'
    }

    foreach ($item in $backupItems) {
        if (Test-IsDestinationWithinSource -Source $item.Source -Destination $item.Target) {
            throw "The destination '$($item.Target)' is inside the source '$($item.Source)'. Choose a different destination to avoid infinite recursion."
        }
    }

    Write-Host 'Estimating backup size...' -ForegroundColor Yellow
    $sizeEstimate = Get-BackupSizeEstimate -Items $backupItems
    $totalBytes = [int64]$sizeEstimate.TotalSizeBytes

    if ($sizeEstimate.HadErrors) {
        foreach ($detail in $sizeEstimate.Details) {
            if ($detail.HadErrors) {
                Write-Warning "Some contents under '$($detail.Path)' could not be scanned: $($detail.ErrorMessages -join '; ')"
            }
        }
        Write-Warning 'The size estimate excludes items that could not be scanned due to access restrictions. Ensure additional free space is available or rerun with elevated permissions.'
    }

    Write-Host "Estimated data to copy: $(Format-ByteSize -Bytes $totalBytes)" -ForegroundColor Yellow

    $availableBytes = Get-DestinationFreeSpace -Path $destination
    Write-Host "Available space at destination: $(Format-ByteSize -Bytes $availableBytes)" -ForegroundColor Yellow

    if ($totalBytes -gt $availableBytes) {
        throw "Estimated backup size ($(Format-ByteSize -Bytes $totalBytes)) exceeds available space ($(Format-ByteSize -Bytes $availableBytes)). Free up space or choose a different destination."
    }

    Write-Host "Starting backup of $($backupItems.Count) item(s)..." -ForegroundColor Magenta
    foreach ($item in $backupItems) {
        Invoke-RobocopyBackup -Item $item -LogFile $logFile -IsDryRun:$DryRun
    }

    Write-Host 'Backup completed successfully.' -ForegroundColor Green
    if ($DryRun) {
        Write-Host 'Dry run mode was enabled. No files were copied.' -ForegroundColor Yellow
    }
    else {
        Export-InstalledSoftwareInventory -DestinationDirectory $destination
    }
}
finally {
    Disconnect-NetworkDestination -Context $networkContext
}
