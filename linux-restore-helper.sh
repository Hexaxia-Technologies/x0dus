#!/usr/bin/env bash
# linux-restore-helper.sh
# Assist recently migrated Linux users with locating and mounting the Windows backup drive.

set -euo pipefail

SCRIPT_VERSION="1.0.0.RC1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

SELECTED_SOURCE_DESCRIPTION=""
DETECTED_DISTRO_NAME="Unknown"
DETECTED_DISTRO_VERSION=""
DETECTED_DISTRO_ID=""

show_banner() {
  local subtitle="$1"
  local cyan='\033[36m'
  local reset='\033[0m'

  printf "${cyan}"
  cat <<'BANNER'

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

BANNER

  printf "           x0dus Migration Toolkit v%s\n" "$SCRIPT_VERSION"
  printf "                     %s\n" "$subtitle"
  printf "       Windows to Linux Migration - Data Backup and\n"
  printf "                   Restore Utility\n"
  printf "             Developed by Hexaxia Technologies\n"
  printf "                   https://hexaxia.tech\n"
  printf "                    Report issues at:\n"
  printf "       github.com/Hexaxia-Technologies/x0dus/issues\n"
  printf "================================================================\n"
  printf "DISCLAIMER: This software is provided \"as is\" without warranty\n"
  printf "of any kind. Use at your own risk. Hexaxia Technologies assumes\n"
  printf "no liability for data loss or damages from use of this software.\n"
  printf "================================================================\n"
  printf "${reset}\n"
}

print_header() {
  local title="$1"
  local underline
  underline=$(printf '%*s' "${#title}" '')
  underline=${underline// /-}
  printf '\n%s\n%s\n' "$title" "$underline"
}

detect_distro() {
  local name="Unknown"
  local version=""
  local id=""

  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    name=${NAME:-$name}
    version=${VERSION:-${VERSION_ID:-}}
    id=${ID:-}
  elif command -v lsb_release >/dev/null 2>&1; then
    name=$(lsb_release -s -d 2>/dev/null || echo "$name")
    version=$(lsb_release -s -r 2>/dev/null || echo "")
    id=$(lsb_release -s -i 2>/dev/null || echo "")
  fi

  DETECTED_DISTRO_NAME=$name
  DETECTED_DISTRO_VERSION=$version
  if [[ -n $id ]]; then
    DETECTED_DISTRO_ID=${id,,}
  else
    DETECTED_DISTRO_ID=""
  fi

  if [[ -z $DETECTED_DISTRO_ID ]]; then
    # Try to infer an ID-like token from the distribution name.
    DETECTED_DISTRO_ID=$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]' | awk '{print $1}')
  fi

  printf 'Detected distribution : %s\n' "$DETECTED_DISTRO_NAME"
  if [[ -n $DETECTED_DISTRO_VERSION ]]; then
    printf 'Version              : %s\n' "$DETECTED_DISTRO_VERSION"
  fi
  if [[ -n $DETECTED_DISTRO_ID ]]; then
    printf 'Distribution ID      : %s\n' "$DETECTED_DISTRO_ID"
  fi
  printf 'Kernel               : %s\n' "$(uname -sr)"
  printf 'Current user         : %s\n' "$(whoami)"
}

git_install_hint() {
  local hint=""
  case "$DETECTED_DISTRO_ID" in
    ubuntu|debian|linuxmint|pop|elementary|zorin|kubuntu|lubuntu|xubuntu|neon|mx|deepin|raspbian|peppermint)
      hint="sudo apt update && sudo apt install -y git"
      ;;
    fedora|rhel|centos|rocky|almalinux|oracle)
      hint="sudo dnf install -y git"
      ;;
    arch|manjaro|endeavouros|garuda)
      hint="sudo pacman -S git"
      ;;
    opensuse*|sles|sled)
      hint="sudo zypper install -y git"
      ;;
    gentoo)
      hint="sudo emerge --ask dev-vcs/git"
      ;;
    void)
      hint="sudo xbps-install -Sy git"
      ;;
    alpine)
      hint="sudo apk add git"
      ;;
    *)
      if command -v apt >/dev/null 2>&1; then
        hint="sudo apt update && sudo apt install -y git"
      elif command -v dnf >/dev/null 2>&1; then
        hint="sudo dnf install -y git"
      elif command -v yum >/dev/null 2>&1; then
        hint="sudo yum install -y git"
      elif command -v pacman >/dev/null 2>&1; then
        hint="sudo pacman -S git"
      elif command -v zypper >/dev/null 2>&1; then
        hint="sudo zypper install -y git"
      elif command -v apk >/dev/null 2>&1; then
        hint="sudo apk add git"
      fi
      ;;
  esac

  printf '%s' "$hint"
}

