#!/usr/bin/env bash

set -euo pipefail

# Globals for detection
OS_NAME=""; OS_VERSION=""; PKG_MGR=""; WEBSERVER=""; ASSUME_YES=${ASSUME_YES:-0}; VERBOSE=${VERBOSE:-0}

log() { printf '%s\n' "$*"; }
info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
error() { printf '[ERROR] %s\n' "$*" >&2; }
success() { printf '[ OK ] %s\n' "$*"; }
die() { error "$*"; exit 1; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

sudo_if_needed() {
  if [[ $EUID -eq 0 ]]; then "$@"; else sudo "$@"; fi
}

confirm() {
  local prompt=${1:-"Proceed? (y/N): "}
  if [[ "$ASSUME_YES" -eq 1 ]]; then return 0; fi
  read -r -p "$prompt" ans
  [[ "$ans" =~ ^[Yy]$ ]]
}

detect_os() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    OS_NAME=${NAME:-Unknown}
    OS_VERSION=${VERSION_ID:-}
  else
    OS_NAME=$(uname -s)
    OS_VERSION=$(uname -r)
  fi
}

detect_pkg_manager() {
  if command_exists apt; then PKG_MGR=apt
  elif command_exists dnf; then PKG_MGR=dnf
  elif command_exists yum; then PKG_MGR=yum
  elif command_exists pacman; then PKG_MGR=pacman
  elif command_exists apk; then PKG_MGR=apk
  elif command_exists zypper; then PKG_MGR=zypper
  else die "No supported package manager found (apt, dnf, yum, pacman, apk, zypper)."; fi
}

detect_webserver() {
  WEBSERVER=""
  if command_exists systemctl; then
    if systemctl is-active --quiet nginx; then WEBSERVER=nginx; return 0; fi
    if systemctl is-active --quiet apache2; then WEBSERVER=apache; return 0; fi
    if systemctl is-active --quiet httpd; then WEBSERVER=apache; return 0; fi
  fi
  return 1
}

install_certbot() {
  case "$PKG_MGR" in
    apt)
      sudo_if_needed apt update
      sudo_if_needed apt install -y certbot
      ;;
    dnf)
      sudo_if_needed dnf install -y certbot
      ;;
    yum)
      sudo_if_needed yum install -y epel-release || true
      sudo_if_needed yum install -y certbot
      ;;
    pacman)
      sudo_if_needed pacman -Sy --noconfirm certbot
      ;;
    apk)
      sudo_if_needed apk add --no-cache certbot
      ;;
    zypper)
      sudo_if_needed zypper --non-interactive install certbot
      ;;
    *) die "Unsupported package manager: $PKG_MGR" ;;
  esac
}

install_certbot_plugin() {
  local websrv="$1"
  case "$PKG_MGR/$websrv" in
    apt/nginx) sudo_if_needed apt install -y python3-certbot-nginx ;;
    apt/apache) sudo_if_needed apt install -y python3-certbot-apache ;;
    dnf/nginx) sudo_if_needed dnf install -y certbot-nginx || sudo_if_needed dnf install -y python3-certbot-nginx ;;
    dnf/apache) sudo_if_needed dnf install -y certbot-apache || sudo_if_needed dnf install -y python3-certbot-apache ;;
    yum/nginx) sudo_if_needed yum install -y certbot-nginx || sudo_if_needed yum install -y python3-certbot-nginx ;;
    yum/apache) sudo_if_needed yum install -y certbot-apache || sudo_if_needed yum install -y python3-certbot-apache ;;
    pacman/nginx) sudo_if_needed pacman -Sy --noconfirm certbot-nginx ;;
    pacman/apache) sudo_if_needed pacman -Sy --noconfirm certbot-apache ;;
    apk/nginx) sudo_if_needed apk add --no-cache certbot-nginx || true ;;
    apk/apache) sudo_if_needed apk add --no-cache certbot-apache || true ;;
    zypper/nginx) sudo_if_needed zypper --non-interactive install python3-certbot-nginx || true ;;
    zypper/apache) sudo_if_needed zypper --non-interactive install python3-certbot-apache || true ;;
    *) warn "No known plugin mapping for $PKG_MGR/$websrv" ;;
  esac
}

require_certbot() {
  if ! command_exists certbot; then
    detect_pkg_manager
    if confirm "Certbot not found. Install it now? (y/N): "; then
      install_certbot
    else
      die "Certbot is required. Aborting."
    fi
  fi
}

auto_renew_status() {
  if command_exists systemctl && systemctl list-unit-files | grep -q '^certbot\.timer'; then
    info "systemd certbot.timer status:"
    systemctl status certbot.timer || true
  else
    info "No systemd timer detected. Cron may be used instead."
    crontab -l 2>/dev/null | grep -E 'certbot.*renew' || echo "No certbot renew entry in crontab."
  fi
}

enable_auto_renew() {
  if command_exists systemctl && systemctl list-unit-files | grep -q '^certbot\.timer'; then
    info "Enabling certbot.timer..."
    sudo_if_needed systemctl enable --now certbot.timer
    success "Auto-renew enabled via systemd timer."
  else
    warn "systemd certbot.timer not available. Falling back to cron." 
    local cron_line="0 3 * * * certbot renew --quiet"
    (crontab -l 2>/dev/null; echo "$cron_line") | crontab -
    success "Auto-renew scheduled via crontab (3:00 AM daily)."
  fi
}

disable_auto_renew() {
  local changed=0
  if command_exists systemctl && systemctl list-unit-files | grep -q '^certbot\.timer'; then
    info "Disabling certbot.timer..."
    sudo_if_needed systemctl disable --now certbot.timer || true
    changed=1
  fi
  # Remove cron entry if present
  if crontab -l 2>/dev/null | grep -q 'certbot.*renew'; then
    crontab -l 2>/dev/null | grep -v 'certbot.*renew' | crontab -
    changed=1
  fi
  if [[ "$changed" -eq 1 ]]; then success "Auto-renew disabled."; else info "Auto-renew not configured."; fi
}

