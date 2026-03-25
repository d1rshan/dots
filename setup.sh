#!/usr/bin/env bash

set -euo pipefail

# ── colour helpers ────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  C_RESET='\033[0m'
  C_BOLD='\033[1m'
  C_CYAN='\033[0;36m'
  C_GREEN='\033[0;32m'
  C_YELLOW='\033[0;33m'
  C_RED='\033[0;31m'
  C_DIM='\033[2m'
else
  C_RESET='' C_BOLD='' C_CYAN='' C_GREEN='' C_YELLOW='' C_RED='' C_DIM=''
fi

# ── defaults ──────────────────────────────────────────────────────────────────
REPO_URL="${REPO_URL:-https://github.com/d1rshan/dots.git}"
REPO_BRANCH="${REPO_BRANCH:-main}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/share/dots}"
WALLPAPER_PATH="${WALLPAPER_PATH:-}"

# non-interactive flags (bypass the menus when set)
NON_INTERACTIVE=0
SKIP_PACKAGES=0
SKIP_BACKUP=0
SKIP_WAL=0
# Space-separated list of components for --components flag (empty = all)
COMPONENTS_ARG=""

# ── component catalogue ───────────────────────────────────────────────────────
# Each entry: "key|description|packages..."
# The first two fields are metadata; everything from field 3 onward are pacman packages.
COMPONENT_DEFS=(
  "fastfetch|Fastfetch (system info)|fastfetch"
  "fish|Fish shell + Starship prompt|fish starship"
  "hypr|Hyprland WM (hyprland hyprpaper hyprlock hypridle hyprshot)|hyprland hyprpaper hyprlock hypridle hyprshot"
  "kitty|Kitty terminal|kitty"
  "mako|Mako notification daemon|mako"
  "nvim|Neovim editor|neovim"
  "rofi|Rofi launcher|rofi"
  "waybar|Waybar status bar|waybar"
  "starship|Starship prompt config only|starship"
)

# common packages always installed when package installation is active
COMMON_PACKAGES=(
  wl-clipboard
  ttf-jetbrains-mono-nerd
  ttf-font-awesome
  noto-fonts-emoji
  git
  curl
)

# ── logging ───────────────────────────────────────────────────────────────────
timestamp() { date +"%Y%m%d-%H%M%S"; }

log()  { printf "${C_GREEN}[setup]${C_RESET} %s\n" "$*"; }
info() { printf "${C_CYAN}  →${C_RESET} %s\n" "$*"; }
warn() { printf "${C_YELLOW}[setup] warning:${C_RESET} %s\n" "$*" >&2; }
die()  { printf "${C_RED}[setup] error:${C_RESET} %s\n" "$*" >&2; exit 1; }

# ── usage ─────────────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
usage: setup.sh [options]

Interactive dotfiles installer for d1rshan/dots (Arch Linux + Hyprland).

Without options the script runs in interactive mode: it backs up your existing
~/.config, then lets you choose which configs to install via a menu.

options:
  --repo-url URL         clone/fetch from a different repo url
  --branch NAME          branch to clone or update (default: ${REPO_BRANCH})
  --repo-dir PATH        target directory for the downloaded repo (default: ${INSTALL_DIR})
  --wallpaper PATH       wallpaper to pass to wal after install
  --components LIST      comma-separated list of components to install without
                         the interactive menu (e.g. hypr,rofi,kitty)
                         valid components: fastfetch fish hypr kitty mako nvim rofi waybar starship
  --non-interactive      install everything without prompting (implies --components all)
  --skip-packages        skip package installation
  --skip-backup          skip backing up existing configs before overwrite
  --skip-wal             skip the initial wal run
  -h, --help             show this help message

environment overrides:
  REPO_URL, REPO_BRANCH, INSTALL_DIR, WALLPAPER_PATH
EOF
}

