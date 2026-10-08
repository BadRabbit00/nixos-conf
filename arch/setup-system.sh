#!/usr/bin/env bash
set -euo pipefail

if (( EUID != 0 )); then
    echo 'Run: sudo ./arch/setup-system.sh' >&2
    exit 1
fi
# shellcheck source=/dev/null
source /etc/os-release
if [[ ${ID:-} != arch ]]; then
    echo 'This script only supports Arch Linux.' >&2
    exit 1
fi
if ! account=$(getent passwd badrabbit) || [[ $(cut -d: -f6 <<< "$account") != /home/badrabbit ]]; then
    echo 'Create user badrabbit with home /home/badrabbit before running this script.' >&2
    exit 1
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
packages=(
    niri                     # System compositor, niri-session and GDM session entry
    xwayland-satellite       # X11 applications in niri (started on demand)
    hyprlock                 # Lock screen with Arch PAM integration
    hypridle                 # Matching idle daemon
    gdm                      # Existing GNOME login screen
    gnome-shell              # GNOME session for the other accounts
    gnome-session            # GNOME session definitions
    accountsservice          # Per-user session selection remembered by GDM
    xdg-desktop-portal        # D-Bus desktop portal broker
    xdg-desktop-portal-gnome  # niri screencasting and GNOME portal backend
    xdg-desktop-portal-gtk    # File chooser and fallback portals
    nvidia-open              # RTX 5080 kernel module for Arch's standard linux kernel
    nvidia-utils             # Matching NVIDIA userspace, Vulkan ICD and nvidia-smi
    egl-wayland              # NVIDIA EGL on Wayland
    egl-gbm                  # NVIDIA EGL GBM platform
    egl-x11                  # NVIDIA EGL X11 platform for Xwayland
    vulkan-icd-loader        # Host Vulkan loader
    networkmanager          # Network service, polkit rules and nmcli
    bluez                    # Bluetooth daemon and D-Bus policy
    bluez-utils              # bluetoothctl used by Mechabar
    brightnessctl            # Backlight access and udev rules
    pipewire                 # Audio/video server, including portal screencasts
    pipewire-pulse           # PulseAudio protocol server for Waybar and apps
    wireplumber              # PipeWire session manager and wpctl
    libpulse                 # pactl and host PulseAudio client libraries
    polkit                   # System authorization daemon
    polkit-gnome              # Authentication dialog in badrabbit's niri session
    gnome-keyring            # Secrets service and GDM PAM keyring integration
    udisks2                  # Privileged disk operations for Thunar
    gvfs                     # User mounts and trash support for GTK applications
    fontconfig               # Host font discovery, including HM fontconfig rules
    bash                     # Portable script interpreter and login shell fallback
    zsh                      # Optional system login shell with HM's zsh configuration
    coreutils                # env, timeout, shuf and basic script utilities
    util-linux               # rfkill, logger and runuser
    procps-ng                # pidof, pkill, watch and ps
    gawk                     # awk used by Mechabar
    grep                     # Text filters used by Mechabar
    sed                      # Text transformations used by Mechabar
    curl                     # Weather label in hyprlock
    pacman-contrib           # checkupdates used by system-update.sh
    python                   # Lossless AccountsService update and driver metadata script
    sudo                     # Explicit system updates from system-update.sh
)

# A complete upgrade avoids unsupported partial upgrades on Arch.
pacman -Syu --needed "${packages[@]}"

session_file=/usr/share/wayland-sessions/niri.desktop
if [[ ! -f $session_file ]]; then
    echo "Missing session entry: $session_file" >&2
    exit 1
fi
session=${session_file##*/}
session=${session%.desktop}
python "$script_dir/accounts-service.py" /var/lib/AccountsService/users/badrabbit "$session"
systemctl restart accounts-daemon.service
systemctl enable --now NetworkManager.service bluetooth.service
# Do not restart the display manager underneath existing users.
systemctl enable gdm.service

cat <<'EOF'
System packages and badrabbit's GDM session are configured.
As badrabbit, run ./arch/sync-nvidia.sh, then Home Manager (see README).
After activation, run the exact sudo non-nixos-gpu-setup command printed by HM.
Reboot after a kernel/NVIDIA update before testing graphics.
EOF
