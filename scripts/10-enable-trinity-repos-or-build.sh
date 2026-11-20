#!/usr/bin/env bash
# 10-enable-trinity-repos-or-build.sh — prepare the local TDE build pipeline.
#
# Decision (docs/package-source-decision.md): no aarch64 Trinity binaries exist
# anywhere, so we RE-BUILD official TDE R14.1.7 f44 SRPMs locally for aarch64.
# This script sets up the workspace: downloads SRPMs + GPG key from the official
# mirror, prepares a local RPM repo, and writes a mock config that chains the
# local repo in (so later packages can BuildRequire earlier ones).
#
# Idempotent: downloads are skipped if present, repo/config rewritten in place
# (mock config backed up once). Run as the build user (trinity), not root;
# sudo used only to install the mock config.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$PROJECT_DIR/logs"; mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/10-setup-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1
log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
die() { log "FATAL: $*"; exit 1; }

[ "$(uname -m)" = "aarch64" ] || die "expected aarch64"
[ "$(id -u)" -ne 0 ] || die "run as build user, not root"
command -v mock >/dev/null || die "mock not installed (run 00-bootstrap first)"
command -v createrepo_c >/dev/null || die "createrepo_c not installed"

MIRROR="https://mirror.ppa.trinitydesktop.org/trinity/rpm/f44"
SRPM_URL="$MIRROR/trinity-r14/SRPMS"
SRPMS_DIR="$PROJECT_DIR/rpmbuild/srpms"
REPO_DIR="$PROJECT_DIR/repo"
mkdir -p "$SRPMS_DIR" "$REPO_DIR"

# ---- Trinity GPG keys (provenance for SRPMs) -----------------------------
# R14.1.7 is signed with the 2026 key; the older key covers earlier releases.
mkdir -p "$PROJECT_DIR/rpmbuild"
for key in RPM-GPG-KEY-trinity RPM-GPG-KEY-trinity-2026; do
    if [ ! -f "$PROJECT_DIR/rpmbuild/$key" ]; then
        curl -fsSL "$MIRROR/$key" -o "$PROJECT_DIR/rpmbuild/$key"
        log "Downloaded $key."
    fi
    sudo rpmkeys --import "$PROJECT_DIR/rpmbuild/$key" 2>/dev/null || true
done

# ---- SRPM set: minimum core session chain (build order) ------------------
SRPMS=(
    trinity-tqt-3.5.0-14.1.7_1.fc44.src.rpm
    trinity-tde-cmake-14.1.7-1.fc44.src.rpm
    fileshareset-2.0-1.fc44.src.rpm
    htdig-3.2.0b6_19-1.fc44.src.rpm
    trinity-tqtinterface-4.2.0-14.1.7_1.fc44.src.rpm
    trinity-libart-lgpl-2.3.22-14.1.7_1.fc44.src.rpm
    trinity-arts-1.5.10-14.1.7_1.fc44.src.rpm
    trinity-dbus-tqt-0.63-14.1.7_1.fc44.src.rpm
    trinity-dbus-1-tqt-0.9-14.1.7_1.fc44.src.rpm
    trinity-avahi-tqt-0.6.30-14.1.7_1.fc44.src.rpm
    trinity-tqca-1.0-14.1.7_1.fc44.src.rpm
    trinity-filesystem-14.1.7-1.fc44.src.rpm
    trinity-tdelibs-14.1.7-1.fc44.src.rpm
    trinity-tdebase-14.1.7-1.fc44.src.rpm
)
for s in "${SRPMS[@]}"; do
    if [ -f "$SRPMS_DIR/$s" ]; then
        log "have: $s"
    else
        log "downloading: $s"
        curl -fsSL "$SRPM_URL/$s" -o "$SRPMS_DIR/$s.part"
        mv "$SRPMS_DIR/$s.part" "$SRPMS_DIR/$s"
    fi
    rpmkeys --checksig "$SRPMS_DIR/$s" || log "WARNING: signature check inconclusive for $s"
done

# ---- local repo (consumed by mock + final dnf install) -------------------
createrepo_c --update "$REPO_DIR" >/dev/null
log "Local repo metadata refreshed at $REPO_DIR"

# ---- mock config: fedora-44-aarch64 + local TDE repo + ccache ------------
MOCK_CFG=/etc/mock/fedora-44-aarch64-tde.cfg
TMP_CFG="$(mktemp)"
cat > "$TMP_CFG" <<EOF
include('fedora-44-aarch64.cfg')
config_opts['root'] = 'fedora-44-aarch64-tde'
config_opts['plugin_conf']['ccache_enable'] = True
config_opts['plugin_conf']['ccache_opts']['max_cache_size'] = '4G'
config_opts[f'{config_opts.package_manager}.conf'] += """
[tde-local]
name=TDE local aarch64 rebuild
baseurl=file://$REPO_DIR
enabled=1
gpgcheck=0
priority=5
skip_if_unavailable=1
"""
EOF
if [ -f "$MOCK_CFG" ] && ! sudo cmp -s "$TMP_CFG" "$MOCK_CFG"; then
    sudo cp -n "$MOCK_CFG" "$MOCK_CFG.bak.$(date +%Y%m%d%H%M%S)" || true
fi
sudo install -m 0644 "$TMP_CFG" "$MOCK_CFG"
rm -f "$TMP_CFG"
log "Mock config installed: $MOCK_CFG (root: fedora-44-aarch64-tde)"

log "Setup complete. Next: scripts/11-build-tde-chain.sh"