# ── argument parsing ──────────────────────────────────────────────────────────
while (($# > 0)); do
  case "$1" in
    --repo-url)
      [[ $# -ge 2 ]] || die "--repo-url requires a value"
      REPO_URL="$2"; shift 2 ;;
    --branch)
      [[ $# -ge 2 ]] || die "--branch requires a value"
      REPO_BRANCH="$2"; shift 2 ;;
    --repo-dir)
      [[ $# -ge 2 ]] || die "--repo-dir requires a value"
      INSTALL_DIR="$2"; shift 2 ;;
    --wallpaper)
      [[ $# -ge 2 ]] || die "--wallpaper requires a value"
      WALLPAPER_PATH="$2"; shift 2 ;;
    --components)
      [[ $# -ge 2 ]] || die "--components requires a value"
      COMPONENTS_ARG="$2"; NON_INTERACTIVE=1; shift 2 ;;
    --non-interactive)
      NON_INTERACTIVE=1; shift ;;
    --skip-packages)
      SKIP_PACKAGES=1; shift ;;
    --skip-backup)
      SKIP_BACKUP=1; shift ;;
    --skip-wal)
      SKIP_WAL=1; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      die "unknown option: $1" ;;
  esac
done

# ── helpers ───────────────────────────────────────────────────────────────────
need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

script_dir() {
  local src="${BASH_SOURCE[0]}"
  if [[ -n "$src" && -e "$src" ]]; then
    dirname "$(readlink -f "$src")"
  else
    pwd
  fi
}

# extract field N (1-based) from a pipe-delimited component def string
field() { printf '%s\n' "$1" | cut -d'|' -f"$2"; }

# return the key for a component def
comp_key()  { field "$1" 1; }
comp_desc() { field "$1" 2; }
comp_pkgs() {
  # fields 3+ are packages
  local def="$1"
  printf '%s\n' "$def" | cut -d'|' -f3- | tr '|' ' '
}

# ── repo resolution ───────────────────────────────────────────────────────────
resolve_repo_dir() {
  local source_root
  source_root="$(script_dir)"
  if [[ -d "$source_root/.config" && -d "$source_root/.local" ]]; then
    printf '%s\n' "$source_root"
    return
  fi

  mkdir -p "$(dirname "$INSTALL_DIR")"

  if [[ -d "$INSTALL_DIR/.git" ]]; then
    log "updating repo in $INSTALL_DIR"
    git -C "$INSTALL_DIR" fetch --depth 1 origin "$REPO_BRANCH"
    git -C "$INSTALL_DIR" checkout "$REPO_BRANCH"
    git -C "$INSTALL_DIR" pull --ff-only origin "$REPO_BRANCH"
  elif [[ -d "$INSTALL_DIR" ]]; then
    die "$INSTALL_DIR exists but is not a git checkout"
  else
    log "cloning repo into $INSTALL_DIR"
    git clone --depth 1 --branch "$REPO_BRANCH" "$REPO_URL" "$INSTALL_DIR"
  fi

  printf '%s\n' "$INSTALL_DIR"
}

# ── interactive multi-select menu ─────────────────────────────────────────────
# Sets the global array SELECTED_COMPONENTS to the keys chosen by the user.
interactive_component_menu() {
  local n=${#COMPONENT_DEFS[@]}
  # selected[i]=1 means chosen; start all selected
  local selected=()
  local i
  for ((i = 0; i < n; i++)); do selected[i]=1; done

  while true; do
    printf '\n'
    printf "${C_BOLD}${C_CYAN}  Select configs to install${C_RESET}\n"
    printf "${C_DIM}  Toggle with a number · (a) all · (n) none · (d) done · (q) quit${C_RESET}\n\n"

    for ((i = 0; i < n; i++)); do
      local def="${COMPONENT_DEFS[$i]}"
      local key desc checkbox
      key="$(comp_key "$def")"
      desc="$(comp_desc "$def")"
      if ((selected[i])); then
        checkbox="${C_GREEN}[✓]${C_RESET}"
      else
        checkbox="${C_DIM}[ ]${C_RESET}"
      fi
      printf "  %b  %2d)  %-14s  %b%s%b\n" \
        "$checkbox" $((i + 1)) "$key" "$C_BOLD" "$desc" "$C_RESET"
    done

    printf '\n'
    printf "${C_CYAN}  choice:${C_RESET} "
    local choice
    read -r choice

    case "$choice" in
      a|A)
        for ((i = 0; i < n; i++)); do selected[i]=1; done ;;
      n|N)
        for ((i = 0; i < n; i++)); do selected[i]=0; done ;;
      d|D|'')
        break ;;
      q|Q)
        printf '\n%b  aborted.%b\n\n' "$C_YELLOW" "$C_RESET"
        exit 0 ;;
      *)
        # numeric toggle – accept space/comma-separated list
        local token
        for token in ${choice//,/ }; do
          if [[ "$token" =~ ^[0-9]+$ ]] && ((token >= 1 && token <= n)); then
            local idx=$((token - 1))
            selected[idx]=$(( 1 - selected[idx] ))
          else
            printf "  ${C_YELLOW}ignoring unknown input: %s${C_RESET}\n" "$token"
          fi
        done
        ;;
    esac
  done

  # build SELECTED_COMPONENTS from the chosen indices
  SELECTED_COMPONENTS=()
  for ((i = 0; i < n; i++)); do
    if ((selected[i])); then
      SELECTED_COMPONENTS+=( "$(comp_key "${COMPONENT_DEFS[$i]}")" )
    fi
  done
}

