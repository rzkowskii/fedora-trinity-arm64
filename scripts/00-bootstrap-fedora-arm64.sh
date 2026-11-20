#!/usr/bin/env bash
# 00-bootstrap-fedora-arm64.sh — install build + desktop runtime prerequisites
# for the Fedora ARM64 Trinity project. Idempotent: dnf skips installed pkgs.
# Safe: additive only (package installs + one group membership); no removals,
# no config overwrites.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$PROJECT_DIR/logs"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/00-bootstrap-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
die() { log "FATAL: $*"; exit 1; }

# ---- safety checks -------------------------------------------------------
[ "$(uname -m)" = "aarch64" ] || die "expected aarch64, got $(uname -m)"
. /etc/os-release
[ "${ID:-}" = "fedora" ] || die "expected Fedora, got ${ID:-unknown}"
[ "${VERSION_ID:-0}" -ge 44 ] || die "expected Fedora >= 44, got ${VERSION_ID:-unknown}"

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    sudo -n true 2>/dev/null || die "need root or passwordless sudo"
    SUDO="sudo"
fi

log "Bootstrap starting on Fedora ${VERSION_ID} $(uname -m), kernel $(uname -r)"

# ---- package sets --------------------------------------------------------
# fedpkg intentionally omitted: it targets Fedora dist-git workflows; TDE
# SRPMs come from TDE upstream, plain rpmbuild/mock is sufficient.
RPM_TOOLS=(
    rpmdevtools mock dnf-plugins-core rpmlint createrepo_c
    rpm-build redhat-rpm-config rpm-sign
)
BUILD_TOOLS=(
    gcc gcc-c++ make cmake ninja-build git autoconf automake libtool
    patch ccache pkgconf-pkg-config
)
XORG=(
    xorg-x11-server-Xorg xorg-x11-xinit xorg-x11-drv-libinput
    xorg-x11-xauth xterm xrandr xset xsetroot xdpyinfo xev
    mesa-dri-drivers mesa-libGL mesa-libEGL
)
DBUS=(dbus dbus-x11 dbus-tools)
FONTS=(
    dejavu-sans-fonts dejavu-serif-fonts dejavu-sans-mono-fonts
    liberation-sans-fonts liberation-serif-fonts liberation-mono-fonts
    fontconfig xorg-x11-fonts-misc
)
SOUND=(pipewire pipewire-alsa pipewire-pulseaudio wireplumber alsa-utils)
NET=(NetworkManager network-manager-applet)
UTIL=(rsync curl wget tar xz bzip2 unzip file htop)

ALL=("${RPM_TOOLS[@]}" "${BUILD_TOOLS[@]}" "${XORG[@]}" "${DBUS[@]}"
     "${FONTS[@]}" "${SOUND[@]}" "${NET[@]}" "${UTIL[@]}")

log "Installing ${#ALL[@]} packages (single transaction, skipping unavailable)"
$SUDO dnf -y install --skip-unavailable "${ALL[@]}"

# Report anything that did not land so gaps are explicit, not silent.
MISSING=()
for p in "${ALL[@]}"; do
    rpm -q "$p" >/dev/null 2>&1 || MISSING+=("$p")
done
if [ "${#MISSING[@]}" -gt 0 ]; then
    log "WARNING: not installed (unavailable on this arch/release): ${MISSING[*]}"
else
    log "All requested packages present."
fi

# ---- mock group ----------------------------------------------------------
BUILD_USER="${SUDO_USER:-trinity}"
if id "$BUILD_USER" >/dev/null 2>&1; then
    if id -nG "$BUILD_USER" | tr ' ' '\n' | grep -qx mock; then
        log "User $BUILD_USER already in mock group."
    else
        $SUDO usermod -aG mock "$BUILD_USER"
        log "Added $BUILD_USER to mock group (re-login required to take effect)."
    fi
fi

log "Bootstrap complete. Log: $LOG"
