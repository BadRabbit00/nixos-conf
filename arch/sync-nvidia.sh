#!/usr/bin/env bash
set -euo pipefail

if (( EUID == 0 )); then
    echo 'Run this script as the repository owner, without sudo.' >&2
    exit 1
fi
if [[ $# -gt 1 || ( $# -eq 1 && $1 != --check ) ]]; then
    echo 'Usage: ./arch/sync-nvidia.sh [--check]' >&2
    exit 1
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
driver_file="$script_dir/nvidia-driver.json"
# Arch's epoch and pkgrel are not part of NVIDIA's upstream driver version.
read -r _ package_version < <(pacman -Q nvidia-utils)
driver_version=${package_version#*:}
driver_version=${driver_version%-*}
if [[ ! $driver_version =~ ^[0-9]{3}\.[0-9]{2,3}(\.[0-9]{2,3})?$ ]]; then
    echo "Unrecognized NVIDIA version: $package_version" >&2
    exit 1
fi

if [[ ${1:-} == --check ]]; then
    python - "$driver_file" "$driver_version" <<'PY'
import json, sys
expected = json.load(open(sys.argv[1]))["version"]
if expected != sys.argv[2]:
    sys.exit(f"NVIDIA mismatch: HM={expected}, Arch={sys.argv[2]}. Run ./arch/sync-nvidia.sh and rebuild HM.")
print(f"NVIDIA version matches Arch: {expected}")
PY
    exit 0
fi

url="https://download.nvidia.com/XFree86/Linux-x86_64/$driver_version/NVIDIA-Linux-x86_64-$driver_version.run"
prefetch=$(nix store prefetch-file --json "$url")
driver_hash=$(python -c 'import json,sys; print(json.load(sys.stdin)["hash"])' <<< "$prefetch")
python - "$driver_file" "$driver_version" "$driver_hash" <<'PY'
import json, os, pathlib, re, sys, tempfile
path = pathlib.Path(sys.argv[1])
if not re.fullmatch(r"sha256-[A-Za-z0-9+/]{43}=", sys.argv[3]):
    sys.exit("Invalid SHA-256 returned by nix store prefetch-file")
data = json.dumps({"version": sys.argv[2], "sha256": sys.argv[3]}, indent=2) + "\n"
if path.read_text() != data:
    fd, temporary = tempfile.mkstemp(prefix=".nvidia-driver.", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            stream.write(data)
        os.chmod(temporary, 0o644)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
print(f"{path}: NVIDIA {sys.argv[2]}")
PY
echo 'Now rebuild Home Manager and run its printed sudo non-nixos-gpu-setup command.'