# ── resolve which components to install ───────────────────────────────────────
resolve_selected_components() {
  SELECTED_COMPONENTS=()

  if ((NON_INTERACTIVE)); then
    if [[ -z "$COMPONENTS_ARG" || "$COMPONENTS_ARG" == "all" ]]; then
      # all components
      local def
      for def in "${COMPONENT_DEFS[@]}"; do
        SELECTED_COMPONENTS+=( "$(comp_key "$def")" )
      done
    else
      # parse comma-separated list and validate each entry
      local valid_keys=()
      local def
      for def in "${COMPONENT_DEFS[@]}"; do
        valid_keys+=( "$(comp_key "$def")" )
      done
      IFS=',' read -ra SELECTED_COMPONENTS <<< "$COMPONENTS_ARG"
      local comp
      for comp in "${SELECTED_COMPONENTS[@]}"; do
        local found=0
        local k
        for k in "${valid_keys[@]}"; do
          [[ "$k" == "$comp" ]] && found=1 && break
        done
        if ! ((found)); then
          die "unknown component '$comp'. Valid components: ${valid_keys[*]}"
        fi
      done
    fi
    return
  fi

  interactive_component_menu
}

# ── backup ────────────────────────────────────────────────────────────────────
backup_path() {
  local src="$1" backup_root="$2"
  local rel="${src#"$HOME/"}"
  mkdir -p "$backup_root/$(dirname "$rel")"
  mv "$src" "$backup_root/$rel"
}

do_backup() {
  local backup_root="$1"
  shift
  # $@ = list of component keys to back up (plus "starship.toml" and "bin")
  local item path

  for item in "$@"; do
    path="$HOME/.config/$item"
    if [[ -e "$path" ]]; then
      mkdir -p "$backup_root"
      info "backing up $path"
      backup_path "$path" "$backup_root"
    fi
  done

  # always back up ~/.local/bin if it exists and we are installing anything
  if [[ -e "$HOME/.local/bin" ]]; then
    mkdir -p "$backup_root"
    info "backing up $HOME/.local/bin"
    local rel=".local/bin"
    mkdir -p "$backup_root/$(dirname "$rel")"
    mv "$HOME/.local/bin" "$backup_root/$rel"
  fi
}

prompt_backup() {
  local backup_root="$1"
  shift
  local components=("$@")

  if ((SKIP_BACKUP)); then
    log "skipping config backup (--skip-backup)"
    return
  fi

  printf '\n'
  log "Step 1 — Backup existing configs"
  printf "${C_DIM}  Destination: %s${C_RESET}\n" "$backup_root"

  if ((NON_INTERACTIVE)); then
    do_backup "$backup_root" "${components[@]}"
    return
  fi

  printf '\n'
  printf "  Existing configs for the selected components will be moved to:\n"
  printf "  ${C_BOLD}%s${C_RESET}\n\n" "$backup_root"
  printf "  Back up now? [Y/n] "
  local ans
  read -r ans
  case "${ans:-y}" in
    y|Y|yes|YES) do_backup "$backup_root" "${components[@]}" ;;
    *)
      warn "backup skipped at user request"
      ;;
  esac
}

