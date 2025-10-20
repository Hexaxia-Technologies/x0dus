#!/usr/bin/env bash
# linux-software-inventory.sh
# Summarize Windows software inventory data from a mounted backup.

set -euo pipefail

SCRIPT_VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

if [[ -z ${HOME:-} ]]; then
  echo "The HOME environment variable is not set. Unable to determine where to store helper data." >&2
  exit 1
fi

WORKSPACE_DIR="${HOME}/x0dus"
LOG_FILE="${WORKSPACE_DIR}/linux-software-inventory.log"
SYSTEM_INFO_FILE="${WORKSPACE_DIR}/system-info.txt"
MOUNT_POINT_FILE="${WORKSPACE_DIR}/mount-point.txt"
INVENTORY_FILE_RECORD="${WORKSPACE_DIR}/installed-software-inventory-path.txt"
SOFTWARE_LIST_RECORD="${WORKSPACE_DIR}/installed-software-names-path.txt"
SOFTWARE_LIST_LATEST="${WORKSPACE_DIR}/installed-software-names-latest.txt"
GIT_INFO_FILE="${WORKSPACE_DIR}/git-info.txt"

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
                   =====================
                 =========================
               =============================
             =================================
            ===================================
           =====================================
          ===+===+===+===+===+===+===+===+===+===
         ===+===+===+===+===+===+===+===+===+===+
        ===+===+===+===+===+===+===+===+===+===+===
       ===+===+===+===+===+===+===+===+===+===+===+=
       ===+===+===+===+===+===+===+===+===+===+===+=
      ===+===+===+===+===+===+===+===+===+===+===+==
      ===+===+===+===+===+===+===+===+===+===+===+==
      ===+===+===+===+===+===+===+===+===+===+===+==
       ===+===+===+===+===+===+===+===+===+===+===+=
       ===+===+===+===+===+===+===+===+===+===+===+=
        ===+===+===+===+===+===+===+===+===+===+===
         ===+===+===+===+===+===+===+===+===+===+
          ===+===+===+===+===+===+===+===+===+===
           =====================================
            ===================================
             =================================
               =============================
                 =========================
                   =====================
                      ==============
                         =======
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

show_help() {
  cat <<'HELP'
Usage: linux-software-inventory.sh [PATH] [OPTIONS]

Summarize the Windows software inventory to assist with reinstalling
applications on Linux.

Arguments:
  PATH          Path to the mounted backup (default: /mnt/backup or remembered path)

Options:
  --version     Show version information and exit
  -h, --help    Show this help message and exit

This helper will:
  1. Locate the installed-software.csv file from the Windows backup
  2. Extract unique application names
  3. Provide package manager commands for your distribution
  4. Save the simplified list to ~/x0dus/ for reference

HELP
}