report_git_status() {
  print_header "Git availability"

  local workspace=""
  local git_info_file=""
  if [[ -n ${HOME:-} ]]; then
    workspace="${HOME}/x0dus"
    if [[ -e $workspace && ! -d $workspace ]]; then
      echo "$workspace exists but is not a directory. Git details will not be saved."
    else
      if mkdir -p "$workspace"; then
        git_info_file="$workspace/git-info.txt"
      else
        echo "Unable to create $workspace to record Git information."
      fi
    fi
  fi

  local repo_root=""
  local repo_url=""
  local -a git_lines=()

  if command -v git >/dev/null 2>&1; then
    local git_version
    git_version=$(git --version 2>/dev/null || echo "git")
    echo "Git command found: $git_version"
    git_lines+=("Git available: yes")
    git_lines+=("Git version: $git_version")
    git_lines+=("Verification command: git --version")

    if git -C "$SCRIPT_DIR" rev-parse --show-toplevel >/dev/null 2>&1; then
      repo_root=$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)
      echo "Script is inside the Git working tree at: $repo_root"
      git_lines+=("Repository root: $repo_root")
      local branch
      branch=$(git -C "$SCRIPT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
      git_lines+=("Current branch: $branch")
      echo "Current branch: $branch"
      repo_url=$(git -C "$SCRIPT_DIR" config --get remote.origin.url 2>/dev/null || echo "")
      if [[ -n $repo_url ]]; then
        echo "Remote origin: $repo_url"
        git_lines+=("Remote origin: $repo_url")
      fi
      echo "To fetch the latest updates, run:"
      echo "  cd \"$repo_root\""
      echo "  git pull"
      git_lines+=("Update command: cd \"$repo_root\" && git pull")
    else
      if [[ -n ${HOME:-} ]]; then
        repo_root="${HOME}/x0dus"
      else
        repo_root="${PWD}/x0dus"
      fi
      if [[ -z $repo_url ]]; then
        repo_url="https://github.com/Hexaxia-Technologies/x0dus.git"
      fi
      echo "These helpers are not currently in a Git repository."
      echo "You can clone them to your home directory with:"
      echo "  cd \"${HOME:-$PWD}\""
      echo "  git clone ${repo_url} x0dus"
      git_lines+=("Clone URL: ${repo_url}")
      git_lines+=("Clone target: ${HOME:-$PWD}/x0dus")
      git_lines+=("Clone suggestion: cd \"${HOME:-$PWD}\" && git clone ${repo_url} x0dus")
    fi
  else
    echo "Git is not installed on this system."
    git_lines+=("Git available: no")
    echo "Run 'git --version' after installing to verify the command is available."
    git_lines+=("Verification command: git --version")
    local install_hint
    install_hint=$(git_install_hint)
    if [[ -n $install_hint ]]; then
      echo "Suggested install command:"
      echo "  $install_hint"
      git_lines+=("Suggested install command: $install_hint")
    else
      echo "Consult your distribution documentation for Git installation steps."
      git_lines+=("Suggested install command: (consult distribution documentation)")
    fi
  fi

  if [[ -n $git_info_file && ${#git_lines[@]} -gt 0 ]]; then
    printf '%s\n' "${git_lines[@]}" >"$git_info_file"
    echo "Git information recorded at $git_info_file"
  fi
}

show_storage_overview() {
  print_header "Storage devices overview"
  if command -v lsblk >/dev/null 2>&1; then
    echo "Listing block devices (lsblk -f):"
    lsblk -f
  else
    echo "lsblk is not available on this system."
  fi

  if command -v blkid >/dev/null 2>&1; then
    printf '\nFilesystem signatures (blkid):\n'
    blkid
  else
    printf '\nblkid is not available. You can install the util-linux package to access it.\n'
  fi

  if command -v df >/dev/null 2>&1; then
    printf '\nMounted filesystems (df -h):\n'
    df -h
  fi
}

get_mount_targets_for_source() {
  local source="$1"
  if [[ -z $source ]]; then
    return
  fi

  if command -v findmnt >/dev/null 2>&1; then
    findmnt -nrS "$source" -o TARGET 2>/dev/null || true
    return
  fi

  awk -v src="$source" '$1==src {print $2}' /proc/mounts
}

choose_existing_mount() {
  local targets=("$@")
  local count=${#targets[@]}
  if (( count == 0 )); then
    return 1
  fi

  if (( count == 1 )); then
    local target="${targets[0]}"
    read -r -p "Reuse existing mount at $target? [Y/n]: " reuse
    reuse=${reuse,,}
    if [[ -z $reuse || $reuse == "y" || $reuse == "yes" ]]; then
      printf '%s\n' "$target"
      return 0
    fi
    return 1
  fi

  echo "Existing mount points for this source:"
  local i
  for ((i = 0; i < count; i++)); do
    printf '  [%d] %s\n' "$((i + 1))" "${targets[i]}"
  done

  read -r -p "Enter the number of a mount point to reuse or press Enter to mount a new location: " selection
  if [[ -z $selection ]]; then
    return 1
  fi

  if [[ $selection =~ ^[0-9]+$ ]] && (( selection >= 1 && selection <= count )); then
    printf '%s\n' "${targets[selection - 1]}"
    return 0
  fi

  echo "Invalid selection. Continuing with a new mount."
  return 1
}

prompt_mount_point() {
  local default_point="$1"
  read -r -p "Enter the mount point to use [${default_point}]: " mount_point
  mount_point=${mount_point:-$default_point}
  printf '%s\n' "$mount_point"
}

is_mount_point_in_use() {
  local mount_point="$1"
  if [[ -z $mount_point ]]; then
    return 1
  fi

  if command -v findmnt >/dev/null 2>&1; then
    if findmnt -nrT "$mount_point" >/dev/null 2>&1; then
      return 0
    fi
    return 1
  fi

  awk -v tgt="$mount_point" '$2==tgt {found=1; exit} END {exit found?0:1}' /proc/mounts
}

prompt_backup_location_type() {
  while true; do
    printf '\nWhere is your backup stored?\n'
    printf '  [1] Local drive (USB, SATA, NVMe, etc.)\n'
    printf '  [2] Network share (SMB/CIFS or NFS)\n'
    read -r -p "Select an option [1]: " choice
    case ${choice:-1} in
      1)
        printf 'device\n'
        return
        ;;
      2)
        printf 'network\n'
        return
        ;;
      q|Q)
        echo "Exiting per user request."
        exit 0
        ;;
      *)
        echo "Unknown selection. Please choose 1 for a local drive or 2 for a network share."
        ;;
    esac
  done
}

