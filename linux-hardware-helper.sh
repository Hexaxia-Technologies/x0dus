#!/usr/bin/env bash
# linux-hardware-helper.sh
# Analyze Windows hardware inventory and provide Linux driver compatibility guidance.

set -euo pipefail

SCRIPT_VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

if [[ -z ${HOME:-} ]]; then
  echo "The HOME environment variable is not set. Unable to determine workspace location." >&2
  exit 1
fi

WORKSPACE_DIR="${HOME}/x0dus"
LOG_FILE="${WORKSPACE_DIR}/linux-hardware-helper.log"
SYSTEM_INFO_FILE="${WORKSPACE_DIR}/system-info.txt"
MOUNT_POINT_FILE="${WORKSPACE_DIR}/mount-point.txt"
HARDWARE_INVENTORY_RECORD="${WORKSPACE_DIR}/hardware-inventory-path.txt"
HARDWARE_REPORT_FILE="${WORKSPACE_DIR}/hardware-compatibility-report.txt"
GIT_INFO_FILE="${WORKSPACE_DIR}/git-info.txt"

DETECTED_DISTRO_NAME="Unknown"
DETECTED_DISTRO_VERSION=""
DETECTED_DISTRO_ID=""

# ANSI color codes
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RESET='\033[0m'

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
Usage: linux-hardware-helper.sh [PATH] [OPTIONS]

Analyze Windows hardware inventory and provide Linux driver compatibility
guidance for your migration.

Arguments:
  PATH          Path to the mounted backup (default: remembered path or /mnt/backup)

Options:
  --version     Show version information and exit
  -h, --help    Show this help message and exit

This helper will:
  1. Locate the hardware-inventory.csv file from the Windows backup
  2. Analyze hardware for known Linux compatibility issues
  3. Identify devices that may need proprietary drivers
  4. Provide distro-specific installation commands
  5. Check if drivers are already installed on your system
  6. Generate a compatibility report saved to ~/x0dus/

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
  printf 'Workspace directory    : %s\n' "$WORKSPACE_DIR"
  printf 'Log file               : %s\n' "$LOG_FILE"
  printf 'Compatibility report   : %s\n' "$HARDWARE_REPORT_FILE"
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

resolve_mount_point() {
  local initial="$1"
  local path="$initial"

  local remembered_default=""
  remembered_default=$(load_remembered_path "$MOUNT_POINT_FILE")

  if [[ -n $path ]]; then
    if [[ -d $path ]]; then
      remember_path "$path" "$MOUNT_POINT_FILE"
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
    remember_path "$path" "$MOUNT_POINT_FILE"
    printf '%s\n' "$path"
    return 0
  done
}