# ── package installation ──────────────────────────────────────────────────────
install_packages_for() {
  local components=("$@")

  if ((SKIP_PACKAGES)); then
    log "skipping package installation (--skip-packages)"
    return
  fi

  if ! command -v pacman >/dev/null 2>&1; then
    warn "pacman not found; skipping package installation"
    return
  fi

  need_cmd sudo

  # collect packages for selected components
  local pkgs=("${COMMON_PACKAGES[@]}")
  local comp def
  for comp in "${components[@]}"; do
    for def in "${COMPONENT_DEFS[@]}"; do
      if [[ "$(comp_key "$def")" == "$comp" ]]; then
        # read the space-separated package list for this component
        local pkg_str
        pkg_str="$(comp_pkgs "$def")"
        read -ra extra_pkgs <<< "$pkg_str"
        pkgs+=("${extra_pkgs[@]}")
        break
      fi
    done
  done

  log "Step 2 — Installing packages"
  sudo pacman -S --needed --noconfirm "${pkgs[@]}"

  if command -v yay >/dev/null 2>&1; then
    log "installing pywal16 with yay"
    yay -S --needed --noconfirm python-pywal16
    return
  fi

  if command -v python3 >/dev/null 2>&1; then
    log "installing pywal16 with pip"
    python3 -m pip install --user pywal16
    return
  fi

  warn "could not install pywal16 automatically; install it manually if 'wal' is missing"
}

# ── copy configs ──────────────────────────────────────────────────────────────
copy_components() {
  local repo_root="$1"
  shift
  local components=("$@")

  mkdir -p "$HOME/.config" "$HOME/.local"

  log "Step 3 — Installing selected configs"
  local comp
  for comp in "${components[@]}"; do
    case "$comp" in
      starship)
        # starship is a single file, not a directory
        if [[ -f "$repo_root/.config/starship.toml" ]]; then
          info "installing ~/.config/starship.toml"
          cp -a "$repo_root/.config/starship.toml" "$HOME/.config/starship.toml"
        fi
        ;;
      *)
        if [[ -d "$repo_root/.config/$comp" ]]; then
          info "installing ~/.config/$comp"
          cp -a "$repo_root/.config/$comp" "$HOME/.config/"
        else
          warn "component '$comp' has no matching directory in the repo; skipping"
        fi
        ;;
    esac
  done

  # ~/.local/bin is always installed when anything is selected
  if [[ -d "$repo_root/.local/bin" ]]; then
    info "installing ~/.local/bin"
    cp -a "$repo_root/.local/bin" "$HOME/.local/"
  fi
}

copy_wallpapers() {
  local repo_root="$1"

  mkdir -p "$HOME/walls"
  log "Step 4 — Copying bundled wallpapers to ~/walls"
  cp -a "$repo_root/walls/." "$HOME/walls/"
}

# ── pywal ─────────────────────────────────────────────────────────────────────
resolve_wal_cmd() {
  if command -v wal >/dev/null 2>&1; then command -v wal; return; fi
  if [[ -x "$HOME/.local/bin/wal" ]]; then printf '%s\n' "$HOME/.local/bin/wal"; return; fi
  return 1
}

pick_wallpaper() {
  if [[ -n "$WALLPAPER_PATH" ]]; then printf '%s\n' "$WALLPAPER_PATH"; return; fi
  if [[ -f "$HOME/walls/night-city.jpg" ]]; then printf '%s\n' "$HOME/walls/night-city.jpg"; return; fi
  [[ -d "$HOME/walls" ]] && find "$HOME/walls" -maxdepth 1 -type f | sort | head -n 1
}

run_wal() {
  if ((SKIP_WAL)); then
    log "skipping wal generation (--skip-wal)"
    return
  fi

  local wal_cmd
  wal_cmd="$(resolve_wal_cmd || true)"
  if [[ -z "$wal_cmd" ]]; then
    warn "wal command not found; skipping pywal cache generation"
    return
  fi

  local wallpaper
  wallpaper="$(pick_wallpaper)"
  if [[ -z "$wallpaper" || ! -f "$wallpaper" ]]; then
    warn "no wallpaper available for wal; skipping pywal cache generation"
    return
  fi

  log "Step 5 — Generating pywal cache from $wallpaper"
  "$wal_cmd" -i "$wallpaper"
}

