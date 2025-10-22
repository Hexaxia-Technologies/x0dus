#!/usr/bin/env bash
# linux-ai-prompt-generator.sh
# Generate AI chatbot prompts based on Windows-to-Linux migration context.

set -euo pipefail

SCRIPT_VERSION="1.0.0.RC1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

if [[ -z ${HOME:-} ]]; then
  echo "The HOME environment variable is not set. Unable to determine workspace location." >&2
  exit 1
fi

WORKSPACE_DIR="${HOME}/x0dus"
LOG_FILE="${WORKSPACE_DIR}/linux-ai-prompt-generator.log"
AI_PROMPTS_DIR="${WORKSPACE_DIR}/ai-prompts"
PROMPT_INDEX_FILE="${AI_PROMPTS_DIR}/index.md"
SYSTEM_INFO_FILE="${WORKSPACE_DIR}/system-info.txt"
MOUNT_POINT_FILE="${WORKSPACE_DIR}/mount-point.txt"
HARDWARE_INVENTORY_RECORD="${WORKSPACE_DIR}/hardware-inventory-path.txt"
SOFTWARE_LIST_RECORD="${WORKSPACE_DIR}/installed-software-names-path.txt"

DETECTED_DISTRO_NAME="Unknown"
DETECTED_DISTRO_VERSION=""
DETECTED_DISTRO_ID=""

# ANSI color codes
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RESET='\033[0m'

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

show_help() {
  cat <<'HELP'
Usage: linux-ai-prompt-generator.sh [OPTIONS]

Generate ready-to-use AI chatbot prompts based on your Windows-to-Linux
migration context. These prompts help you get personalized assistance from
AI chatbots like ChatGPT, Claude, Gemini, or others.

Options:
  --version     Show version information and exit
  -h, --help    Show this help message and exit

This helper will:
  1. Analyze your Linux distribution and system information
  2. Read hardware and software inventories from the Windows backup
  3. Generate contextual AI prompts for:
     - Hardware compatibility and driver installation
     - Software alternatives and migration
     - Gaming setup (if games detected)
     - Development environment setup (if dev tools detected)
     - General troubleshooting
  4. Save all prompts to ~/x0dus/ai-prompts/ for easy copy-paste

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

  mkdir -p "$WORKSPACE_DIR"
  mkdir -p "$AI_PROMPTS_DIR"

  if ! touch "$LOG_FILE"; then
    echo "Unable to create the log file at $LOG_FILE." >&2
    exit 1
  fi

  exec > >(tee -a "$LOG_FILE") 2>&1

  print_header "Workspace"
  printf 'Workspace directory    : %s\n' "$WORKSPACE_DIR"
  printf 'AI prompts directory   : %s\n' "$AI_PROMPTS_DIR"
  printf 'Prompt index           : %s\n' "$PROMPT_INDEX_FILE"
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
  printf 'Desktop environment  : %s\n' "${XDG_CURRENT_DESKTOP:-Not detected}"
}

get_package_manager_name() {
  case "$DETECTED_DISTRO_ID" in
    ubuntu|debian|linuxmint|pop|elementary|zorin|kubuntu|lubuntu|xubuntu|neon|mx|deepin|raspbian|peppermint)
      echo "APT (apt/apt-get)"
      ;;
    fedora|rhel|centos|rocky|almalinux|oracle)
      echo "DNF"
      ;;
    arch|manjaro|endeavouros|garuda)
      echo "pacman"
      ;;
    opensuse*|sles|sled)
      echo "zypper"
      ;;
    gentoo)
      echo "Portage (emerge)"
      ;;
    void)
      echo "XBPS"
      ;;
    alpine)
      echo "APK"
      ;;
    *)
      echo "your distribution's package manager"
      ;;
  esac
}