find_hardware_inventory() {
  local base="$1"
  if [[ -z $base || ! -d $base ]]; then
    return 1
  fi

  local -a candidates=()
  local direct="$base/hardware-inventory.csv"
  if [[ -f $direct ]]; then
    candidates+=("$direct")
  fi

  while IFS= read -r -d '' path; do
    local found=0
    for existing in "${candidates[@]}"; do
      if [[ $path == "$existing" ]]; then
        found=1
        break
      fi
    done
    if [[ $found -eq 0 ]]; then
      candidates+=("$path")
    fi
  done < <(find "$base" -maxdepth 4 -type f -name 'hardware-inventory.csv' -print0 2>/dev/null)

  local count=${#candidates[@]}
  if (( count == 0 )); then
    return 1
  fi

  if (( count == 1 )); then
    printf '%s\n' "${candidates[0]}"
    return 0
  fi

  echo "Multiple hardware inventory files were found:"
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

check_driver_loaded() {
  local driver_name="$1"
  if lsmod | grep -q "^${driver_name}"; then
    return 0
  fi
  return 1
}

check_package_installed() {
  local package="$1"

  if command -v dpkg >/dev/null 2>&1; then
    dpkg -l "$package" 2>/dev/null | grep -q "^ii"
    return $?
  elif command -v rpm >/dev/null 2>&1; then
    rpm -q "$package" >/dev/null 2>&1
    return $?
  elif command -v pacman >/dev/null 2>&1; then
    pacman -Q "$package" >/dev/null 2>&1
    return $?
  fi
  return 1
}

get_driver_install_command() {
  local driver_type="$1"
  local commands=""

  case "$DETECTED_DISTRO_ID" in
    ubuntu|debian|linuxmint|pop|elementary|zorin|kubuntu|lubuntu|xubuntu|neon|mx|deepin|raspbian|peppermint)
      case "$driver_type" in
        nvidia)
          commands="sudo ubuntu-drivers autoinstall\n# Or manually:\nsudo apt update\nsudo apt install nvidia-driver-XXX  # Replace XXX with version"
          ;;
        amd)
          commands="# AMDGPU driver is usually built-in to kernel\n# If needed:\nsudo apt update\nsudo apt install firmware-amd-graphics mesa-vulkan-drivers"
          ;;
        broadcom-wifi)
          commands="sudo apt update\nsudo apt install broadcom-sta-dkms\n# Or for older cards:\nsudo apt install firmware-b43-installer"
          ;;
        intel-wifi)
          commands="sudo apt update\nsudo apt install firmware-iwlwifi\nsudo modprobe -r iwlwifi && sudo modprobe iwlwifi"
          ;;
        realtek-net)
          commands="sudo apt update\nsudo apt install r8168-dkms\n# Blacklist r8169 if needed:\necho 'blacklist r8169' | sudo tee /etc/modprobe.d/blacklist-r8169.conf"
          ;;
      esac
      ;;
    fedora|rhel|centos|rocky|almalinux|oracle)
      case "$driver_type" in
        nvidia)
          commands="sudo dnf install akmod-nvidia\n# Or for newer cards:\nsudo dnf install xorg-x11-drv-nvidia"
          ;;
        amd)
          commands="# AMDGPU driver is usually built-in to kernel\n# Mesa drivers:\nsudo dnf install mesa-vulkan-drivers mesa-dri-drivers"
          ;;
        broadcom-wifi)
          commands="sudo dnf install broadcom-wl\n# May require enabling RPM Fusion repository"
          ;;
        intel-wifi)
          commands="sudo dnf install iwl*-firmware\nsudo modprobe -r iwlwifi && sudo modprobe iwlwifi"
          ;;
        realtek-net)
          commands="sudo dnf install kmod-r8168\n# From ELRepo or RPM Fusion"
          ;;
      esac
      ;;
    arch|manjaro|endeavouros|garuda)
      case "$driver_type" in
        nvidia)
          commands="sudo pacman -S nvidia nvidia-utils\n# For LTS kernel:\nsudo pacman -S nvidia-lts"
          ;;
        amd)
          commands="# AMDGPU driver is usually built-in\n# Mesa drivers:\nsudo pacman -S mesa vulkan-radeon"
          ;;
        broadcom-wifi)
          commands="sudo pacman -S broadcom-wl-dkms\n# Or from AUR:\nyay -S broadcom-wl"
          ;;
        intel-wifi)
          commands="sudo pacman -S linux-firmware\n# Firmware is usually included"
          ;;
        realtek-net)
          commands="sudo pacman -S r8168\n# Blacklist r8169:\necho 'blacklist r8169' | sudo tee /etc/modprobe.d/blacklist-r8169.conf"
          ;;
      esac
      ;;
    *)
      commands="# Consult your distribution documentation for $driver_type driver installation"
      ;;
  esac

  printf '%b\n' "$commands"
}