print_header() {
  local title="$1"
  local underline
  underline=$(printf '%*s' "${#title}" '')
  underline=${underline// /-}
  printf '\n%s\n%s\n' "$title" "$underline"
}

setup_workspace() {
  if [[ -e $WORKSPACE_DIR && ! -d $WORKSPACE_DIR ]]; then
    echo "$WORKSPACE_DIR exists but is not a directory. Please move or rename the existing file before continuing." >&2
    exit 1
  fi

  if ! mkdir -p "$WORKSPACE_DIR"; then
    echo "Unable to create the workspace directory at $WORKSPACE_DIR." >&2
    exit 1
  fi

  # Prepare log and metadata files before redirecting output so we can report failures cleanly.
  if ! touch "$LOG_FILE"; then
    echo "Unable to create the log file at $LOG_FILE." >&2
    exit 1
  fi

  exec > >(tee -a "$LOG_FILE") 2>&1

  if ! chmod 700 "$WORKSPACE_DIR" 2>/dev/null; then
    echo "Warning: Unable to set permissions on $WORKSPACE_DIR. Current permissions have been preserved."
  fi

  # Ensure a placeholder exists for system information that other helpers can append to.
  touch "$SYSTEM_INFO_FILE"

  print_header "Workspace"
  printf 'Workspace directory : %s\n' "$WORKSPACE_DIR"
  printf 'Log file            : %s\n' "$LOG_FILE"
  printf 'System info file    : %s\n' "$SYSTEM_INFO_FILE"
  printf 'Git info file       : %s\n' "$GIT_INFO_FILE"
}

record_system_info() {
  local timestamp
  timestamp=$(date --iso-8601=seconds)

  {
    echo "=== linux-software-inventory.sh ==="
    printf 'Timestamp           : %s\n' "$timestamp"
    printf 'Distribution name   : %s\n' "$DETECTED_DISTRO_NAME"
    if [[ -n $DETECTED_DISTRO_VERSION ]]; then
      printf 'Distribution version: %s\n' "$DETECTED_DISTRO_VERSION"
    fi
    if [[ -n $DETECTED_DISTRO_ID ]]; then
      printf 'Distribution ID     : %s\n' "$DETECTED_DISTRO_ID"
    fi
    printf 'Kernel              : %s\n' "$(uname -sr)"
    printf 'Current user        : %s\n' "$(whoami)"
    echo
  } >>"$SYSTEM_INFO_FILE"

  echo "System information recorded at $SYSTEM_INFO_FILE"
}

remember_path() {
  local value="$1"
  local file="$2"
  local label="$3"

  if [[ -z $value ]]; then
    rm -f "$file"
    return
  fi

  printf '%s\n' "$value" >"$file"
  if [[ -n $label ]]; then
    printf '%s saved to %s\n' "$label" "$file"
  fi
}

load_remembered_path() {
  local file="$1"

  if [[ -f $file ]]; then
    local value=""
    IFS= read -r value <"$file" || value=""
    printf '%s\n' "$value"
  fi
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
    DETECTED_DISTRO_ID=$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]' | awk '{print $1}')
  fi

  print_header "Linux environment"
  printf 'Detected distribution : %s\n' "$DETECTED_DISTRO_NAME"
  if [[ -n $DETECTED_DISTRO_VERSION ]]; then
    printf 'Version              : %s\n' "$DETECTED_DISTRO_VERSION"
  fi
  if [[ -n $DETECTED_DISTRO_ID ]]; then
    printf 'Distribution ID      : %s\n' "$DETECTED_DISTRO_ID"
  fi
  printf 'Kernel               : %s\n' "$(uname -sr)"
  printf 'Current user         : %s\n' "$(whoami)"

  record_system_info
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

capture_git_environment() {
  print_header "Git availability"

  local -a git_lines=()
  if ! : >"$GIT_INFO_FILE"; then
    echo "Warning: Unable to write Git information to $GIT_INFO_FILE."
    GIT_INFO_FILE=""
  fi

  local repo_root=""
  local repo_url=""

  if command -v git >/dev/null 2>&1; then
    local git_version
    git_version=$(git --version 2>/dev/null || echo "git")
    echo "Git command found: $git_version"
    git_lines+=("Git available: yes")
    git_lines+=("Git version: $git_version")
    git_lines+=("Verification command: git --version")

    if git -C "$SCRIPT_DIR" rev-parse --show-toplevel >/dev/null 2>&1; then
      repo_root=$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)
      echo "Script directory belongs to Git working tree: $repo_root"
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
      echo "Use the following to update the helpers:"
      echo "  cd \"$repo_root\""
      echo "  git pull"
      git_lines+=("Update command: cd \"$repo_root\" && git pull")
    else
      if [[ -n ${HOME:-} ]]; then
        repo_root="${HOME}/x0dus"
      else
        repo_root="${PWD}/x0dus"
      fi
      repo_url="https://github.com/your-account/x0dus.git"
      echo "These helpers are not running from a Git repository."
      echo "Clone them to your home directory with:"
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

  if [[ -n $GIT_INFO_FILE && ${#git_lines[@]} -gt 0 ]]; then
    printf '%s\n' "${git_lines[@]}" >"$GIT_INFO_FILE"
    echo "Git information saved to $GIT_INFO_FILE"
  fi
}

resolve_mount_point() {
  local initial="$1"
  local path="$initial"

  local remembered_default=""
  remembered_default=$(load_remembered_path "$MOUNT_POINT_FILE")

  if [[ -n $path ]]; then
    if [[ -d $path ]]; then
      remember_path "$path" "$MOUNT_POINT_FILE" "Mount point"
      printf '%s\n' "$path"
      return 0
    fi
    echo "Provided path $path is not a directory."
  fi

  local default="/mnt/backup"
  if [[ -n $initial ]]; then
    default="$initial"
  elif [[ -n $remembered_default ]]; then
    default="$remembered_default"
  fi

  while true; do
    read -r -p "Enter the path to the mounted Windows backup [${default}]: " path
    path=${path:-$default}
    if [[ -z $path ]]; then
      echo "A path is required to continue."
      continue
    fi
    if [[ ! -d $path ]]; then
      echo "$path does not exist or is not a directory."
      continue
    fi
    remember_path "$path" "$MOUNT_POINT_FILE" "Mount point"
    printf '%s\n' "$path"
    return 0
  done
}

find_installed_software_inventory() {
  local base="$1"
  if [[ -z $base || ! -d $base ]]; then
    return 1
  fi

  local -a candidates=()
  declare -A seen=()

  local direct="$base/installed-software.csv"
  if [[ -f $direct ]]; then
    candidates+=("$direct")
    seen["$direct"]=1
  fi

  while IFS= read -r -d '' path; do
    if [[ -z ${seen["$path"]:-} ]]; then
      candidates+=("$path")
      seen["$path"]=1
    fi
  done < <(find "$base" -maxdepth 4 -type f -name 'installed-software.csv' -print0 2>/dev/null)

  local count=${#candidates[@]}
  if (( count == 0 )); then
    return 1
  fi

  if (( count == 1 )); then
    printf '%s\n' "${candidates[0]}"
    return 0
  fi

  echo "Multiple inventory files were found:"
  local i
  for ((i = 0; i < count; i++)); do
    printf '  [%d] %s\n' "$((i + 1))" "${candidates[i]}"
  done

  while true; do
    read -r -p "Select the inventory file to use [1]: " selection
    selection=${selection:-1}
    if [[ $selection =~ ^[0-9]+$ ]] && (( selection >= 1 && selection <= count )); then
      printf '%s\n' "${candidates[selection - 1]}"
      return 0
    fi
    echo "Invalid selection. Please enter a number between 1 and $count."
  done
}

extract_software_names() {
  local csv_path="$1"
  if [[ -z $csv_path || ! -f $csv_path ]]; then
    return 1
  fi

  if ! command -v python3 >/dev/null 2>&1; then
    echo "Python 3 is required to parse the inventory automatically."
    echo "You can open $csv_path manually to review the data."
    return 1
  fi

  python3 - "$csv_path" <<'PY'
import csv
import sys

csv_path = sys.argv[1]

names = set()
try:
    with open(csv_path, newline='', encoding='utf-8-sig') as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            value = (row.get('DisplayName') or '').strip()
            if value:
                names.add(value)
except FileNotFoundError:
    sys.exit(1)

for entry in sorted(names, key=str.casefold):
    print(entry)
PY
}

print_package_manager_guidance() {
  local reference_file="$1"
  local count="$2"

  local pm=""
  local update_hint=""
  local install_hint=""
  local search_hint=""

  case "$DETECTED_DISTRO_ID" in
    ubuntu|debian|linuxmint|pop|elementary|zorin|kubuntu|lubuntu|xubuntu|neon|mx|deepin|raspbian|peppermint)
      pm="APT"
      update_hint="sudo apt update"
      install_hint="sudo apt install <package>"
      search_hint="apt search <term>"
      ;;
    fedora|rhel|centos|rocky|almalinux|oracle)
      pm="DNF"
      update_hint="sudo dnf makecache"
      install_hint="sudo dnf install <package>"
      search_hint="dnf search <term>"
      ;;
    arch|manjaro|endeavouros|garuda)
      pm="pacman"
      update_hint="sudo pacman -Syu"
      install_hint="sudo pacman -S <package>"
      search_hint="pacman -Ss <term>"
      ;;
    opensuse*|sles|sled)
      pm="zypper"
      update_hint="sudo zypper refresh"
      install_hint="sudo zypper install <package>"
      search_hint="zypper search <term>"
      ;;
    *)
      if command -v apt >/dev/null 2>&1; then
        pm="APT"
        update_hint="sudo apt update"
        install_hint="sudo apt install <package>"
        search_hint="apt search <term>"
      elif command -v dnf >/dev/null 2>&1; then
        pm="DNF"
        update_hint="sudo dnf makecache"
        install_hint="sudo dnf install <package>"
        search_hint="dnf search <term>"
      elif command -v yum >/dev/null 2>&1; then
        pm="YUM"
        update_hint="sudo yum makecache"
        install_hint="sudo yum install <package>"
        search_hint="yum search <term>"
      elif command -v pacman >/dev/null 2>&1; then
        pm="pacman"
        update_hint="sudo pacman -Syu"
        install_hint="sudo pacman -S <package>"
        search_hint="pacman -Ss <term>"
      elif command -v zypper >/dev/null 2>&1; then
        pm="zypper"
        update_hint="sudo zypper refresh"
        install_hint="sudo zypper install <package>"
        search_hint="zypper search <term>"
      elif command -v emerge >/dev/null 2>&1; then
        pm="emerge"
        update_hint="sudo emerge --sync"
        install_hint="sudo emerge <package>"
        search_hint="equery list <term>"
      elif command -v xbps-install >/dev/null 2>&1; then
        pm="XBPS"
        update_hint="sudo xbps-install -S"
        install_hint="sudo xbps-install <package>"
        search_hint="xbps-query -Rs <term>"
      fi
  esac

  if [[ -z $pm ]]; then
    echo "Unable to determine an appropriate package manager for ${DETECTED_DISTRO_NAME}."
    echo "Review $(basename "$reference_file") manually and consult your distribution's documentation."
    return
  fi

  print_header "Package reinstall helpers"
  echo "Detected package manager guidance : $pm"
  if [[ -n $update_hint ]]; then
    printf 'Update package index: %s\n' "$update_hint"
  fi
  printf 'Install a package   : %s\n' "$install_hint"
  if [[ -n $search_hint ]]; then
    printf 'Search for packages : %s\n' "$search_hint"
  fi
  printf '\nUse the names from %s when searching for Linux equivalents.\n' "$(basename "$reference_file")"
  if [[ $pm == "APT" ]]; then
    echo "Tip: Ubuntu- and Debian-based systems also provide snap and flatpak as alternative sources for some applications."
  fi
  if (( count > 0 )); then
    echo "Consider marking each program you reinstall to track progress."
  fi
}

