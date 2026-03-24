#!/usr/bin/env bash

set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/d1rshan/dots.git}"
REPO_BRANCH="${REPO_BRANCH:-main}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/share/dots}"
WALLPAPER_PATH="${WALLPAPER_PATH:-}"
SKIP_PACKAGES=0
SKIP_BACKUP=0
SKIP_WAL=0

CONFIG_DIRS=(
  fastfetch
  fish
  hypr
  kitty
  mako
  nvim
  rofi
  waybar
)

PACMAN_PACKAGES=(
  hyprland
  hyprpaper
  hyprlock
  hypridle
  hyprshot
  waybar
  rofi
  kitty
  fish
  neovim
  mako
  fastfetch
  starship
  wl-clipboard
  ttf-jetbrains-mono-nerd
  ttf-font-awesome
  noto-fonts-emoji
  git
  curl
)

timestamp() {
  date +"%Y%m%d-%H%M%S"
}

log() {
  printf '[setup] %s\n' "$*"
}

warn() {
  printf '[setup] warning: %s\n' "$*" >&2
}

die() {
  printf '[setup] error: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<EOF
usage: setup.sh [options]

downloads this dotfiles repo if needed, installs the configs, copies bundled wallpapers,
and generates the initial pywal cache.

options:
  --repo-url URL         clone/fetch from a different repo url
  --branch NAME          branch to clone or update (default: ${REPO_BRANCH})
  --repo-dir PATH        target directory for the downloaded repo (default: ${INSTALL_DIR})
  --wallpaper PATH       wallpaper to pass to wal after install
  --skip-packages        skip package installation
  --skip-backup          skip backing up existing configs before overwrite
  --skip-wal             skip the initial wal run
  -h, --help             show this help message

environment overrides:
  REPO_URL, REPO_BRANCH, INSTALL_DIR, WALLPAPER_PATH
EOF
}

while (($# > 0)); do
  case "$1" in
    --repo-url)
      [[ $# -ge 2 ]] || die "--repo-url requires a value"
      REPO_URL="$2"
      shift 2
      ;;
    --branch)
      [[ $# -ge 2 ]] || die "--branch requires a value"
      REPO_BRANCH="$2"
      shift 2
      ;;
    --repo-dir)
      [[ $# -ge 2 ]] || die "--repo-dir requires a value"
      INSTALL_DIR="$2"
      shift 2
      ;;
    --wallpaper)
      [[ $# -ge 2 ]] || die "--wallpaper requires a value"
      WALLPAPER_PATH="$2"
      shift 2
      ;;
    --skip-packages)
      SKIP_PACKAGES=1
      shift
      ;;
    --skip-backup)
      SKIP_BACKUP=1
      shift
      ;;
    --skip-wal)
      SKIP_WAL=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

script_dir() {
  local source_path
  source_path="${BASH_SOURCE[0]}"
  if [[ -n "$source_path" && -e "$source_path" ]]; then
    dirname "$(readlink -f "$source_path")"
  else
    pwd
  fi
}

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

install_packages() {
  if ((SKIP_PACKAGES)); then
    log "skipping package installation"
    return
  fi

  if ! command -v pacman >/dev/null 2>&1; then
    warn "pacman not found; skipping package installation"
    return
  fi

  need_cmd sudo

  log "installing arch packages"
  sudo pacman -S --needed --noconfirm "${PACMAN_PACKAGES[@]}"

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

  warn "could not install pywal16 automatically; install it manually if wal is missing"
}

backup_path() {
  local source_path="$1"
  local backup_root="$2"
  local relative_name

  relative_name="${source_path#$HOME/}"
  mkdir -p "$backup_root/$(dirname "$relative_name")"
  mv "$source_path" "$backup_root/$relative_name"
}

backup_existing() {
  local backup_root="$1"
  local name path

  if ((SKIP_BACKUP)); then
    log "skipping config backup"
    return
  fi

  for name in "${CONFIG_DIRS[@]}" starship.toml; do
    path="$HOME/.config/$name"
    if [[ -e "$path" ]]; then
      mkdir -p "$backup_root"
      log "backing up $path"
      backup_path "$path" "$backup_root"
    fi
  done

  if [[ -e "$HOME/.local/bin" ]]; then
    mkdir -p "$backup_root"
    log "backing up $HOME/.local/bin"
    backup_path "$HOME/.local/bin" "$backup_root"
  fi
}

copy_into_place() {
  local repo_root="$1"
  local name

  mkdir -p "$HOME/.config" "$HOME/.local"

  for name in "${CONFIG_DIRS[@]}"; do
    log "installing ~/.config/$name"
    cp -a "$repo_root/.config/$name" "$HOME/.config/"
  done

  log "installing ~/.config/starship.toml"
  cp -a "$repo_root/.config/starship.toml" "$HOME/.config/starship.toml"

  mkdir -p "$HOME/.local"
  log "installing ~/.local/bin"
  cp -a "$repo_root/.local/bin" "$HOME/.local/"
}

copy_wallpapers() {
  local repo_root="$1"

  mkdir -p "$HOME/walls"
  log "copying bundled wallpapers to $HOME/walls"
  cp -a "$repo_root/walls/." "$HOME/walls/"
}

resolve_wal_cmd() {
  if command -v wal >/dev/null 2>&1; then
    command -v wal
    return
  fi

  if [[ -x "$HOME/.local/bin/wal" ]]; then
    printf '%s\n' "$HOME/.local/bin/wal"
    return
  fi

  return 1
}

pick_wallpaper() {
  if [[ -n "$WALLPAPER_PATH" ]]; then
    printf '%s\n' "$WALLPAPER_PATH"
    return
  fi

  if [[ -f "$HOME/walls/night-city.jpg" ]]; then
    printf '%s\n' "$HOME/walls/night-city.jpg"
    return
  fi

  find "$HOME/walls" -maxdepth 1 -type f | sort | head -n 1
}

run_wal() {
  local wal_cmd wallpaper

  if ((SKIP_WAL)); then
    log "skipping wal generation"
    return
  fi

  wal_cmd="$(resolve_wal_cmd || true)"
  if [[ -z "$wal_cmd" ]]; then
    warn "wal command not found; skipping pywal cache generation"
    return
  fi

  wallpaper="$(pick_wallpaper)"
  if [[ -z "$wallpaper" || ! -f "$wallpaper" ]]; then
    warn "no wallpaper available for wal; skipping pywal cache generation"
    return
  fi

  log "generating pywal cache from $wallpaper"
  "$wal_cmd" -i "$wallpaper"
}

main() {
  local repo_root backup_root

  need_cmd git
  repo_root="$(resolve_repo_dir)"

  install_packages

  backup_root="$HOME/.config-backups/dots-$(timestamp)"
  backup_existing "$backup_root"
  copy_into_place "$repo_root"
  copy_wallpapers "$repo_root"
  run_wal

  log "done"
  log "repo: $repo_root"
  if ((SKIP_BACKUP)); then
    log "backup: skipped"
  elif [[ -d "$backup_root" ]]; then
    log "backup: $backup_root"
  else
    log "backup: no existing configs were moved"
  fi
  log "reload hyprland/waybar or restart your session to apply everything"
}

main "$@"
