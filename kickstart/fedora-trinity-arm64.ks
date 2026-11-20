# fedora-trinity-arm64.ks — Fedora 44 aarch64 Trinity Desktop remix
# Build: livemedia-creator --make-disk --no-virt --ks this-file (see docs/remix-build-plan.md)
# Status: DRAFT — package list will be finalized from docs/package-manifest.md
#         after Stage 7 validation of the reference VM.

# --- localization / basics --------------------------------------------------
lang en_US.UTF-8
keyboard us
timezone Australia/Sydney --utc
rootpw --lock
selinux --enforcing
firewall --enabled --service=mdns
services --enabled=NetworkManager,lightdm --disabled=sshd
network --bootproto=dhcp --device=link --activate

# --- storage (raw disk image; total size via livemedia-creator --image-size) -
zerombr
clearpart --all --initlabel --disklabel=gpt
# no reqpart: the ESP is declared explicitly below (reqpart would duplicate it)
part /boot/efi --size=600 --fstype=efi
part /boot     --size=1024 --fstype=ext4
# explicit size: lmc computes the disk image size as the sum of part sizes,
# a bare --grow (size=None) breaks that; --grow still expands on real disks.
# ext4 (not btrfs): plain part+btrfs fails to mount inside lmc --no-virt
# (anaconda namespace); revisit with proper `btrfs` subvolume commands later.
part /         --size=9500 --grow --fstype=ext4

# --leavebootorder: skip efibootmgr NVRAM writes — impossible (and wrong) in
# an image build; the image boots via the ESP fallback EFI/BOOT/BOOTAA64.EFI
bootloader --timeout=1 --leavebootorder

# --- users -------------------------------------------------------------------
# Test-image credential (documented): change or replace with firstboot/initial-setup
# before any real distribution. root stays locked.
user --name=trinity --groups=wheel --password=trinity --plaintext --gecos="Trinity"

# --- repositories ------------------------------------------------------------
# url/repo lines are consumed by livemedia-creator; releasever=44
url --mirrorlist="https://mirrors.fedoraproject.org/mirrorlist?repo=fedora-44&arch=aarch64"
repo --name=updates --mirrorlist="https://mirrors.fedoraproject.org/mirrorlist?repo=updates-released-f44&arch=aarch64"
# Local aarch64 Trinity rebuild (Stage 4 output), served over loopback HTTP by
# scripts/40-build-remix-image.sh for the duration of the build (anaconda
# fails to load file:// additional repos in --no-virt mode: it sets them up as
# sources and tears them down without loading metadata). For distributable
# images point this at a hosted/signed repo — see docs/remix-build-plan.md.
repo --name=tde-local --baseurl=http://127.0.0.1:8123/

# --- packages ----------------------------------------------------------------
%packages
@core
@hardware-support
@fonts
@networkmanager-submodules

# X11 stack (see scripts/00-bootstrap-fedora-arm64.sh — kept in sync)
xorg-x11-server-Xorg
xorg-x11-xinit
xorg-x11-drv-libinput
xorg-x11-xauth
mesa-dri-drivers
xterm

# display manager (Stage 5 decision: lightdm first; tdm under evaluation)
lightdm
lightdm-gtk

# sound
pipewire
pipewire-alsa
pipewire-pulseaudio
wireplumber

# NOTE: the Trinity packages are installed in %post, not here — anaconda in
# lmc --no-virt mode registers additional `repo` lines but never loads their
# metadata before %packages resolution ("No match for argument"), regardless
# of file:// or http:// baseurl. %post dnf against the loopback repo works.

# BRANDING TODO (distribution blocker): a remix must swap fedora-logos for
# generic-logos, but trinity-tdebase (as shipped upstream) hard-Requires
# fedora-logos — the two conflict. Until tdebase is rebuilt with
# "Requires: system-logos" (upstream PR candidate), this TEST image keeps
# fedora-logos and must not be redistributed. See docs/remix-build-plan.md.

# trim for image size
-@dial-up
-@input-methods
%end

# --- post ---------------------------------------------------------------------
%post --erroronfail
# set -e: without it a failing dnf would be masked by later commands and
# --erroronfail would never trigger (this bit us: build 'succeeded' with no TDE).
set -e
# Install the Trinity set from the loopback repo served by scripts/40 (see the
# %packages note: anaconda won't resolve additional repos itself in this mode).
cat > /etc/yum.repos.d/tde-build-local.repo <<'EOF'
[tde-build-local]
name=TDE local build repo (image build time only)
baseurl=http://127.0.0.1:8123/
enabled=1
gpgcheck=0
EOF
dnf -y install trinity-filesystem trinity-tdelibs trinity-tdebase \
    trinity-twin trinity-kicker trinity-kdesktop trinity-ksmserver \
    trinity-konsole trinity-klipper trinity-kcontrol
rm -f /etc/yum.repos.d/tde-build-local.repo

# Trinity xsession fallback entry (mirrors scripts/30-configure-trinity-session.sh)
if [ ! -e /usr/share/xsessions/tde.desktop ] && [ ! -e /usr/share/xsessions/trinity.desktop ]; then
cat > /usr/share/xsessions/trinity.desktop <<'EOF'
[Desktop Entry]
Encoding=UTF-8
Name=Trinity
Comment=Trinity Desktop Environment (TDE R14)
Exec=/opt/trinity/bin/starttde
TryExec=/opt/trinity/bin/starttde
Type=XSession
EOF
fi
systemctl set-default graphical.target
%end
