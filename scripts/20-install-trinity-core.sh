#!/usr/bin/env bash
# 20-install-trinity-core.sh — install locally built Trinity packages via DNF.
# Run AS ROOT (prlctl exec) after 11-build-tde-chain.sh completes.
#
# Registers the local repo as a proper dnf repo (so packages are managed,
# upgradable, removable — no /usr/local side-installs), then installs the
# core session set. Idempotent.
set -euo pipefail
log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
die() { log "FATAL: $*"; exit 1; }

[ "$(id -u)" -eq 0 ] || die "must run as root"
PROJECT_DIR="/home/trinity/fedora-trinity-arm64"
REPO_DIR="$PROJECT_DIR/repo"
[ -d "$REPO_DIR/repodata" ] || die "local repo has no metadata — build chain finished?"

REPO_FILE=/etc/yum.repos.d/tde-local.repo
if [ -f "$REPO_FILE" ]; then
    cmp -s "$REPO_FILE" /dev/null || cp -n "$REPO_FILE" "$REPO_FILE.bak" || true
fi
cat > "$REPO_FILE" <<EOF
[tde-local]
name=TDE local aarch64 rebuild
baseurl=file://$REPO_DIR
enabled=1
gpgcheck=0
priority=5
EOF
log "Registered local repo: $REPO_FILE"

# Core Trinity session set (binary package names from the local repo; the
# toolkit stack libtqt3-mt/libtqt4/arts etc. is pulled in as dependencies).
PKGS=(
    trinity-filesystem
    trinity-tdelibs
    trinity-tdebase
    trinity-twin
    trinity-kicker
    trinity-kdesktop
    trinity-ksmserver
    trinity-konsole
    trinity-klipper
    trinity-kcontrol
    trinity-tdm
)
dnf -y install "${PKGS[@]}"

log "Installed. Key session binaries:"
for b in starttde konsole kicker kdesktop twin ksmserver tdm; do
    p="$(command -v "$b" 2>/dev/null || ls /opt/trinity/bin/$b 2>/dev/null || true)"
    printf '  %-10s %s\n' "$b" "${p:-NOT FOUND}"
done