analyze_gpu() {
  local csv_file="$1"
  local report_file="$2"

  print_header "Graphics Processing Unit (GPU) Analysis"

  local -a nvidia_gpus=()
  local -a amd_gpus=()
  local -a intel_gpus=()

  while IFS=',' read -r category name manufacturer model device_id driver status location additional; do
    if [[ $category == "Graphics" || $category == "Display" ]]; then
      name=$(echo "$name" | tr -d '"' | xargs)
      manufacturer=$(echo "$manufacturer" | tr -d '"' | xargs)

      if [[ $manufacturer =~ NVIDIA|nvidia ]]; then
        nvidia_gpus+=("$name")
      elif [[ $manufacturer =~ AMD|ATI|Advanced\ Micro\ Devices ]]; then
        amd_gpus+=("$name")
      elif [[ $manufacturer =~ Intel ]]; then
        intel_gpus+=("$name")
      fi
    fi
  done < <(tail -n +2 "$csv_file")  # Skip header row

  if [[ ${#nvidia_gpus[@]} -gt 0 ]]; then
    printf "${YELLOW}⚠ NVIDIA GPU(s) detected:${RESET}\n"
    for gpu in "${nvidia_gpus[@]}"; do
      printf "  - %s\n" "$gpu"
    done
    echo ""
    echo "NVIDIA GPUs typically require proprietary drivers for best performance."

    if check_driver_loaded "nvidia"; then
      printf "${GREEN}✓ NVIDIA driver is already loaded${RESET}\n"
    else
      printf "${YELLOW}⚠ NVIDIA driver not detected${RESET}\n"
      echo ""
      echo "Installation commands:"
      get_driver_install_command "nvidia"
    fi

    {
      echo "=== GPU: NVIDIA ==="
      printf 'Status: Requires proprietary driver\n'
      for gpu in "${nvidia_gpus[@]}"; do
        printf 'Device: %s\n' "$gpu"
      done
      get_driver_install_command "nvidia"
      echo ""
    } >> "$report_file"
    echo ""
  fi

  if [[ ${#amd_gpus[@]} -gt 0 ]]; then
    printf "${YELLOW}⚠ AMD GPU(s) detected:${RESET}\n"
    for gpu in "${amd_gpus[@]}"; do
      printf "  - %s\n" "$gpu"
    done
    echo ""
    echo "AMD GPUs use the open-source AMDGPU driver (usually built-in)."
    echo "Mesa drivers provide Vulkan and OpenGL support."

    if check_driver_loaded "amdgpu"; then
      printf "${GREEN}✓ AMDGPU driver is already loaded${RESET}\n"
    else
      printf "${YELLOW}⚠ AMDGPU driver not detected (may be called 'radeon' for older cards)${RESET}\n"
      echo ""
      echo "Installation commands for Mesa drivers:"
      get_driver_install_command "amd"
    fi

    {
      echo "=== GPU: AMD ==="
      printf 'Status: Open-source driver (AMDGPU) usually built-in\n'
      for gpu in "${amd_gpus[@]}"; do
        printf 'Device: %s\n' "$gpu"
      done
      get_driver_install_command "amd"
      echo ""
    } >> "$report_file"
    echo ""
  fi

  if [[ ${#intel_gpus[@]} -gt 0 ]]; then
    printf "${GREEN}✓ Intel GPU(s) detected:${RESET}\n"
    for gpu in "${intel_gpus[@]}"; do
      printf "  - %s\n" "$gpu"
    done
    echo ""
    echo "Intel integrated graphics have excellent open-source driver support."
    echo "Drivers are typically included in the kernel and work out-of-the-box."

    {
      echo "=== GPU: Intel ==="
      printf 'Status: Excellent Linux support (open-source drivers built-in)\n'
      for gpu in "${intel_gpus[@]}"; do
        printf 'Device: %s\n' "$gpu"
      done
      echo ""
    } >> "$report_file"
    echo ""
  fi

  if [[ ${#nvidia_gpus[@]} -eq 0 && ${#amd_gpus[@]} -eq 0 && ${#intel_gpus[@]} -eq 0 ]]; then
    printf "${GREEN}✓ No discrete GPUs requiring special attention detected${RESET}\n\n"
  fi
}

analyze_network() {
  local csv_file="$1"
  local report_file="$2"

  print_header "Network Adapter Analysis"

  local -a broadcom_wifi=()
  local -a intel_wifi=()
  local -a realtek_net=()
  local -a other_net=()

  while IFS=',' read -r category name manufacturer model device_id driver status location additional; do
    if [[ $category == "Network" ]]; then
      name=$(echo "$name" | tr -d '"' | xargs)
      manufacturer=$(echo "$manufacturer" | tr -d '"' | xargs)

      if [[ $manufacturer =~ Broadcom ]] && [[ $name =~ Wi-Fi|Wireless|802.11 ]]; then
        broadcom_wifi+=("$name")
      elif [[ $manufacturer =~ Intel ]] && [[ $name =~ Wi-Fi|Wireless|802.11 ]]; then
        intel_wifi+=("$name")
      elif [[ $manufacturer =~ Realtek ]]; then
        realtek_net+=("$name")
      else
        other_net+=("$name")
      fi
    fi
  done < <(tail -n +2 "$csv_file")

  if [[ ${#broadcom_wifi[@]} -gt 0 ]]; then
    printf "${YELLOW}⚠ Broadcom Wi-Fi adapter(s) detected:${RESET}\n"
    for adapter in "${broadcom_wifi[@]}"; do
      printf "  - %s\n" "$adapter"
    done
    echo ""
    echo "Broadcom Wi-Fi cards often require proprietary firmware."
    echo ""
    echo "Installation commands:"
    get_driver_install_command "broadcom-wifi"

    {
      echo "=== Network: Broadcom Wi-Fi ==="
      printf 'Status: May require proprietary firmware\n'
      for adapter in "${broadcom_wifi[@]}"; do
        printf 'Device: %s\n' "$adapter"
      done
      get_driver_install_command "broadcom-wifi"
      echo ""
    } >> "$report_file"
    echo ""
  fi

  if [[ ${#intel_wifi[@]} -gt 0 ]]; then
    printf "${GREEN}✓ Intel Wi-Fi adapter(s) detected:${RESET}\n"
    for adapter in "${intel_wifi[@]}"; do
      printf "  - %s\n" "$adapter"
    done
    echo ""
    echo "Intel Wi-Fi cards have good Linux support with iwlwifi driver."
    echo "Firmware is usually included in linux-firmware package."

    if ! check_driver_loaded "iwlwifi"; then
      echo ""
      echo "If Wi-Fi isn't working, install firmware:"
      get_driver_install_command "intel-wifi"
    fi

    {
      echo "=== Network: Intel Wi-Fi ==="
      printf 'Status: Good Linux support (iwlwifi driver)\n'
      for adapter in "${intel_wifi[@]}"; do
        printf 'Device: %s\n' "$adapter"
      done
      echo ""
    } >> "$report_file"
    echo ""
  fi

  if [[ ${#realtek_net[@]} -gt 0 ]]; then
    printf "${YELLOW}⚠ Realtek network adapter(s) detected:${RESET}\n"
    for adapter in "${realtek_net[@]}"; do
      printf "  - %s\n" "$adapter"
    done
    echo ""
    echo "Some Realtek adapters work better with r8168 driver instead of r8169."
    echo "If you experience network issues, try:"
    get_driver_install_command "realtek-net"

    {
      echo "=== Network: Realtek ==="
      printf 'Status: May need r8168 driver for optimal performance\n'
      for adapter in "${realtek_net[@]}"; do
        printf 'Device: %s\n' "$adapter"
      done
      get_driver_install_command "realtek-net"
      echo ""
    } >> "$report_file"
    echo ""
  fi

  if [[ ${#other_net[@]} -gt 0 ]]; then
    printf "${GREEN}✓ Other network adapter(s):${RESET}\n"
    for adapter in "${other_net[@]}"; do
      printf "  - %s\n" "$adapter"
    done
    echo "These adapters typically have good Linux support."
    echo ""
  fi
}

analyze_audio() {
  local csv_file="$1"
  local report_file="$2"

  print_header "Audio Device Analysis"

  local -a audio_devices=()

  while IFS=',' read -r category name manufacturer model device_id driver status location additional; do
    if [[ $category == "Audio" || $category == "Sound" ]]; then
      name=$(echo "$name" | tr -d '"' | xargs)
      audio_devices+=("$name")
    fi
  done < <(tail -n +2 "$csv_file")

  if [[ ${#audio_devices[@]} -gt 0 ]]; then
    printf "${GREEN}✓ Audio device(s) detected:${RESET}\n"
    for device in "${audio_devices[@]}"; do
      printf "  - %s\n" "$device"
    done
    echo ""
    echo "Most audio devices work out-of-the-box with ALSA/PulseAudio/PipeWire."
    echo "If audio doesn't work, check your desktop environment's sound settings."

    {
      echo "=== Audio Devices ==="
      printf 'Status: Usually work out-of-the-box\n'
      for device in "${audio_devices[@]}"; do
        printf 'Device: %s\n' "$device"
      done
      echo ""
    } >> "$report_file"
    echo ""
  else
    printf "${GREEN}✓ No audio devices found in inventory (may use built-in motherboard audio)${RESET}\n\n"
  fi
}

analyze_usb() {
  local csv_file="$1"
  local report_file="$2"

  print_header "USB Controller Analysis"

  local usb_count=0

  while IFS=',' read -r category name manufacturer model device_id driver status location additional; do
    if [[ $category == "USB" ]]; then
      ((usb_count++))
    fi
  done < <(tail -n +2 "$csv_file")

  if [[ $usb_count -gt 0 ]]; then
    printf "${GREEN}✓ Found %d USB controller(s)${RESET}\n" "$usb_count"
    echo "USB controllers have excellent Linux support."
    echo ""

    {
      echo "=== USB Controllers ==="
      printf 'Status: Excellent Linux support\n'
      printf 'Count: %d controller(s)\n' "$usb_count"
      echo ""
    } >> "$report_file"
  fi
}

generate_summary() {
  local report_file="$1"

  print_header "Hardware Compatibility Summary"

  printf "A detailed compatibility report has been saved to:\n"
  printf "  %s\n\n" "$report_file"

  printf "${CYAN}Legend:${RESET}\n"
  printf "  ${GREEN}✓${RESET} = Good Linux support, works out-of-the-box\n"
  printf "  ${YELLOW}⚠${RESET} = May require additional drivers or configuration\n"
  printf "  ${RED}✗${RESET} = Known compatibility issues, requires attention\n\n"

  printf "For more detailed guidance on any problematic hardware, consult:\n"
  printf "  - Your distribution's hardware support documentation\n"
  printf "  - Linux Hardware Database: https://linux-hardware.org/\n"
  printf "  - Your hardware manufacturer's Linux support pages\n\n"
}

process_hardware_inventory() {
  local mount_point="$1"
  print_header "Windows hardware inventory analysis"

  local inventory_file
  if ! inventory_file=$(find_hardware_inventory "$mount_point"); then
    echo "No hardware-inventory.csv file was found under $mount_point."
    echo "Ensure you ran the Windows backup script that collects hardware inventory."
    return 1
  fi

  echo "Using inventory file: $inventory_file"
  remember_path "$inventory_file" "$HARDWARE_INVENTORY_RECORD"

  if [[ ! -s $inventory_file ]]; then
    echo "The inventory file is empty. Inspect it manually to confirm its contents."
    return 1
  fi

  # Initialize report file
  : > "$HARDWARE_REPORT_FILE"
  {
    echo "=========================================="
    echo "Hardware Compatibility Report"
    echo "Generated: $(date)"
    echo "Distribution: $DETECTED_DISTRO_NAME $DETECTED_DISTRO_VERSION"
    echo "=========================================="
    echo ""
  } >> "$HARDWARE_REPORT_FILE"

  # Analyze different hardware categories
  analyze_gpu "$inventory_file" "$HARDWARE_REPORT_FILE"
  analyze_network "$inventory_file" "$HARDWARE_REPORT_FILE"
  analyze_audio "$inventory_file" "$HARDWARE_REPORT_FILE"
  analyze_usb "$inventory_file" "$HARDWARE_REPORT_FILE"

  generate_summary "$HARDWARE_REPORT_FILE"
}

main() {
  # Parse command-line arguments
  local mount_arg=""
  for arg in "$@"; do
    case "$arg" in
      --version)
        printf 'linux-hardware-helper.sh version %s\n' "$SCRIPT_VERSION"
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

  show_banner "Hardware Compatibility Check"
  setup_workspace
  detect_distro

  local mount_point
  mount_point=$(resolve_mount_point "$mount_arg")
  printf '\nWorking with backup contents at: %s\n' "$mount_point"

  if process_hardware_inventory "$mount_point"; then
    printf "\n${GREEN}✓ Hardware analysis complete${RESET}\n"
    printf "Review %s for detailed guidance.\n" "$HARDWARE_REPORT_FILE"
  else
    printf "\n${RED}✗ Hardware analysis could not be completed${RESET}\n"
    exit 1
  fi
}

main "$@"
