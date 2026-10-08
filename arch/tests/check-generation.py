"""Check a built Arch generation without activating it or needing a display."""

import configparser
from pathlib import Path
import shlex
import sys


def check_generation(generation: Path) -> None:
    profile = generation / "home-path"
    files = generation / "home-files"
    wrapped = {
        "kitty", "firefox", "google-chrome-stable", "code", "antigravity-ide",
        "Discord", "obsidian", "spotify", "Telegram", "obs", "hyprpicker", "swaync",
    }

    def check_wrapper(path: Path) -> None:
        # Depending on the app's stdenv, makeWrapper emits a shell script or ELF.
        assert b"nixGLCombinedWrapper-Nvidia" in path.read_bytes(), f"Unwrapped entry point: {path}"

    for name in wrapped:
        check_wrapper(profile / "bin" / name)

    desktop_programs = set()
    for desktop in (profile / "share/applications").glob("*.desktop"):
        for line in desktop.read_text().splitlines():
            if not line.startswith(("Exec=", "TryExec=")):
                continue
            command = shlex.split(line.split("=", 1)[1])[0]
            path = Path(command)
            if path.name in wrapped:
                check_wrapper(path if path.is_absolute() else profile / "bin" / path)
                desktop_programs.add(path.name)
    assert wrapped - {"hyprpicker", "swaync"} <= desktop_programs, desktop_programs

    telegram = profile / "share/dbus-1/services/org.telegram.desktop.service"
    command = next(line[5:] for line in telegram.read_text().splitlines() if line.startswith("Exec="))
    check_wrapper(Path(shlex.split(command)[0]))

    service_names = {"waybar", "swaync", "hypridle", "niri-polkit-agent", "nm-applet", "pasystray"}
    units = files / ".config/systemd/user"
    for name in service_names:
        unit = configparser.ConfigParser(interpolation=None, strict=False)
        unit.read(units / f"{name}.service")
        for section, key in [("Install", "WantedBy"), ("Unit", "PartOf"), ("Unit", "Requisite")]:
            assert set(unit[section][key].split()) == {"niri.service"}, (name, section, key)
    for link in units.glob("*.wants/*.service"):
        if link.stem in service_names:
            assert link.parent.name == "niri.service.wants", link

    for name in ["nm-applet", "pasystray"]:
        assert "Hidden=true" in (files / f".config/autostart/{name}.desktop").read_text()
    for name in ["org.erikreider.swaync", "org.erikreider.swaync.cc"]:
        entry = (files / f".local/share/dbus-1/services/{name}.service").read_text()
        assert "SystemdService=swaync.service" in entry
        assert "/bin/false" in entry

    niri = (files / ".config/niri/config.kdl").read_text()
    assert 'spawn-at-startup "swaync"' not in niri
    assert 'spawn-at-startup "awww-daemon"' in niri
    assert 'spawn-at-startup "wl-paste"' in niri
    assert "TMPDIR=%t" in (units / "niri.service.d/10-home-manager.conf").read_text()
    print(f"Verified {len(wrapped)} GPU packages, desktop/D-Bus entry points and niri-only services.")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("Usage: python3 arch/tests/check-generation.py GENERATION")
    check_generation(Path(sys.argv[1]))
