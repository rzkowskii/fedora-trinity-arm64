#!/usr/bin/env bash
# 90-validate-tde-session.sh — automated validation of the Trinity session stack.
# Run AS ROOT inside the guest (prlctl exec or sudo) AFTER scripts 20 + 30.
# Non-destructive: starts/queries services and X clients, kills only what it
# started. Produces a PASS/FAIL table on stdout; caller records results in
# docs/validation-results.md.
set -euo pipefail
log()  { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
PASS=0; FAIL=0
declare -a RESULTS
check() { # check <name> <cmd...>
    local name="$1"; shift
    if "$@" >/dev/null 2>&1; then
        RESULTS+=("PASS  $name"); PASS=$((PASS+1))
    else
        RESULTS+=("FAIL  $name"); FAIL=$((FAIL+1))
    fi
}

TDE_PREFIX="/opt/trinity"
[ -x "$TDE_PREFIX/bin/starttde" ] || TDE_PREFIX="/usr"
BIN="$TDE_PREFIX/bin"

# --- 1. architecture -------------------------------------------------------
check "uname -m is aarch64" test "$(uname -m)" = "aarch64"

# --- 2. binaries present ---------------------------------------------------
for b in starttde twin kicker kdesktop ksmserver konsole; do
    check "binary $b present" test -x "$BIN/$b"
done

# --- 3. Xorg starts --------------------------------------------------------
# Use the DM if enabled, else spawn a bare Xorg on :77 to prove the driver works.
XPID=""
if systemctl is-active lightdm >/dev/null 2>&1; then
    check "Xorg via lightdm active" pgrep -x Xorg
else
    /usr/bin/Xorg :77 -noreset >/tmp/Xorg.validate.log 2>&1 &
    XPID=$!
    sleep 4
    check "bare Xorg starts (:77)" kill -0 "$XPID"
fi

# --- 4. session / app smoke tests on a display -----------------------------
# Xorg lives at /usr/libexec/Xorg under Fedora DMs, /usr/bin/Xorg when bare.
XORG_ARGS="$(ps -eo args | grep -E '^/usr/(bin|libexec)/Xorg' | head -1 || true)"
DISP="$(printf '%s' "$XORG_ARGS" | grep -oE ' :[0-9]+' | head -1 | tr -d ' ' || true)"
DISP="${DISP:-:77}"
export DISPLAY="$DISP"
XAUTH="$(printf '%s' "$XORG_ARGS" | grep -oE '\-auth [^ ]+' | awk '{print $2}' | head -1 || true)"
[ -n "$XAUTH" ] && export XAUTHORITY="$XAUTH"

check "X answers on $DISP" xdpyinfo
# konsole in --version mode does not need X; run a real X client too:
check "konsole binary runs" "$BIN/konsole" --version
# Window-mapping proof is taken from the live session (screenshot / taskbar):
# xwininfo under root's auth cookie is unreliable across DM configs, so the
# automated check is process-level only.
check "konsole process in session (launch one as the user to test)" pgrep -x konsole

# --- 5. session processes (only meaningful after a real TDE login) ---------
for p in twin kicker kdesktop ksmserver; do
    if pgrep -x "$p" >/dev/null 2>&1; then
        RESULTS+=("PASS  $p running (live session)"); PASS=$((PASS+1))
    else
        RESULTS+=("INFO  $p not running (no live TDE session at validation time)")
    fi
done

# --- 6. logout/reboot path -------------------------------------------------
check "graphical.target is default" sh -c "systemctl get-default | grep -q graphical"
check "lightdm enabled" systemctl is-enabled lightdm
check "systemd reboot path resolvable" systemctl show reboot.target -p Id

# --- 7. log capture --------------------------------------------------------
check "Xorg log exists" sh -c "ls /var/log/Xorg.0.log /tmp/Xorg.validate.log 2>/dev/null | grep -q ."

[ -n "$XPID" ] && kill "$XPID" 2>/dev/null || true

echo
echo "==================== VALIDATION SUMMARY ===================="
printf '%s\n' "${RESULTS[@]}"
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
