#!/usr/bin/env bash
#
# security-skills installer
# Installs security-skills for Claude Code and Google Antigravity (agy).
#
# Usage:
#   ./install.sh [options] [skill1 skill2 ...]
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Determine script directory (repository root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Available skills in this repository
AVAILABLE_SKILLS=(
  "security-scan"
  "security-evaluate"
  "security-remediate"
  "security-update-cve"
  "tests"
  "docs"
)

# Defaults
TARGET_CLAUDE=true
TARGET_AGY=true
INSTALL_MODE="copy" # "copy" or "symlink"
SCOPE="global"      # "global" or "project"
PROJECT_DIR=""
DRY_RUN=false
FORCE=false
UNINSTALL=false
SELECTED_SKILLS=()

# Paths
CLAUDE_GLOBAL_DIR="${HOME}/.claude/skills"
AGY_GLOBAL_DIR="${HOME}/.gemini/config/skills"

print_banner() {
  echo -e "${BOLD}${CYAN}====================================================${NC}"
  echo -e "${BOLD}${CYAN}       Security Skills Installer (Claude & agy)     ${NC}"
  echo -e "${BOLD}${CYAN}====================================================${NC}"
  echo ""
}

show_help() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS] [SKILLS...]

Installs security and development skills into Claude Code and Google Antigravity (agy).

SKILLS:
  security-scan          OWASP Top 10 scanner with CVSS 3.1 & CVE matching
  security-evaluate      Risk scoring, security balance scorecard & matrix
  security-remediate     Auto-patch, suggest, or interactive vulnerability fixing
  security-update-cve    Sync CVE/vulnerability database from OSV.dev & NVD
  tests                  Test suite generator (Vitest, Playwright, pytest)
  docs                   Documentation suite generator (README, ARCHITECTURE, etc.)
  (default: all skills)

TARGET OPTIONS:
  -c, --claude           Install for Claude Code only (~/.claude/skills)
  -a, --agy, --antigravity
                         Install for Antigravity only (~/.gemini/config/skills)
  --all                  Install for both Claude and Antigravity (default)

INSTALLATION MODE:
  -s, --symlink          Create symbolic links (recommended for active development)
  -C, --copy             Copy skill directories (default)

SCOPE OPTIONS:
  -g, --global           Install globally into user config (default)
  -p, --project [DIR]    Install into a specific project directory:
                           Claude: <DIR>/.claude/skills
                           Antigravity: <DIR>/.agents/skills
                         (Defaults to current directory if DIR not specified)

ACTIONS:
  -u, --uninstall        Remove the selected skills from target destinations
  -n, --dry-run          Show actions without making changes
  -f, --force            Overwrite existing files/links without prompting
  -l, --list             List available skills and current installation status
  -h, --help             Show this help message

EXAMPLES:
  # Install all skills for both Claude and Antigravity (copy mode)
  ./install.sh

  # Install all skills using symlinks for live repo updates
  ./install.sh --symlink

  # Install only for Claude Code
  ./install.sh --claude

  # Install only for Antigravity
  ./install.sh --agy

  # Install specific skills with symlinks
  ./install.sh --symlink security-scan security-remediate

  # Install into a specific project workspace
  ./install.sh --project /path/to/my-project

  # Uninstall skills
  ./install.sh --uninstall
EOF
}

list_skills() {
  echo -e "${BOLD}Available skills in this repository:${NC}"
  echo ""
  for skill in "${AVAILABLE_SKILLS[@]}"; do
    local claude_status="${RED}not installed${NC}"
    local agy_status="${RED}not installed${NC}"

    if [ -e "${CLAUDE_GLOBAL_DIR}/${skill}" ] || [ -L "${CLAUDE_GLOBAL_DIR}/${skill}" ]; then
      if [ -L "${CLAUDE_GLOBAL_DIR}/${skill}" ]; then
        claude_status="${GREEN}symlinked${NC}"
      else
        claude_status="${GREEN}copied${NC}"
      fi
    fi

    if [ -e "${AGY_GLOBAL_DIR}/${skill}" ] || [ -L "${AGY_GLOBAL_DIR}/${skill}" ]; then
      if [ -L "${AGY_GLOBAL_DIR}/${skill}" ]; then
        agy_status="${GREEN}symlinked${NC}"
      else
        agy_status="${GREEN}copied${NC}"
      fi
    fi

    printf "  %-22s Claude: %-22b agy: %-22b\n" "$skill" "$claude_status" "$agy_status"
  done
  echo ""
}