process_software_inventory() {
  local mount_point="$1"
  print_header "Windows software inventory review"

  local inventory_file
  if ! inventory_file=$(find_installed_software_inventory "$mount_point"); then
    echo "No installed-software.csv file was found under $mount_point."
    echo "Ensure you ran the Windows backup with the software inventory option enabled."
    return
  fi

  echo "Using inventory file: $inventory_file"
  remember_path "$inventory_file" "$INVENTORY_FILE_RECORD" "Inventory file location"
  if [[ ! -s $inventory_file ]]; then
    echo "The inventory file is empty. Inspect it manually to confirm its contents."
    return
  fi

  local timestamp
  timestamp=$(date +%Y%m%d-%H%M%S)
  local output_file="${WORKSPACE_DIR}/installed-software-names-${timestamp}.txt"

  if extract_software_names "$inventory_file" >"$output_file"; then
    local count
    count=$(wc -l <"$output_file")
    echo "Extracted $count unique application names."
    if (( count > 0 )); then
      local sample=$(( count < 15 ? count : 15 ))
      echo "Sample entries:"
      head -n "$sample" "$output_file" | sed 's/^/  - /'
      if (( count > sample )); then
        echo "  ..."
      fi
    fi
    echo "Saved the simplified list to $output_file"
    remember_path "$output_file" "$SOFTWARE_LIST_RECORD" "Simplified software list"
    cp "$output_file" "$SOFTWARE_LIST_LATEST"
    echo "A copy of the latest list is available at $SOFTWARE_LIST_LATEST"
    print_package_manager_guidance "$output_file" "$count"
  else
    rm -f "$output_file"
    echo "Unable to parse $inventory_file automatically."
    echo "Open the CSV manually to review the data and plan reinstalls."
  fi
}

main() {
  # Parse command-line arguments
  local mount_arg=""
  for arg in "$@"; do
    case "$arg" in
      --version)
        printf 'linux-software-inventory.sh version %s\n' "$SCRIPT_VERSION"
        printf 'Part of x0dus Migration Toolkit\n'
        printf 'https://hexaxia.tech\n'
        exit 0
        ;;
      -h|--help)
        show_help
        exit 0
        ;;
      -*)
        echo "Unknown option: $arg" >&2
        echo "Use --help for usage information." >&2
        exit 1
        ;;
      *)
        mount_arg="$arg"
        ;;
    esac
  done

  show_banner "Windows App Reinstall Guide"
  setup_workspace
  detect_distro
  capture_git_environment
  local mount_point
  mount_point=$(resolve_mount_point "$mount_arg")
  printf '\nWorking with backup contents at: %s\n' "$mount_point"
  process_software_inventory "$mount_point"
}

main "$@"
