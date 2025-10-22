#!/usr/bin/env bash
# linux-data-restore.sh
# Restore Windows user data into the current Linux home directory while keeping the desktop tidy.

set -euo pipefail

SCRIPT_VERSION="1.0.0.RC1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

if [[ -z ${HOME:-} ]]; then
  echo "The HOME environment variable is not set. Unable to determine where to restore data." >&2
  exit 1
fi

WORKSPACE_DIR="${HOME}/x0dus"
LOG_FILE="${WORKSPACE_DIR}/linux-data-restore.log"
SYSTEM_INFO_FILE="${WORKSPACE_DIR}/system-info.txt"
MOUNT_POINT_FILE="${WORKSPACE_DIR}/mount-point.txt"
PROFILE_RECORD_FILE="${WORKSPACE_DIR}/windows-profile-path.txt"
GIT_INFO_FILE="${WORKSPACE_DIR}/git-info.txt"
RESTORE_SUMMARY_FILE="${WORKSPACE_DIR}/restore-summary.txt"
OLD_DESKTOP_DIR="${HOME}/oldDesktop"
OLD_DESKTOP_LIST="${WORKSPACE_DIR}/old-desktop-items.txt"

DETECTED_DISTRO_NAME="Unknown"
DETECTED_DISTRO_VERSION=""
DETECTED_DISTRO_ID=""

BACKUP_ROOT=""
PROFILE_PATH=""
DRY_RUN=0
DESKTOP_PREVIEW_ONLY=0

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

usage() {
  cat <<'USAGE'
Usage: linux-data-restore.sh [OPTIONS]

Restore a Windows user profile into the current Linux home directory while
placing desktop items into ~/oldDesktop to keep the new desktop clean.

Options:
  --backup-root PATH   Path to the mounted Windows backup (contains Users/...).
  --profile PATH       Path to the specific Windows user profile to restore.
  --dry-run            Preview the copy operations without modifying files.
  --version            Show version information and exit.
  -h, --help           Show this help message and exit.
USAGE
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --backup-root)
        if [[ $# -lt 2 ]]; then
          echo "--backup-root requires a path argument." >&2
          exit 1
        fi
        BACKUP_ROOT="$2"
        shift 2
        ;;
      --profile)
        if [[ $# -lt 2 ]]; then
          echo "--profile requires a path argument." >&2
          exit 1
        fi
        PROFILE_PATH="$2"
        shift 2
        ;;
      --dry-run)
        DRY_RUN=1
        shift
        ;;
      --version)
        printf 'linux-data-restore.sh version %s\n' "$SCRIPT_VERSION"
        printf 'Part of x0dus Migration Toolkit\n'
        printf 'https://hexaxia.tech\n'
        exit 0
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "Unknown option: $1" >&2
        usage >&2
        exit 1
        ;;
    esac
  done
}

setup_workspace() {
  if [[ -e $WORKSPACE_DIR && ! -d $WORKSPACE_DIR ]]; then
    echo "$WORKSPACE_DIR exists but is not a directory. Please move or rename it before continuing." >&2
    exit 1
  fi

  if ! mkdir -p "$WORKSPACE_DIR"; then
    echo "Unable to create the workspace directory at $WORKSPACE_DIR." >&2
    exit 1
  fi

  if ! touch "$LOG_FILE"; then
    echo "Unable to create the log file at $LOG_FILE." >&2
    exit 1
  fi

  exec > >(tee -a "$LOG_FILE") 2>&1

  if ! chmod 700 "$WORKSPACE_DIR" 2>/dev/null; then
    echo "Warning: Unable to adjust permissions on $WORKSPACE_DIR. Current permissions were preserved."
  fi

  touch "$SYSTEM_INFO_FILE"

  print_header "Workspace"
  printf 'Workspace directory : %s\n' "$WORKSPACE_DIR"
  printf 'Log file            : %s\n' "$LOG_FILE"
  printf 'System info file    : %s\n' "$SYSTEM_INFO_FILE"
  printf 'Git info file       : %s\n' "$GIT_INFO_FILE"
  printf 'Restore summary     : %s\n' "$RESTORE_SUMMARY_FILE"
}