generate_hardware_prompt() {
  local hardware_file="$1"
  local prompt_file="${AI_PROMPTS_DIR}/01-hardware-compatibility.txt"

  if [[ ! -f $hardware_file ]]; then
    return 1
  fi

  print_header "Generating hardware compatibility prompt"

  local timestamp
  timestamp=$(date "+%Y-%m-%d %H:%M:%S")

  cat > "$prompt_file" <<PROMPT
# Hardware Compatibility Assistance Prompt
# Generated: $timestamp
# Distribution: $DETECTED_DISTRO_NAME $DETECTED_DISTRO_VERSION
# Package Manager: $(get_package_manager_name)

========================================
COPY THE TEXT BELOW TO YOUR AI CHATBOT:
========================================

I'm migrating from Windows to Linux and need help with hardware driver compatibility.

**My System:**
- Distribution: $DETECTED_DISTRO_NAME $DETECTED_DISTRO_VERSION
- Kernel: $(uname -sr)
- Desktop: ${XDG_CURRENT_DESKTOP:-Not specified}
- Package Manager: $(get_package_manager_name)

**Hardware Inventory from Windows:**

$(cat "$hardware_file" | head -n 100)

$(if [[ $(wc -l < "$hardware_file") -gt 100 ]]; then echo "[... inventory truncated, full file available at $hardware_file ...]"; fi)

**Questions:**
1. Which hardware devices are likely to need additional drivers or configuration on Linux?
2. What are the specific installation commands for my distribution ($(get_package_manager_name))?
3. Are there any known compatibility issues with this hardware on Linux?
4. Should I use proprietary or open-source drivers, and why?
5. What post-installation configuration might be needed?

Please provide step-by-step commands I can run in my terminal.

========================================
PROMPT

  printf "${GREEN}✓${RESET} Hardware compatibility prompt saved to:\n  %s\n" "$prompt_file"
  return 0
}

generate_software_prompt() {
  local software_file="$1"
  local prompt_file="${AI_PROMPTS_DIR}/02-software-alternatives.txt"

  if [[ ! -f $software_file ]]; then
    return 1
  fi

  print_header "Generating software migration prompt"

  local timestamp
  timestamp=$(date "+%Y-%m-%d %H:%M:%S")

  cat > "$prompt_file" <<PROMPT
# Software Migration Assistance Prompt
# Generated: $timestamp
# Distribution: $DETECTED_DISTRO_NAME $DETECTED_DISTRO_VERSION

========================================
COPY THE TEXT BELOW TO YOUR AI CHATBOT:
========================================

I'm migrating from Windows to Linux and need help finding alternatives for my Windows applications.

**My System:**
- Distribution: $DETECTED_DISTRO_NAME $DETECTED_DISTRO_VERSION
- Package Manager: $(get_package_manager_name)
- Desktop: ${XDG_CURRENT_DESKTOP:-Not specified}

**Windows Applications I Had Installed:**

$(cat "$software_file" | head -n 100)

$(if [[ $(wc -l < "$software_file") -gt 100 ]]; then echo "[... list truncated, full file available at $software_file ...]"; fi)

**Questions:**
1. What are the best Linux alternatives for each of these applications?
2. Which alternatives are available through $(get_package_manager_name)?
3. Which applications might work through Wine or compatibility layers?
4. Are there web-based alternatives I should consider?
5. What are the installation commands for the recommended alternatives?

**Preferences:**
- Prioritize open-source software when possible
- Prefer native Linux applications over compatibility layers
- Suggest both GUI and CLI alternatives where applicable
- Include Flatpak/Snap alternatives if native packages aren't available

Please provide a structured list with installation commands for my distribution.

========================================
PROMPT

  printf "${GREEN}✓${RESET} Software migration prompt saved to:\n  %s\n" "$prompt_file"
  return 0
}

