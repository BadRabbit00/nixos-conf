#!/usr/bin/env bash
# Prepare a GitHub-hosted ubuntu runner for a very large Nix build:
#  1. delete preinstalled toolchains this repo does not use (frees ~30+ GB on /);
#  2. back /nix with the big ephemeral /mnt disk (bind mount, before Nix is installed);
#  3. optionally enable /dev/kvm for NixOS VM tests.
# Usage: prepare-runner.sh [--kvm]
set -euo pipefail

echo "== disk before =="
df -h / /mnt

for d in \
  /usr/local/lib/android \
  /usr/share/dotnet \
  /usr/local/.ghcup \
  /opt/ghc \
  /usr/local/share/powershell \
  /usr/local/share/chromium \
  /usr/share/swift \
  /opt/hostedtoolcache \
  /opt/microsoft \
  /usr/local/share/boost; do
  sudo rm -rf "$d"
done
sudo docker image prune --all --force >/dev/null 2>&1 || true
sudo apt-get clean || true

# /mnt is a separate temporary disk (about 60+ GB free on standard runners).
sudo mkdir -p /mnt/nix /nix
sudo mount --bind /mnt/nix /nix

if [ "${1:-}" = "--kvm" ]; then
  echo 'KERNEL=="kvm", GROUP="kvm", MODE="0666", OPTIONS+="static_node=kvm"' \
    | sudo tee /etc/udev/rules.d/99-kvm4all.rules >/dev/null
  sudo udevadm control --reload-rules
  sudo udevadm trigger --name-match=kvm
  ls -l /dev/kvm
fi

echo "== disk after =="
df -h / /mnt /nix