# Parse command line arguments
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        show_help
        exit 0
        ;;
      -l|--list)
        print_banner
        list_skills
        exit 0
        ;;
      -c|--claude)
        TARGET_CLAUDE=true
        TARGET_AGY=false
        shift
        ;;
      -a|--agy|--antigravity)
        TARGET_CLAUDE=false
        TARGET_AGY=true
        shift
        ;;
      --all)
        TARGET_CLAUDE=true
        TARGET_AGY=true
        shift
        ;;
      -s|--symlink)
        INSTALL_MODE="symlink"
        shift
        ;;
      -C|--copy)
        INSTALL_MODE="copy"
        shift
        ;;
      -g|--global)
        SCOPE="global"
        shift
        ;;
      -p|--project)
        SCOPE="project"
        if [[ $# -gt 1 && ! "$2" =~ ^- ]]; then
          PROJECT_DIR="$2"
          shift 2
        else
          PROJECT_DIR="$(pwd)"
          shift
        fi
        ;;
      -u|--uninstall)
        UNINSTALL=true
        shift
        ;;
      -n|--dry-run)
        DRY_RUN=true
        shift
        ;;
      -f|--force)
        FORCE=true
        shift
        ;;
      -*)
        echo -e "${RED}Error: Unknown option: $1${NC}" >&2
        echo "Run '$0 --help' for usage." >&2
        exit 1
        ;;
      *)
        # Skill name argument
        local valid=false
        for skill in "${AVAILABLE_SKILLS[@]}"; do
          if [[ "$1" == "$skill" ]]; then
            valid=true
            SELECTED_SKILLS+=("$1")
            break
          fi
        done
        if [ "$valid" = false ]; then
          echo -e "${RED}Error: Unknown skill: $1${NC}" >&2
          echo "Available skills: ${AVAILABLE_SKILLS[*]}" >&2
          exit 1
        fi
        shift
        ;;
    esac
  done

  # Default to all skills if none specified
  if [ ${#SELECTED_SKILLS[@]} -eq 0 ]; then
    SELECTED_SKILLS=("${AVAILABLE_SKILLS[@]}")
  fi
}

resolve_destinations() {
  CLAUDE_DEST=""
  AGY_DEST=""

  if [ "$SCOPE" = "global" ]; then
    CLAUDE_DEST="$CLAUDE_GLOBAL_DIR"
    AGY_DEST="$AGY_GLOBAL_DIR"
  else
    if [ -z "$PROJECT_DIR" ]; then
      PROJECT_DIR="$(pwd)"
    fi
    if [ ! -d "$PROJECT_DIR" ]; then
      echo -e "${RED}Error: Project directory does not exist: $PROJECT_DIR${NC}" >&2
      exit 1
    fi
    PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
    CLAUDE_DEST="${PROJECT_DIR}/.claude/skills"
    AGY_DEST="${PROJECT_DIR}/.agents/skills"
  fi
}

MARKER=".installed-by-security-skills"

install_skill() {
  local skill="$1"
  local dest_dir="$2"
  local target_name="$3"
  local src_dir="${SCRIPT_DIR}/${skill}"
  local target_path="${dest_dir}/${skill}"

  if [ ! -d "$src_dir" ]; then
    echo -e "  ${RED}✗${NC} Source not found: $src_dir"
    return 1
  fi

  if [ "$DRY_RUN" = true ]; then
    if [ "$INSTALL_MODE" = "symlink" ]; then
      echo -e "  ${YELLOW}[dry-run]${NC} Would link: $target_path -> $src_dir (${target_name})"
    else
      echo -e "  ${YELLOW}[dry-run]${NC} Would copy: $src_dir -> $target_path (${target_name})"
    fi
    return 0
  fi

  mkdir -p "$dest_dir"

  # Handle existing destination safely
  if [ -L "$target_path" ]; then
    rm -f "$target_path"   # a symlink is only a pointer; safe to replace
  elif [ -e "$target_path" ]; then
    if [ -f "$target_path/$MARKER" ]; then
      rm -rf "$target_path"   # a copy previously created by this installer
    else
      local backup_dir="${dest_dir}/.backup"
      local backup_path="${backup_dir}/${skill}.$(date +%Y%m%d-%H%M%S)"
      mkdir -p "$backup_dir"
      mv "$target_path" "$backup_path"
      echo -e "  ${YELLOW}!${NC} Existing ${skill} was not installed by this script; moved to ${backup_path}"
    fi
  fi

  if [ "$INSTALL_MODE" = "symlink" ]; then
    ln -s "$src_dir" "$target_path"
    echo -e "  ${GREEN}✓${NC} Symlinked ${BOLD}${skill}${NC} -> ${target_path}"
  else
    # Copy directory
    cp -R "$src_dir" "$target_path"
    : > "$target_path/$MARKER"
    echo -e "  ${GREEN}✓${NC} Copied ${BOLD}${skill}${NC} -> ${target_path}"
  fi
}

uninstall_skill() {
  local skill="$1"
  local dest_dir="$2"
  local target_name="$3"
  local target_path="${dest_dir}/${skill}"

  if [ ! -e "$target_path" ] && [ ! -L "$target_path" ]; then
    echo -e "  ${BLUE}-${NC} ${skill} not installed in ${target_name} (${target_path})"
    return 0
  fi

  if [ "$DRY_RUN" = true ]; then
    echo -e "  ${YELLOW}[dry-run]${NC} Would remove: $target_path (${target_name})"
    return 0
  fi

  if [ -L "$target_path" ]; then
    rm -f "$target_path"
  elif [ -f "$target_path/$MARKER" ]; then
    rm -rf "$target_path"
  else
    echo -e "  ${YELLOW}!${NC} ${skill} in ${target_name} was not installed by this script; leaving it untouched (${target_path})"
    return 0
  fi
  echo -e "  ${GREEN}✓${NC} Removed ${BOLD}${skill}${NC} from ${target_name}"
}

main() {
  parse_args "$@"
  print_banner
  resolve_destinations

  if [ "$UNINSTALL" = true ]; then
    echo -e "${BOLD}Uninstalling security-skills...${NC}"
    echo -e "Mode: Scope = ${BOLD}${SCOPE}${NC}"
    echo ""

    if [ "$TARGET_CLAUDE" = true ]; then
      echo -e "${CYAN}Target: Claude Code (${CLAUDE_DEST})${NC}"
      for skill in "${SELECTED_SKILLS[@]}"; do
        uninstall_skill "$skill" "$CLAUDE_DEST" "Claude"
      done
      echo ""
    fi

    if [ "$TARGET_AGY" = true ]; then
      echo -e "${CYAN}Target: Google Antigravity (${AGY_DEST})${NC}"
      for skill in "${SELECTED_SKILLS[@]}"; do
        uninstall_skill "$skill" "$AGY_DEST" "Antigravity"
      done
      echo ""
    fi

    echo -e "${GREEN}${BOLD}Uninstallation complete!${NC}"
    exit 0
  fi

  echo -e "${BOLD}Installation Configuration:${NC}"
  echo -e "  Scope:       ${BOLD}${SCOPE}${NC} $([ "$SCOPE" = "project" ] && echo "(${PROJECT_DIR})")"
  echo -e "  Mode:        ${BOLD}${INSTALL_MODE}${NC}"
  echo -e "  Skills (${#SELECTED_SKILLS[@]}):  ${SELECTED_SKILLS[*]}"
  echo ""

  if [ "$TARGET_CLAUDE" = true ]; then
    echo -e "${CYAN}Installing for Claude Code -> ${CLAUDE_DEST}${NC}"
    for skill in "${SELECTED_SKILLS[@]}"; do
      install_skill "$skill" "$CLAUDE_DEST" "Claude"
    done
    echo ""
  fi

  if [ "$TARGET_AGY" = true ]; then
    echo -e "${CYAN}Installing for Google Antigravity (agy) -> ${AGY_DEST}${NC}"
    for skill in "${SELECTED_SKILLS[@]}"; do
      install_skill "$skill" "$AGY_DEST" "Antigravity"
    done
    echo ""
  fi

  if [ "$DRY_RUN" = false ]; then
    echo -e "${GREEN}${BOLD}All selected skills successfully installed!${NC}"
    echo ""
    echo -e "${BOLD}Next steps:${NC}"
    if [ "$TARGET_CLAUDE" = true ]; then
      echo -e "  ${BOLD}Claude Code:${NC} Open a terminal in any project and type:"
      echo -e "    ${CYAN}/security-scan${NC}       - Run security audit"
      echo -e "    ${CYAN}/security-evaluate${NC}   - Score & classify findings"
      echo -e "    ${CYAN}/security-remediate${NC}  - Fix vulnerabilities"
      echo -e "    ${CYAN}/security-update-cve${NC} - Sync CVE database"
      echo -e "    ${CYAN}/tests${NC}               - Generate test suite"
      echo -e "    ${CYAN}/docs${NC}                - Generate full documentation"
    fi
    if [ "$TARGET_AGY" = true ]; then
      echo -e "  ${BOLD}Antigravity (agy):${NC} Skills are automatically discovered and loaded"
      echo -e "    on demand when you ask Antigravity to run security scans, evaluations,"
      echo -e "    remediations, tests, or documentation workflows."
    fi
    echo ""
  fi
}

main "$@"