generate_gaming_prompt() {
  local software_file="$1"
  local prompt_file="${AI_PROMPTS_DIR}/03-gaming-setup.txt"

  if [[ ! -f $software_file ]]; then
    return 1
  fi

  # Check if gaming-related software is in the list
  local has_games=0
  if grep -qiE "steam|epic|gog|origin|uplay|battle\.net|riot|minecraft|league of legends" "$software_file"; then
    has_games=1
  fi

  if [[ $has_games -eq 0 ]]; then
    return 1
  fi

  print_header "Generating gaming setup prompt"

  local timestamp
  timestamp=$(date "+%Y-%m-%d %H:%M:%S")

  cat > "$prompt_file" <<PROMPT
# Gaming Setup Assistance Prompt
# Generated: $timestamp
# Distribution: $DETECTED_DISTRO_NAME $DETECTED_DISTRO_VERSION

========================================
COPY THE TEXT BELOW TO YOUR AI CHATBOT:
========================================

I'm a gamer migrating from Windows to Linux and need help setting up my gaming environment.

**My System:**
- Distribution: $DETECTED_DISTRO_NAME $DETECTED_DISTRO_VERSION
- Kernel: $(uname -sr)
- Package Manager: $(get_package_manager_name)
- GPU: $(lspci | grep -i vga | head -n 1 || echo "Not detected")

**Gaming-Related Software from Windows:**

$(grep -iE "steam|epic|gog|origin|uplay|battle|riot|game|minecraft" "$software_file" || echo "General gaming software detected")

**Questions:**
1. How do I install and configure Steam for Linux gaming?
2. What is Proton and how do I enable it for Windows games?
3. How do I set up Lutris for non-Steam games (Epic, GOG, etc.)?
4. What Wine configuration is optimal for my distribution?
5. How do I install graphics drivers for best gaming performance?
6. Are there any gaming-specific optimizations for my distribution?
7. How do I enable MangoHud or other performance overlays?
8. What about anti-cheat compatibility (EAC, BattlEye)?

**Gaming Platforms I Used on Windows:**
- Steam
- Epic Games Store
- GOG Galaxy
- Origin/EA App
- Battle.net
- Xbox Game Pass
- Others (please suggest Linux solutions)

Please provide step-by-step installation and configuration commands for my distribution.

========================================
PROMPT

  printf "${GREEN}✓${RESET} Gaming setup prompt saved to:\n  %s\n" "$prompt_file"
  return 0
}

generate_development_prompt() {
  local software_file="$1"
  local prompt_file="${AI_PROMPTS_DIR}/04-development-environment.txt"

  if [[ ! -f $software_file ]]; then
    return 1
  fi

  # Check if development tools are in the list
  local has_dev_tools=0
  if grep -qiE "visual studio|vscode|pycharm|intellij|eclipse|sublime|atom|notepad\+\+|git|docker|node|python|java|android studio|postman" "$software_file"; then
    has_dev_tools=1
  fi

  if [[ $has_dev_tools -eq 0 ]]; then
    return 1
  fi

  print_header "Generating development environment prompt"

  local timestamp
  timestamp=$(date "+%Y-%m-%d %H:%M:%S")

  cat > "$prompt_file" <<PROMPT
# Development Environment Setup Prompt
# Generated: $timestamp
# Distribution: $DETECTED_DISTRO_NAME $DETECTED_DISTRO_VERSION

========================================
COPY THE TEXT BELOW TO YOUR AI CHATBOT:
========================================

I'm a developer migrating from Windows to Linux and need help recreating my development environment.

**My System:**
- Distribution: $DETECTED_DISTRO_NAME $DETECTED_DISTRO_VERSION
- Package Manager: $(get_package_manager_name)
- Shell: $SHELL

**Development Tools from Windows:**

$(grep -iE "visual studio|vscode|pycharm|intellij|eclipse|sublime|atom|notepad|git|docker|node|python|java|android|postman|terminal|wsl" "$software_file" || echo "Development tools detected")

**Questions:**
1. What are the best Linux alternatives for my Windows dev tools?
2. How do I install and configure these tools on $(get_package_manager_name)?
3. What's the equivalent of WSL2 on Linux? (native environment!)
4. How do I set up Docker without Docker Desktop?
5. What terminal emulator and shell should I use (bash, zsh, fish)?
6. How do I configure my IDE for optimal Linux development?
7. Are there any distribution-specific development packages I should install?
8. How do I manage multiple language versions (nvm, pyenv, rbenv, etc.)?

**Programming Languages/Frameworks I Use:**
$(grep -iE "python|node|java|ruby|php|go|rust|\.net|c\+\+|typescript" "$software_file" || echo "Various languages")

Please provide:
- Installation commands for each tool on my distribution
- Configuration recommendations
- Any Linux-specific best practices I should know
- Suggestions for improving my workflow on Linux

========================================
PROMPT

  printf "${GREEN}✓${RESET} Development environment prompt saved to:\n  %s\n" "$prompt_file"
  return 0
}