# ── summary confirmation ──────────────────────────────────────────────────────
confirm_plan() {
  local components=("$@")

  printf '\n'
  printf "${C_BOLD}${C_CYAN}  Installation plan${C_RESET}\n\n"
  printf "  Components to install:\n"
  local comp
  for comp in "${components[@]}"; do
    printf "    ${C_GREEN}✓${C_RESET}  %s\n" "$comp"
  done
  printf '\n'
  printf "  Packages:     %s\n" "$(((SKIP_PACKAGES)) && echo 'skipped' || echo 'will be installed')"
  printf "  Backup first: %s\n" "$(((SKIP_BACKUP))   && echo 'skipped' || echo 'yes')"
  printf "  Pywal run:    %s\n" "$(((SKIP_WAL))      && echo 'skipped' || echo 'yes')"
  printf '\n'

  if ((NON_INTERACTIVE)); then
    return
  fi

  printf "  Proceed? [Y/n] "
  local ans
  read -r ans
  case "${ans:-y}" in
    y|Y|yes|YES) ;;
    *)
      printf '\n%b  aborted.%b\n\n' "$C_YELLOW" "$C_RESET"
      exit 0
      ;;
  esac
}

# ── banner ────────────────────────────────────────────────────────────────────
print_banner() {
  printf '\n'
  printf "${C_BOLD}${C_CYAN}"
  printf '  ██████╗  ██████╗ ████████╗███████╗\n'
  printf '  ██╔══██╗██╔═══██╗╚══██╔══╝██╔════╝\n'
  printf '  ██║  ██║██║   ██║   ██║   ███████╗\n'
  printf '  ██║  ██║██║   ██║   ██║   ╚════██║\n'
  printf '  ██████╔╝╚██████╔╝   ██║   ███████║\n'
  printf '  ╚═════╝  ╚═════╝    ╚═╝   ╚══════╝\n'
  printf "${C_RESET}"
  printf "${C_DIM}  d1rshan · Arch Linux + Hyprland dotfiles${C_RESET}\n\n"
}

# ── main ──────────────────────────────────────────────────────────────────────
main() {
  need_cmd git

  print_banner

  local repo_root
  repo_root="$(resolve_repo_dir)"

  # ── component selection ──────────────────────────────────────────────────
  resolve_selected_components

  if [[ ${#SELECTED_COMPONENTS[@]} -eq 0 ]]; then
    printf '\n%b  No components selected. Nothing to do.%b\n\n' "$C_YELLOW" "$C_RESET"
    exit 0
  fi

  # build backup item list: component keys + "starship.toml" if starship selected
  local backup_items=()
  local comp
  for comp in "${SELECTED_COMPONENTS[@]}"; do
    case "$comp" in
      starship) backup_items+=("starship.toml") ;;
      *)        backup_items+=("$comp") ;;
    esac
  done

  # ── show plan and confirm ────────────────────────────────────────────────
  confirm_plan "${SELECTED_COMPONENTS[@]}"

  # ── step 1: backup ───────────────────────────────────────────────────────
  local backup_root="$HOME/.config-backups/dots-$(timestamp)"
  prompt_backup "$backup_root" "${backup_items[@]}"

  # ── step 2: packages ─────────────────────────────────────────────────────
  install_packages_for "${SELECTED_COMPONENTS[@]}"

  # ── step 3: copy configs ─────────────────────────────────────────────────
  copy_components "$repo_root" "${SELECTED_COMPONENTS[@]}"

  # ── step 4: wallpapers ───────────────────────────────────────────────────
  copy_wallpapers "$repo_root"

  # ── step 5: pywal ────────────────────────────────────────────────────────
  run_wal

  # ── summary ──────────────────────────────────────────────────────────────
  printf '\n'
  log "Done! ✨"
  printf '\n'
  printf "  ${C_BOLD}Repo:${C_RESET}    %s\n" "$repo_root"
  if ((SKIP_BACKUP)); then
    printf "  ${C_BOLD}Backup:${C_RESET}  skipped\n"
  elif [[ -d "$backup_root" ]]; then
    printf "  ${C_BOLD}Backup:${C_RESET}  %s\n" "$backup_root"
  else
    printf "  ${C_BOLD}Backup:${C_RESET}  no existing configs were found\n"
  fi
  printf '\n'
  printf "  ${C_YELLOW}Reload Hyprland/Waybar or restart your session to apply changes.${C_RESET}\n\n"
}

main "$@"
