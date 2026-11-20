#!/usr/bin/env bash
# 12-root-setup-mock.sh — root-side companion to 10-enable-trinity-repos-or-build.sh
# Run AS ROOT (e.g. via `prlctl exec`). Does exactly two things:
#   1. import the Trinity GPG keys into the rpm keyring
#   2. install the mock chroot config for the TDE aarch64 rebuild
# Idempotent; backs up an existing differing mock config once per change.
set -euo pipefail
log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
die() { log "FATAL: $*"; exit 1; }

[ "$(id -u)" -eq 0 ] || die "must run as root"
PROJECT_DIR="/home/trinity/fedora-trinity-arm64"
REPO_DIR="$PROJECT_DIR/repo"
KEY_DIR="$PROJECT_DIR/rpmbuild"

for key in RPM-GPG-KEY-trinity RPM-GPG-KEY-trinity-2026; do
    [ -f "$KEY_DIR/$key" ] || die "missing $KEY_DIR/$key (run script 10 first)"
    rpmkeys --import "$KEY_DIR/$key"
done
log "Trinity GPG key imported: $(rpm -q gpg-pubkey --qf '%{NAME}-%{VERSION}:%{SUMMARY}\n' | grep -ic trinity || true) trinity key(s) in keyring"

MOCK_CFG=/etc/mock/fedora-44-aarch64-tde.cfg
TMP_CFG="$(mktemp)"
cat > "$TMP_CFG" <<EOF
include('fedora-44-aarch64.cfg')
config_opts['root'] = 'fedora-44-aarch64-tde'
config_opts['plugin_conf']['ccache_enable'] = True
config_opts['plugin_conf']['ccache_opts']['max_cache_size'] = '4G'
# TDE specs package .la files (TDE's autotools consume them), but Fedora's
# brp-remove-la-files policy deletes them from the buildroot before %files.
# Upstream TDE build farms don't run this policy; disable it for this chroot.
config_opts['macros']['%__brp_remove_la_files'] = '%{nil}'
# Fedora 44 buildroots no longer include compilers by default and several TDE
# specs (e.g. trinity-tde-cmake) omit BuildRequires: gcc/gcc-c++ because the
# upstream farm injects them. Mirror that here.
config_opts['chroot_additional_packages'] = 'gcc gcc-c++ perl-interpreter'
# TDE specs use the legacy pattern "mkdir build + cd build + %cmake .. + make".
# Fedora's %cmake injects -S/-B (out-of-source redhat-linux-build dir), which
# strands the Makefiles away from where the spec runs make. In-source mode
# restores the behaviour the specs (and upstream's farm) expect.
# NOTE: this heredoc is unquoted (needs $REPO_DIR) — never put backticks here.
config_opts['macros']['%__cmake_in_source_build'] = '1'
# F44 %cmake defaults to the Ninja generator; TDE specs invoke plain make.
# The macro expands unquoted (-G %{_cmake_generator}) so the two-word generator
# needs embedded double quotes.
config_opts['macros']['%_cmake_generator'] = '"Unix Makefiles"'
# With ccache enabled, debugedit yields an empty debugsourcefiles.list for some
# TDE packages (tqtinterface) and rpmbuild hard-fails on the empty %files.
# rpm 6 ignored %_debugsource_packages=0 in ~/.rpmmacros, so disable debug
# subpackages entirely for this chroot (acceptable for the desktop milestone;
# revisit if -debuginfo is ever needed).
config_opts['macros']['%debug_package'] = '%{nil}'
# TDE installs under /opt/trinity with RPATH /opt/trinity/lib64 by design;
# Fedora's check-rpaths brp flags that as ERROR 0002 and fails %install.
config_opts['macros']['%__brp_check_rpaths'] = '%{nil}'
# tdelibs needs the utempter helper, which is executable-but-not-readable on
# Fedora; TDE's old cmake_minimum_required leaves CMP0109 at OLD (helper
# rejected). Default the policy to NEW via the %__cmake entry point.
config_opts['macros']['%__cmake'] = '/usr/bin/cmake -DCMAKE_POLICY_DEFAULT_CMP0109=NEW'
# The R14.1.7 SRPMs carry the 14.1.7 tarball, but each spec still falls back to
# tde_version 14.1.6 unless the build farm defines it (first failure: tqt looked
# for trinity-tqt-14.1.6.tar.gz). Define it for this chroot.
config_opts['macros']['%tde_version'] = '14.1.7'
config_opts['dnf5.conf'] += """
[tde-local]
name=TDE local aarch64 rebuild
baseurl=file://$REPO_DIR
enabled=1
gpgcheck=0
priority=5
skip_if_unavailable=1
"""
EOF
if [ -f "$MOCK_CFG" ] && ! cmp -s "$TMP_CFG" "$MOCK_CFG"; then
    cp "$MOCK_CFG" "$MOCK_CFG.bak.$(date +%Y%m%d%H%M%S)"
fi
install -m 0644 "$TMP_CFG" "$MOCK_CFG"
rm -f "$TMP_CFG"
log "Mock config installed at $MOCK_CFG"
