#!/usr/bin/env bash
# 11-build-tde-chain.sh — build the TDE SRPM chain for aarch64 with mock.
#
# Builds packages in dependency order. After each success the RPMs are copied
# into the local repo and the repo metadata is refreshed, so later packages can
# resolve BuildRequires on earlier ones. A failed package stops the chain
# (dependencies would fail anyway) but leaves its full mock logs isolated under
# logs/mock/<pkg>/ and records the failure in docs/build-failures.md.
#
# Usage: 11-build-tde-chain.sh [start-package]
#   start-package: optional SRPM basename prefix to resume from (skips earlier).
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$PROJECT_DIR/logs"; mkdir -p "$LOG_DIR/mock"
LOG="$LOG_DIR/11-build-chain-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1
log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
die() { log "FATAL: $*"; exit 1; }

[ "$(uname -m)" = "aarch64" ] || die "expected aarch64"
[ "$(id -u)" -ne 0 ] || die "run as build user (in mock group), not root"
id -nG | tr ' ' '\n' | grep -qx mock || die "user not in mock group (re-login?)"

SRPMS_DIR="$PROJECT_DIR/rpmbuild/srpms"
REPO_DIR="$PROJECT_DIR/repo"
MOCK_ROOT="fedora-44-aarch64-tde"
FAILDOC="$PROJECT_DIR/docs/build-failures.md"

CHAIN=(
    trinity-tqt-3.5.0-14.1.7_1.fc44.src.rpm
    trinity-tde-cmake-14.1.7-1.fc44.src.rpm
    # filesystem early: BuildRequires of arts/tdelibs (provides /opt/trinity dirs)
    trinity-filesystem-14.1.7-1.fc44.src.rpm
    fileshareset-2.0-1.fc44.src.rpm
    htdig-3.2.0b6_19-1.fc44.src.rpm
    trinity-tqtinterface-4.2.0-14.1.7_1.fc44.src.rpm
    trinity-libart-lgpl-2.3.22-14.1.7_1.fc44.src.rpm
    trinity-arts-1.5.10-14.1.7_1.fc44.src.rpm
    trinity-dbus-tqt-0.63-14.1.7_1.fc44.src.rpm
    trinity-dbus-1-tqt-0.9-14.1.7_1.fc44.src.rpm
    trinity-avahi-tqt-0.6.30-14.1.7_1.fc44.src.rpm
    trinity-tqca-1.0-14.1.7_1.fc44.src.rpm
    trinity-tdelibs-14.1.7-1.fc44.src.rpm
    trinity-tdebase-14.1.7-1.fc44.src.rpm
)

# already_built <srpm>: marker file written after a successful build+repo copy.
# (Binary package names often differ from the SRPM name — e.g. trinity-tqt
# produces libtqt3-mt* — so repo globbing by SRPM name is not reliable.)
BUILT_DIR="$LOG_DIR/.built"
mkdir -p "$BUILT_DIR"
already_built() { [ -f "$BUILT_DIR/$1.done" ]; }

START="${1:-}"
SKIPPING=false
[ -n "$START" ] && SKIPPING=true

for srpm in "${CHAIN[@]}"; do
    if $SKIPPING; then
        case "$srpm" in "$START"*) SKIPPING=false ;; *) log "skip (before start): $srpm"; continue ;; esac
    fi
    [ -f "$SRPMS_DIR/$srpm" ] || die "missing SRPM: $srpm (run 10-enable-trinity-repos-or-build.sh)"

    if already_built "$srpm"; then
        log "already built: $srpm — skipping"
        continue
    fi

    pkg="${srpm%.src.rpm}"
    result_dir="$LOG_DIR/mock/$pkg"
    mkdir -p "$result_dir"
    log "=== BUILD START: $pkg ==="
    t0=$SECONDS
    if mock -r "$MOCK_ROOT" --resultdir "$result_dir" --no-cleanup-after \
            --rebuild "$SRPMS_DIR/$srpm"; then
        dur=$(( (SECONDS - t0) / 60 ))
        cp -v "$result_dir"/*.aarch64.rpm "$result_dir"/*.noarch.rpm "$REPO_DIR"/ 2>/dev/null || true
        rm -f "$REPO_DIR"/*.src.rpm
        createrepo_c --update "$REPO_DIR" >/dev/null
        touch "$BUILT_DIR/$srpm.done"
        log "=== BUILD OK: $pkg (${dur} min) — repo updated ==="
    else
        dur=$(( (SECONDS - t0) / 60 ))
        log "=== BUILD FAILED: $pkg (${dur} min) — see $result_dir ==="
        {
            echo "## $pkg — FAILED $(date '+%Y-%m-%d %H:%M')"
            echo ""
            echo "- Mock root: $MOCK_ROOT; duration: ${dur} min"
            echo "- Logs: \`logs/mock/$pkg/\` (build.log, root.log)"
            echo "- Last errors:"
            echo '```'
            grep -iE 'error|failed' "$result_dir/build.log" 2>/dev/null | tail -15
            echo '```'
            echo ""
        } >> "$FAILDOC"
        die "chain stopped at $pkg (failure recorded in docs/build-failures.md)"
    fi
done

log "Chain complete. Local repo: $REPO_DIR"
ls -la "$REPO_DIR" | head -40