generate_troubleshooting_template() {
  local prompt_file="${AI_PROMPTS_DIR}/05-troubleshooting-template.txt"

  print_header "Generating troubleshooting template"

  local timestamp
  timestamp=$(date "+%Y-%m-%d %H:%M:%S")

  cat > "$prompt_file" <<PROMPT
# Troubleshooting Template
# Generated: $timestamp
# Distribution: $DETECTED_DISTRO_NAME $DETECTED_DISTRO_VERSION

========================================
COPY AND CUSTOMIZE THIS TEMPLATE:
========================================

**Problem Description:**
[Describe your issue in detail - what's not working? What error messages do you see?]

**My System:**
- Distribution: $DETECTED_DISTRO_NAME $DETECTED_DISTRO_VERSION
- Kernel: $(uname -sr)
- Desktop: ${XDG_CURRENT_DESKTOP:-Not detected}
- Package Manager: $(get_package_manager_name)

**Hardware (if relevant):**
[Copy relevant hardware info from: $HARDWARE_INVENTORY_RECORD]

**What I've Tried:**
1. [Step 1]
2. [Step 2]
3. [Step 3]

**Error Messages/Logs:**
\`\`\`
[Paste relevant error messages or log excerpts here]
\`\`\`

**Expected Behavior:**
[What should happen vs. what actually happens]

**Questions:**
1. What's causing this issue?
2. How can I fix it?
3. Are there any diagnostic commands I should run?
4. Is this a known issue with my distribution?
5. What are the best practices to prevent this in the future?

Please provide step-by-step troubleshooting commands specific to my distribution.

========================================
PROMPT

  printf "${GREEN}✓${RESET} Troubleshooting template saved to:\n  %s\n" "$prompt_file"
  return 0
}

generate_general_migration_prompt() {
  local prompt_file="${AI_PROMPTS_DIR}/06-general-migration-guidance.txt"

  print_header "Generating general migration prompt"

  local timestamp
  timestamp=$(date "+%Y-%m-%d %H:%M:%S")

  cat > "$prompt_file" <<PROMPT
# General Linux Migration Guidance Prompt
# Generated: $timestamp
# Distribution: $DETECTED_DISTRO_NAME $DETECTED_DISTRO_VERSION

========================================
COPY THE TEXT BELOW TO YOUR AI CHATBOT:
========================================

I've just migrated from Windows to Linux and I'm looking for general guidance to get started.

**My System:**
- Distribution: $DETECTED_DISTRO_NAME $DETECTED_DISTRO_VERSION
- Kernel: $(uname -sr)
- Desktop: ${XDG_CURRENT_DESKTOP:-Not detected}
- Package Manager: $(get_package_manager_name)

**Questions:**

**1. Getting Started:**
- What are the most important first steps after installing Linux?
- How do I update my system and keep it secure?
- What essential packages should I install right away?

**2. File System & Navigation:**
- Where do my user files go? (equivalent of C:\\Users)
- What's the Linux equivalent of common Windows directories?
- How do I mount external drives and access network shares?

**3. Software Management:**
- How do I install software with $(get_package_manager_name)?
- When should I use Flatpak vs Snap vs native packages?
- How do I keep my installed software up to date?

**4. System Configuration:**
- How do I customize my desktop environment?
- Where are configuration files typically stored?
- How do I manage startup applications?

**5. Command Line Basics:**
- What are the most useful terminal commands for beginners?
- How do I use sudo safely?
- What's a good terminal emulator and shell configuration?

**6. Windows Workflows:**
- How do I replace common Windows keyboard shortcuts?
- What's the Linux equivalent of Task Manager?
- How do I take screenshots and record screen?

**7. Backup & Maintenance:**
- What backup tools should I use on Linux?
- How do I clean up disk space?
- What routine maintenance should I perform?

Please provide practical, distribution-specific answers with examples for $DETECTED_DISTRO_NAME.

========================================
PROMPT

  printf "${GREEN}✓${RESET} General migration guidance prompt saved to:\n  %s\n" "$prompt_file"
  return 0
}

create_prompt_index() {
  print_header "Creating prompt index"

  local timestamp
  timestamp=$(date "+%Y-%m-%d %H:%M:%S")

  cat > "$PROMPT_INDEX_FILE" <<INDEX
# AI Assistance Prompts for Linux Migration

**Generated:** $timestamp
**Distribution:** $DETECTED_DISTRO_NAME $DETECTED_DISTRO_VERSION
**Toolkit Version:** x0dus v$SCRIPT_VERSION

---

## About These Prompts

These prompts are designed to help you get personalized Linux migration assistance from AI chatbots like ChatGPT, Claude, Gemini, Copilot, or others. Each prompt is pre-filled with your specific system information and migration context.

## How to Use

1. Open any of the prompt files listed below
2. Copy the text under "COPY THE TEXT BELOW TO YOUR AI CHATBOT:"
3. Paste it into your favorite AI chatbot
4. Get specific, contextual answers for your migration

## Available Prompts

### 1. Hardware Compatibility (\`01-hardware-compatibility.txt\`)
Get help with driver installation and hardware compatibility issues.

**When to use:** Right after installing Linux, especially if you have NVIDIA/AMD GPUs, Broadcom Wi-Fi, or Realtek network cards.

---

### 2. Software Alternatives (\`02-software-alternatives.txt\`)
Find Linux alternatives for your Windows applications.

**When to use:** When setting up your system and reinstalling software.

---

### 3. Gaming Setup (\`03-gaming-setup.txt\`) *[If applicable]*
Configure Steam, Proton, Lutris, and Wine for gaming.

**When to use:** If you're a gamer wanting to play Windows games on Linux.

---

### 4. Development Environment (\`04-development-environment.txt\`) *[If applicable]*
Recreate your Windows development environment on Linux.

**When to use:** If you're a developer setting up IDEs, Docker, and dev tools.

---

### 5. Troubleshooting Template (\`05-troubleshooting-template.txt\`)
A customizable template for asking about specific problems.

**When to use:** When you encounter issues and need debugging help.

---

### 6. General Migration Guidance (\`06-general-migration-guidance.txt\`)
Get comprehensive guidance for Linux beginners.

**When to use:** If you're new to Linux and want to understand the basics.

---

## Tips for Best Results

- **Be specific:** The more context you provide, the better the AI can help
- **Follow up:** Ask clarifying questions if something isn't clear
- **Verify commands:** Always understand what a command does before running it
- **Check versions:** Some instructions may vary based on your software versions
- **One prompt at a time:** Start with the most relevant prompt for your current need

## Need More Help?

- **x0dus GitHub Issues:** https://github.com/Hexaxia-Technologies/x0dus/issues
- **Hexaxia Technologies:** https://hexaxia.tech
- **Your distribution's docs:** Most distros have excellent documentation

---

*These prompts were generated by linux-ai-prompt-generator.sh v$SCRIPT_VERSION*
*Part of the x0dus Migration Toolkit by Hexaxia Technologies*
INDEX

  printf "${GREEN}✓${RESET} Prompt index created at:\n  %s\n" "$PROMPT_INDEX_FILE"
}

summarize_generated_prompts() {
  print_header "Summary"

  printf "\n${CYAN}AI Assistance Prompts Generated Successfully!${RESET}\n\n"

  printf "All prompts have been saved to:\n"
  printf "  %s\n\n" "$AI_PROMPTS_DIR"

  printf "Generated prompts:\n"
  local count=0
  for prompt_file in "$AI_PROMPTS_DIR"/*.txt; do
    if [[ -f $prompt_file ]]; then
      ((count++))
      printf "  ${GREEN}✓${RESET} %s\n" "$(basename "$prompt_file")"
    fi
  done

  if [[ $count -eq 0 ]]; then
    printf "  ${YELLOW}⚠${RESET} No prompts were generated (missing inventory files?)\n"
  fi

  printf "\n${YELLOW}Next Steps:${RESET}\n"
  printf "1. Review the prompt index:\n"
  printf "   cat %s\n\n" "$PROMPT_INDEX_FILE"
  printf "2. Open a prompt file relevant to your needs\n"
  printf "3. Copy the prompt text to your favorite AI chatbot\n"
  printf "4. Get personalized assistance for your Linux migration!\n\n"

  printf "${CYAN}Supported AI Chatbots:${RESET}\n"
  printf "  • ChatGPT (OpenAI): https://chat.openai.com/\n"
  printf "  • Claude (Anthropic): https://claude.ai/\n"
  printf "  • Gemini (Google): https://gemini.google.com/\n"
  printf "  • Microsoft Copilot: https://copilot.microsoft.com/\n"
  printf "  • Any other AI chatbot of your choice\n\n"
}

main() {
  # Parse command-line arguments
  for arg in "$@"; do
    case "$arg" in
      --version)
        printf 'linux-ai-prompt-generator.sh version %s\n' "$SCRIPT_VERSION"
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

  show_banner "AI Migration Assistant"
  setup_workspace
  detect_distro

  # Load inventory file paths
  local hardware_file
  local software_file

  hardware_file=$(load_remembered_path "$HARDWARE_INVENTORY_RECORD")
  software_file=$(load_remembered_path "$SOFTWARE_LIST_RECORD")

  # Fallback: try to find files if not remembered
  if [[ -z $hardware_file ]]; then
    local mount_point
    mount_point=$(load_remembered_path "$MOUNT_POINT_FILE")
    if [[ -n $mount_point && -d $mount_point ]]; then
      hardware_file=$(find "$mount_point" -maxdepth 4 -type f -name 'hardware-inventory.csv' -print -quit 2>/dev/null || echo "")
    fi
  fi

  if [[ -z $software_file ]]; then
    software_file=$(find "$WORKSPACE_DIR" -type f -name 'installed-software-names-*.txt' -print -quit 2>/dev/null || echo "")
  fi

  # Generate prompts
  local generated_count=0

  if [[ -n $hardware_file && -f $hardware_file ]]; then
    if generate_hardware_prompt "$hardware_file"; then
      ((generated_count++))
    fi
  else
    printf "${YELLOW}⚠${RESET} Hardware inventory not found - skipping hardware prompt\n"
    printf "   Run linux-hardware-helper.sh first to analyze hardware.\n"
  fi

  if [[ -n $software_file && -f $software_file ]]; then
    if generate_software_prompt "$software_file"; then
      ((generated_count++))
    fi
    if generate_gaming_prompt "$software_file"; then
      ((generated_count++))
    fi
    if generate_development_prompt "$software_file"; then
      ((generated_count++))
    fi
  else
    printf "${YELLOW}⚠${RESET} Software inventory not found - skipping software prompts\n"
    printf "   Run linux-software-inventory.sh first to extract software list.\n"
  fi

  generate_troubleshooting_template
  ((generated_count++))

  generate_general_migration_prompt
  ((generated_count++))

  create_prompt_index

  if [[ $generated_count -gt 0 ]]; then
    summarize_generated_prompts
    printf "${GREEN}✓ Successfully generated %d AI assistance prompt(s)${RESET}\n" "$generated_count"
  else
    printf "${YELLOW}⚠ No prompts could be generated${RESET}\n"
    printf "Make sure you've run the other x0dus helpers first:\n"
    printf "  1. linux-restore-helper.sh    (mount the backup)\n"
    printf "  2. linux-hardware-helper.sh   (analyze hardware)\n"
    printf "  3. linux-software-inventory.sh (extract software list)\n"
    printf "  4. linux-ai-prompt-generator.sh (this script)\n"
    exit 1
  fi
}

main "$@"
