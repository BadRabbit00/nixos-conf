"""Update only the requested [User] keys, preserving other AccountsService data."""

import os
from pathlib import Path
import re
import sys
import tempfile


def update_session(contents: str, session: str) -> str:
    if not re.fullmatch(r"[A-Za-z0-9_.-]+", session):
        raise ValueError("Invalid desktop session name")
    values = {"Session": session, "SessionType": "wayland", "SystemAccount": "false"}
    lines = contents.splitlines(keepends=True)
    result = []
    in_user = False
    found_user = False
    seen = set()

    def add_missing():
        if result and not result[-1].endswith("\n"):
            result[-1] += "\n"
        result.extend(f"{key}={value}\n" for key, value in values.items() if key not in seen)

    for line in lines:
        section = re.fullmatch(r"\s*\[([^\]]+)\]\s*", line)
        if section:
            if in_user:
                add_missing()
            in_user = section[1] == "User"
            if in_user:
                if found_user:
                    raise ValueError("Duplicate [User] sections; refusing an ambiguous update")
                found_user = True
        key = re.match(r"\s*([^=#;\s]+)\s*=", line) if in_user else None
        if key and key[1] in values:
            name = key[1]
            if name not in seen:
                result.append(f"{name}={values[name]}\n")
                seen.add(name)
        else:
            result.append(line)

    if in_user:
        add_missing()
    elif not found_user:
        if result and not result[-1].endswith("\n"):
            result[-1] += "\n"
        result.append("[User]\n")
        add_missing()
    return "".join(result)


def write_session(path: Path, session: str) -> None:
    if path.is_symlink():
        raise ValueError(f"Refusing to replace a symlink: {path}")
    original = path.read_text() if path.exists() else ""
    updated = update_session(original, session)
    if original == updated:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            stream.write(updated)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)  # Atomic, root-owned and mode 0600 under sudo.
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("Usage: python accounts-service.py ACCOUNT_FILE SESSION")
    write_session(Path(sys.argv[1]), sys.argv[2])