detect_network_protocol() {
  local path="$1"
  if [[ $path =~ ^(//|\\\\) ]]; then
    printf 'smb'
    return
  fi

  if [[ $path == *:* ]]; then
    printf 'nfs'
    return
  fi
}

normalize_smb_path() {
  local path="$1"
  path=${path//\\/\/}
  path=${path#//}
  printf '//%s\n' "$path"
}

normalize_network_source() {
  local path="$1"
  local protocol="$2"
  if [[ $protocol == "smb" ]]; then
    normalize_smb_path "$path"
  else
    printf '%s\n' "${path//\\/\/}"
  fi
}

prompt_network_protocol() {
  local initial="$1"
  local detected
  detected=$(detect_network_protocol "$initial")
  while true; do
    local prompt='Protocol to use (smb or nfs)'
    if [[ -n $detected ]]; then
      prompt+=" [${detected}]"
    fi
    prompt+=": "
    read -r -p "$prompt" protocol
    protocol=${protocol,,}
    if [[ -z $protocol && -n $detected ]]; then
      protocol=$detected
    fi
    if [[ $protocol == "smb" || $protocol == "nfs" ]]; then
      printf '%s\n' "$protocol"
      return
    fi
    echo "Please enter either smb or nfs."
  done
}

mount_network_share() {
  local remote="$1"
  local protocol="$2"
  local mount_point="$3"
  local options="$4"

  local fs_type
  case "$protocol" in
    smb)
      fs_type="cifs"
      ;;
    nfs)
      fs_type="nfs"
      ;;
    *)
      echo "Unsupported protocol: $protocol"
      exit 1
      ;;
  esac

  local cmd=(mount -t "$fs_type" "$remote" "$mount_point")
  if [[ -n $options ]]; then
    cmd+=(-o "$options")
  fi

  if [[ $protocol == "smb" ]]; then
    if ! command -v mount.cifs >/dev/null 2>&1; then
      echo "Warning: mount.cifs (from the cifs-utils package) was not found. Mount may fail if CIFS support is missing."
    fi
  fi

  run_with_privilege "${cmd[@]}"
}

handle_device_flow() {
  local -n mount_point_ref=$1
  local -n mounted_flag_ref=$2

  local device
  device=$(prompt_device_selection)
  SELECTED_SOURCE_DESCRIPTION="device $device"

  mapfile -t existing_targets < <(get_mount_targets_for_source "$device")
  local reuse_target=""
  if (( ${#existing_targets[@]} > 0 )); then
    reuse_target=$(choose_existing_mount "${existing_targets[@]}") || true
  fi

  if [[ -n $reuse_target ]]; then
    echo "Using existing mount point $reuse_target for $device."
    mount_point_ref=$reuse_target
    mounted_flag_ref=0
    return
  fi

  if (( ${#existing_targets[@]} > 0 )); then
    echo "The device appears to be mounted at:"
    for target in "${existing_targets[@]}"; do
      printf '  - %s\n' "$target"
    done
    echo "Ensure it is unmounted before mounting elsewhere."
  fi

  mount_point_ref=$(prompt_mount_point "/mnt/backup")
  ensure_mount_point "$mount_point_ref"

  if is_mount_point_in_use "$mount_point_ref"; then
    echo "Mount point $mount_point_ref is already in use. Choose another location or unmount it first."
    exit 1
  fi

  echo "\nAbout to mount $device at $mount_point_ref"
  mount_device "$device" "$mount_point_ref"
  mounted_flag_ref=1
}

handle_network_flow() {
  local -n mount_point_ref=$1
  local -n mounted_flag_ref=$2

  local remote=""
  while true; do
    read -r -p $'Enter the network share (e.g. //server/share or server:/export). Leave blank to exit: ' remote
    if [[ -z ${remote//[[:space:]]/} ]]; then
      echo "No network share specified. Exiting."
      exit 0
    fi
    while [[ $remote == [[:space:]]* ]]; do
      remote=${remote#?}
    done
    while [[ $remote == *[[:space:]] ]]; do
      remote=${remote%?}
    done
    if [[ -n $remote ]]; then
      break
    fi
  done

  local protocol
  protocol=$(prompt_network_protocol "$remote")
  remote=$(normalize_network_source "$remote" "$protocol")
  SELECTED_SOURCE_DESCRIPTION="network share $remote ($protocol)"

  mapfile -t existing_targets < <(get_mount_targets_for_source "$remote")
  local reuse_target=""
  if (( ${#existing_targets[@]} > 0 )); then
    reuse_target=$(choose_existing_mount "${existing_targets[@]}") || true
  fi

  if [[ -n $reuse_target ]]; then
    echo "Using existing mount point $reuse_target for $remote."
    mount_point_ref=$reuse_target
    mounted_flag_ref=0
    return
  fi

  mount_point_ref=$(prompt_mount_point "/mnt/backup")
  ensure_mount_point "$mount_point_ref"

  if is_mount_point_in_use "$mount_point_ref"; then
    echo "Mount point $mount_point_ref is already in use. Choose a different location or unmount it before continuing."
    exit 1
  fi

  echo "You can supply additional mount options (comma-separated)."
  if [[ $protocol == "smb" ]]; then
    echo "For SMB shares examples include username=USER,password=PASS,domain=DOMAIN,vers=3.0"
  else
    echo "For NFS shares examples include vers=4,soft,timeo=600"
  fi

  local default_options="rw"
  read -r -p "Mount options [$default_options]: " mount_options
  mount_options=${mount_options:-$default_options}

  mount_network_share "$remote" "$protocol" "$mount_point_ref" "$mount_options"
  mounted_flag_ref=1
}

prompt_device_selection() {
  printf '\nIdentify the drive that contains your Windows backup from the list above.\n'
  printf 'Typically it will show an NTFS filesystem, a recognizable label, or a size\n'
  printf 'that matches the external drive you used.\n\n'
  read -r -p "Enter the device path to mount (for example /dev/sdb1). Leave blank to exit: " device_path
  if [[ -z $device_path ]]; then
    echo "No device selected. Exiting without mounting."
    exit 0
  fi

  if [[ $device_path != /dev/* ]]; then
    device_path="/dev/${device_path}"
  fi

  if [[ ! -b $device_path ]]; then
    echo "Warning: $device_path is not detected as a block device."
    read -r -p "Continue anyway? [y/N]: " confirm
    if [[ ${confirm,,} != "y" ]]; then
      echo "Aborting per user request."
      exit 1
    fi
  fi

  echo "$device_path"
}

ensure_mount_point() {
  local mount_point="$1"
  if [[ -d $mount_point ]]; then
    return
  fi

  echo "Creating mount point at $mount_point"
  run_with_privilege mkdir -p "$mount_point"
}

run_with_privilege() {
  local cmd=("$@")
  if [[ $EUID -eq 0 ]]; then
    "${cmd[@]}"
    return
  fi

  if command -v sudo >/dev/null 2>&1; then
    sudo "${cmd[@]}"
  else
    echo "This action requires elevated privileges and sudo is not available."
    echo "Please rerun the script as root and try again."
    exit 1
  fi
}

mount_device() {
  local device="$1"
  local mount_point="$2"

  run_with_privilege mount "$device" "$mount_point"
}


show_help() {
  cat <<'HELP'
Usage: linux-restore-helper.sh [OPTIONS]

Locate and mount the Windows backup drive to begin the migration process.

Options:
  --version    Show version information and exit
  -h, --help   Show this help message and exit

This helper will:
  1. Detect your Linux distribution and system information
  2. Display available storage devices
  3. Guide you through mounting the backup location (local or network)
  4. Verify the backup contents
  5. Suggest next steps for data restoration

HELP
}

main() {
  # Parse command-line arguments
  for arg in "$@"; do
    case "$arg" in
      --version)
        printf 'linux-restore-helper.sh version %s\n' "$SCRIPT_VERSION"
        printf 'Part of x0dus Migration Toolkit\n'
        printf 'https://hexaxia.tech\n'
        exit 0
        ;;
      -h|--help)
        show_help
        exit 0
        ;;
      *)
        echo "Unknown option: $arg" >&2
        echo "Use --help for usage information." >&2
        exit 1
        ;;
    esac
  done

  show_banner "Locate and Mount Windows Backup"
  print_header "Linux migration helper"
  detect_distro
  report_git_status
  show_storage_overview

  local location_type
  location_type=$(prompt_backup_location_type)

  local mount_point=""
  local mounted_by_helper=0

  if [[ $location_type == "device" ]]; then
    handle_device_flow mount_point mounted_by_helper
  else
    handle_network_flow mount_point mounted_by_helper
  fi

  if [[ -n ${SELECTED_SOURCE_DESCRIPTION:-} ]]; then
    printf '\nWorking with %s.\n' "$SELECTED_SOURCE_DESCRIPTION"
  fi

  printf '\nContents of %s:\n' "$mount_point"
  if ! ls -- "$mount_point"; then
    echo "Unable to list directory contents. Check permissions and try again."
  fi

  printf '\nNext steps:\n'
  printf '  - Review the backup contents to ensure everything looks correct.\n'
  printf '  - When you are ready, run ./linux-software-inventory.sh "%s" to summarize installed applications.\n' "$mount_point"
  printf '\n'
  if [[ $mounted_by_helper -eq 1 ]]; then
    printf 'Remember to unmount when finished: '
    if [[ $EUID -eq 0 ]]; then
      printf 'umount "%s"\n' "$mount_point"
    else
      printf 'sudo umount "%s"\n' "$mount_point"
    fi
  else
    printf 'Mount point %s was already active before running this helper. Unmount it later if appropriate.\n' "$mount_point"
  fi
}

main "$@"
