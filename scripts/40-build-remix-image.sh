#!/usr/bin/env bash
# 40-build-remix-image.sh — build the Fedora Trinity ARM64 remix disk image
# with livemedia-creator (Stage 8, docs/remix-build-plan.md).
# Run AS ROOT inside the guest. Produces a raw disk image under RESULT_BASE.
#
# Notes:
# - --no-virt runs anaconda directly in this VM (no nested virt on Apple
#   Silicon). lorax documents that novirt builds want SELinux permissive;
#   we set permissive for the build and restore the previous mode after.
# - Idempotent-ish: each run writes to a fresh timestamped resultdir.
set -euo pipefail
log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
die() { log "FATAL: $*"; exit 1; }

[ "$(id -u)" -eq 0 ] || die "must run as root"
[ "$(uname -m)" = "aarch64" ] || die "expected aarch64"

PROJECT_DIR="/home/trinity/fedora-trinity-arm64"
KS="$PROJECT_DIR/kickstart/fedora-trinity-arm64.ks"
RESULT_BASE="/var/tmp/tde-image"
RESULT_DIR="$RESULT_BASE/$(date +%Y%m%d-%H%M%S)"
LOG_DIR="$PROJECT_DIR/logs"
# image size = sum of kickstart part sizes (~11GiB); this is only the
# free-space preflight guard
IMAGE_SIZE_GIB=11

[ -f "$KS" ] || die "kickstart not found: $KS"
[ -d "$PROJECT_DIR/repo/repodata" ] || die "local TDE repo missing"

log "Installing image build tooling (idempotent)"
dnf -y -q install lorax-lmc-novirt pykickstart anaconda-tui >/dev/null

log "Validating kickstart"
ksvalidator "$KS" || die "kickstart failed validation"

FREE_GB=$(df --output=avail -BG /var/tmp | tail -1 | tr -dc '0-9')
[ "$FREE_GB" -ge $((IMAGE_SIZE_GIB + 6)) ] || die "need ~$((IMAGE_SIZE_GIB + 6))G free in /var/tmp, have ${FREE_GB}G"

PREV_ENFORCE="$(getenforce)"
REPO_HTTP_PID=""
FAKE_EFIBOOTMGR=""
restore() {
    [ -n "$REPO_HTTP_PID" ] && kill "$REPO_HTTP_PID" 2>/dev/null || true
    [ -n "$FAKE_EFIBOOTMGR" ] && umount /usr/sbin/efibootmgr 2>/dev/null || true
    [ "$PREV_ENFORCE" = "Enforcing" ] && setenforce 1 || true
}
trap restore EXIT

# anaconda 44 bug: EFIBase.efibootmgr() correctly SKIPS efibootmgr for image
# installs, but the skip path `return ""` fails the caller's `if rc != 0`
# check, raising "Failed to set new efi boot target" on every image build.
# Patch the two skip paths to return 0. (The capture=True caller — boot entry
# removal — would break on an int, but our kickstart's --leavebootorder skips
# removal entirely, so the paths never meet.) Original kept as .bak.tde.
EFI_PY=/usr/lib64/python3.14/site-packages/pyanaconda/modules/storage/bootloader/efi.py
if [ -f "$EFI_PY" ] && grep -qE 'Skipping efibootmgr for (image/directory install|noefi)' "$EFI_PY"; then
    cp -n "$EFI_PY" "$EFI_PY.bak.tde"
    python3 - "$EFI_PY" <<'PYEOF'
import sys
p = sys.argv[1]
src = open(p).read()
patched = src.replace(
    'log.info("Skipping efibootmgr for image/directory install.")\n            return ""',
    'log.info("Skipping efibootmgr for image/directory install.")\n            return 0'
).replace(
    'log.info("Skipping efibootmgr for noefi")\n            return ""',
    'log.info("Skipping efibootmgr for noefi")\n            return 0'
)
if patched != src:
    open(p, "w").write(patched)
    print("efi.py: skip paths patched to return 0")
else:
    print("efi.py: already patched or pattern changed — no edit")
PYEOF
fi
if [ "$PREV_ENFORCE" = "Enforcing" ]; then
    log "setenforce 0 for novirt anaconda run (restored on exit)"
    setenforce 0
fi

# Serve the local repo over loopback HTTP for anaconda (see kickstart comment:
# file:// additional repos never get their metadata loaded in --no-virt mode).
python3 -m http.server 8123 --bind 127.0.0.1 --directory "$PROJECT_DIR/repo" \
    >/dev/null 2>&1 &
REPO_HTTP_PID=$!
sleep 1
curl -sf "http://127.0.0.1:8123/repodata/repomd.xml" >/dev/null \
    || die "loopback repo server failed to start"
log "Loopback repo server on 127.0.0.1:8123 (pid $REPO_HTTP_PID)"

# lmc creates RESULT_DIR itself and refuses a pre-existing one; only the base
# may exist. --nomacboot: no hfsplus-tools on Fedora aarch64 (and no Mac boot
# support needed).
mkdir -p "$RESULT_BASE"
LMC_LOG_DIR="$RESULT_BASE/lmc-logs-$(basename "$RESULT_DIR")"
mkdir -p "$LMC_LOG_DIR"
log "Starting livemedia-creator (resultdir: $RESULT_DIR; size from kickstart parts)"
livemedia-creator \
    --make-disk \
    --no-virt \
    --nomacboot \
    --ks "$KS" \
    --project "Fedora Trinity Remix" \
    --releasever 44 \
    --image-name fedora-trinity-arm64.img \
    --resultdir "$RESULT_DIR" \
    --logfile "$LMC_LOG_DIR/lmc.log" \
    && RC=0 || RC=$?

if [ "$RC" -eq 0 ]; then
    log "IMAGE BUILD OK"
    ls -lh "$RESULT_DIR"
else
    log "IMAGE BUILD FAILED (rc=$RC) — logs in $LMC_LOG_DIR and $RESULT_DIR"
fi
exit "$RC"