remember_path() {
  local value="$1"
  local file="$2"
  if [[ -z $value ]]; then
    rm -f "$file"
    return
  fi
  printf '%s\n' "$value" >"$file"
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
}

record_system_info() {
  local timestamp
  timestamp=$(date --iso-8601=seconds)

  {
    echo "=== linux-data-restore.sh ==="
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

  echo "System information appended to $SYSTEM_INFO_FILE"
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

  local git_info_file="$GIT_INFO_FILE"
  local -a git_lines=()
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
      repo_url="https://github.com/Hexaxia-Technologies/x0dus.git"
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
    git_lines+=("Verification command: git --version")
    local hint
    hint=$(git_install_hint)
    if [[ -n $hint ]]; then
      echo "Install Git with:"
      echo "  $hint"
      git_lines+=("Suggested install command: $hint")
    else
      echo "Consult your distribution documentation for Git installation steps."
      git_lines+=("Suggested install command: (consult distribution documentation)")
    fi
  fi

  if [[ -n $git_info_file && ${#git_lines[@]} -gt 0 ]]; then
    {
      local timestamp
      timestamp=$(date --iso-8601=seconds)
      echo "=== linux-data-restore.sh ==="
      printf 'Timestamp: %s\n' "$timestamp"
      for line in "${git_lines[@]}"; do
        printf '%s\n' "$line"
      done
      echo
    } >>"$git_info_file"

    echo "Git information recorded at $git_info_file"
  fi
}

load_backup_root() {
  if [[ -n $BACKUP_ROOT ]]; then
    return
  fi

  local remembered
  remembered=$(load_remembered_path "$MOUNT_POINT_FILE")
  if [[ -n $remembered && -d $remembered ]]; then
    BACKUP_ROOT="$remembered"
    echo "Using remembered mount point from $MOUNT_POINT_FILE: $BACKUP_ROOT"
  fi
}

prompt_for_backup_root() {
  if [[ -n $BACKUP_ROOT ]]; then
    return
  fi

  echo "Enter the path to the mounted Windows backup (for example /mnt/backup)."
  read -r -p "Backup root path: " BACKUP_ROOT

  if [[ -z $BACKUP_ROOT ]]; then
    echo "A backup root is required to continue." >&2
    exit 1
  fi
}

validate_backup_root() {
  if [[ ! -d $BACKUP_ROOT ]]; then
    echo "The backup root $BACKUP_ROOT is not a directory." >&2
    exit 1
  fi

  remember_path "$BACKUP_ROOT" "$MOUNT_POINT_FILE"
}

list_candidate_profiles() {
  local root="$1"
  local -a candidates=()

  if [[ -d "$root/Users" ]]; then
    while IFS= read -r -d '' dir; do
      candidates+=("$dir")
    done < <(find "$root/Users" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
  fi

  if [[ ${#candidates[@]} -eq 0 ]]; then
    while IFS= read -r -d '' dir; do
      candidates+=("$dir")
    done < <(find "$root" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
  fi

  printf '%s\n' "${candidates[@]}"
}

select_profile_path() {
  if [[ -n $PROFILE_PATH ]]; then
    return
  fi

  local remembered
  remembered=$(load_remembered_path "$PROFILE_RECORD_FILE")
  if [[ -n $remembered && -d $remembered ]]; then
    PROFILE_PATH="$remembered"
    echo "Using remembered Windows profile from $PROFILE_RECORD_FILE: $PROFILE_PATH"
    return
  fi

  mapfile -t candidates < <(list_candidate_profiles "$BACKUP_ROOT")

  if [[ ${#candidates[@]} -eq 1 ]]; then
    PROFILE_PATH="${candidates[0]}"
    echo "Automatically selected the only profile at: $PROFILE_PATH"
    return
  fi

  if [[ ${#candidates[@]} -gt 1 ]]; then
    print_header "Available Windows profiles"
    local idx=1
    for candidate in "${candidates[@]}"; do
      printf ' [%d] %s\n' "$idx" "$candidate"
      ((idx++))
    done
    echo
    local choice
    read -r -p "Select the profile to restore (1-${#candidates[@]}): " choice
    if [[ ! $choice =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#candidates[@]} )); then
      echo "Invalid selection." >&2
      exit 1
    fi
    PROFILE_PATH="${candidates[choice-1]}"
    return
  fi

  echo "No Windows profiles were detected automatically."
  read -r -p "Enter the path to the Windows user profile to restore: " PROFILE_PATH
}

validate_profile_path() {
  if [[ -z $PROFILE_PATH ]]; then
    echo "A Windows profile path is required." >&2
    exit 1
  fi

  if [[ ! -d $PROFILE_PATH ]]; then
    echo "The profile path $PROFILE_PATH is not a directory." >&2
    exit 1
  fi

  remember_path "$PROFILE_PATH" "$PROFILE_RECORD_FILE"
}

summarize_sizes() {
  print_header "Size summary"

  local home_size_bytes=0
  local home_size_hr=""
  if home_size_hr=$(du -sh "$HOME" 2>/dev/null | awk '{print $1}'); then
    home_size_bytes=$(du -sb "$HOME" 2>/dev/null | awk '{print $1}')
    printf 'Current home usage : %s (%s bytes)\n' "$home_size_hr" "$home_size_bytes"
  else
    echo "Unable to measure the size of $HOME."
  fi

  local profile_size_hr=""
  local profile_size_bytes=0
  if profile_size_hr=$(du -sh "$PROFILE_PATH" 2>/dev/null | awk '{print $1}'); then
    profile_size_bytes=$(du -sb "$PROFILE_PATH" 2>/dev/null | awk '{print $1}')
    printf 'Backup profile size: %s (%s bytes)\n' "$profile_size_hr" "$profile_size_bytes"
  else
    echo "Unable to measure the size of $PROFILE_PATH."
  fi

  local df_line
  if df_line=$(df -h "$HOME" 2>/dev/null | tail -n 1); then
    printf 'Home partition info: %s\n' "$df_line"
  else
    echo "Unable to determine free space for $HOME."
  fi

  if [[ $profile_size_bytes -gt 0 ]]; then
    local free_bytes
    free_bytes=$(df -B1 "$HOME" 2>/dev/null | tail -n 1 | awk '{print $4}')
    if [[ -n $free_bytes && $free_bytes -lt $profile_size_bytes ]]; then
      echo
      echo "Warning: The available space in $HOME appears smaller than the Windows profile backup." >&2
      echo "Consider cleaning up space or restoring selectively before continuing." >&2
    fi
  fi
}

ensure_old_desktop_dir() {
  if [[ -e $OLD_DESKTOP_DIR && ! -d $OLD_DESKTOP_DIR ]]; then
    echo "$OLD_DESKTOP_DIR exists but is not a directory. Please move it and rerun the script." >&2
    exit 1
  fi

  if ! mkdir -p "$OLD_DESKTOP_DIR"; then
    echo "Unable to create $OLD_DESKTOP_DIR for the restored desktop items." >&2
    exit 1
  fi
}

copy_profile_contents() {
  print_header "Restoring profile"
  echo "Source profile : $PROFILE_PATH"
  echo "Destination    : $HOME"

  if command -v rsync >/dev/null 2>&1; then
    local -a rsync_cmd=("rsync" "-a" "--info=progress2" "--exclude" "Desktop/" "--exclude" "Desktop/**")
    if (( DRY_RUN )); then
      rsync_cmd+=("--dry-run")
    fi
    rsync_cmd+=("${PROFILE_PATH}/" "${HOME}/")
    "${rsync_cmd[@]}"
  else
    echo "rsync is not available. Falling back to cp -a."
    if (( DRY_RUN )); then
      echo "cp -a (dry-run) ${PROFILE_PATH}/ -> ${HOME}/ excluding Desktop"
    else
      shopt -s dotglob nullglob
      for item in "${PROFILE_PATH}"/*; do
        local base
        base=$(basename "$item")
        if [[ $base == "Desktop" ]]; then
          continue
        fi
        cp -a "$item" "$HOME/"
      done
      shopt -u dotglob nullglob
    fi
  fi
}

restore_desktop_items() {
  local desktop_path="$PROFILE_PATH/Desktop"
  if [[ ! -d $desktop_path ]]; then
    echo "No Desktop directory found at $desktop_path."
    rm -f "$OLD_DESKTOP_LIST"
    return
  fi

  local preview_only=0

  if (( DRY_RUN )); then
    preview_only=1
    DESKTOP_PREVIEW_ONLY=1
    : >"$OLD_DESKTOP_LIST"
    {
      local timestamp
      timestamp=$(date --iso-8601=seconds)
      echo "# linux-data-restore.sh dry run"
      printf '# Timestamp: %s\n' "$timestamp"
      printf '# Items that would be copied to %s\n' "$OLD_DESKTOP_DIR"
      echo
    } >>"$OLD_DESKTOP_LIST"
    echo "Dry run enabled; desktop items will not be copied."
  else
    ensure_old_desktop_dir
    : >"$OLD_DESKTOP_LIST"
    DESKTOP_PREVIEW_ONLY=0
  fi

  print_header "Desktop contents"
  echo "Windows desktop source : $desktop_path"
  echo "Restore target         : $OLD_DESKTOP_DIR"
  if (( preview_only )); then
    echo "Mode                  : dry run (preview only)"
  fi

  local has_items=0
  while IFS= read -r -d '' item; do
    has_items=1
    local base
    base=$(basename "$item")
    echo " - $base"
    if (( preview_only )); then
      echo "   (dry-run) Would copy to $OLD_DESKTOP_DIR/"
    else
      if command -v rsync >/dev/null 2>&1; then
        local -a rsync_cmd=("rsync" "-a" "--info=progress2")
        rsync_cmd+=("$item" "$OLD_DESKTOP_DIR/")
        "${rsync_cmd[@]}"
      else
        cp -a "$item" "$OLD_DESKTOP_DIR/"
      fi
    fi
    printf '%s\n' "$base" >>"$OLD_DESKTOP_LIST"
  done < <(find "$desktop_path" -mindepth 1 -maxdepth 1 ! -iname '*.lnk' -print0 | sort -z)

  if (( ! has_items )); then
    echo "No non-shortcut items were found on the Windows desktop."
  else
    if (( preview_only )); then
      echo "Desktop preview saved to $OLD_DESKTOP_LIST"
    else
      echo "Non-shortcut desktop items recorded at $OLD_DESKTOP_LIST"
    fi
  fi

  local shortcut_count
  shortcut_count=$(find "$desktop_path" -mindepth 1 -maxdepth 1 -iname '*.lnk' -print | wc -l | tr -d ' ')
  if [[ $shortcut_count -gt 0 ]]; then
    echo "Skipped $shortcut_count Windows shortcut file(s)."
  fi
}

write_restore_summary() {
  local timestamp
  timestamp=$(date --iso-8601=seconds)

  {
    echo "=== linux-data-restore.sh ==="
    printf 'Timestamp      : %s\n' "$timestamp"
    printf 'Backup root    : %s\n' "$BACKUP_ROOT"
    printf 'Profile source : %s\n' "$PROFILE_PATH"
    printf 'Destination    : %s\n' "$HOME"
    printf 'Desktop folder : %s\n' "$OLD_DESKTOP_DIR"
    if (( DESKTOP_PREVIEW_ONLY )); then
      printf 'Desktop handling: preview only (dry run)\n'
    fi
    printf 'Dry run        : %s\n' "$((DRY_RUN ? 1 : 0))"
    if [[ -f $OLD_DESKTOP_LIST ]]; then
      printf 'Desktop list   : %s\n' "$OLD_DESKTOP_LIST"
    fi
    echo
  } >>"$RESTORE_SUMMARY_FILE"

  echo "Restore summary saved to $RESTORE_SUMMARY_FILE"
}

main() {
  parse_args "$@"
  show_banner "Import Windows Profile to Linux"
  setup_workspace
  detect_distro
  record_system_info
  report_git_status
  load_backup_root
  if [[ -z $BACKUP_ROOT ]]; then
    prompt_for_backup_root
  fi
  validate_backup_root
  select_profile_path
  validate_profile_path
  summarize_sizes
  copy_profile_contents
  restore_desktop_items
  write_restore_summary
  echo
  echo "Restore complete. Review $RESTORE_SUMMARY_FILE for a log of the operation."
}

main "$@"
