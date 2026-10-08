"""Regression checks for files managed by the Arch setup helpers; no root needed."""

import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ARCH = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("accounts_service", ARCH / "accounts-service.py")
accounts = importlib.util.module_from_spec(spec)
spec.loader.exec_module(accounts)


class AccountSessionTests(unittest.TestCase):
    def test_create(self):
        self.assertEqual(
            accounts.update_session("", "niri"),
            "[User]\nSession=niri\nSessionType=wayland\nSystemAccount=false\n",
        )

    def test_preserve_unrelated_keys_comments_and_sections(self):
        original = (
            "# account metadata\n[User]\nLanguage=ru_RU.UTF-8\nSession=gnome\n"
            "Icon=/var/lib/AccountsService/icons/badrabbit\nSessionType=x11\n"
            "SystemAccount=true\n# preserve this comment\n[Other]\nSession=keep-me\n"
        )
        expected = original.replace("Session=gnome", "Session=niri").replace(
            "SessionType=x11", "SessionType=wayland"
        ).replace("SystemAccount=true", "SystemAccount=false")
        updated = accounts.update_session(original, "niri")
        self.assertEqual(updated, expected)
        self.assertEqual(accounts.update_session(updated, "niri"), updated)

    def test_missing_keys_are_added_to_user_section(self):
        updated = accounts.update_session("[User]\nLanguage=en_US\n[Other]\nName=other", "niri")
        self.assertIn("Session=niri\nSessionType=wayland\nSystemAccount=false\n[Other]", updated)
        self.assertTrue(updated.endswith("Name=other"))

    def test_missing_user_section_and_final_newline(self):
        updated = accounts.update_session("[Other]\nName=other", "niri")
        self.assertTrue(updated.startswith("[Other]\nName=other\n[User]\n"))
        self.assertEqual(accounts.update_session(updated, "niri"), updated)

    def test_duplicate_keys_do_not_keep_old_session(self):
        updated = accounts.update_session("[User]\n Session = gnome\nSession=other", "niri")
        self.assertEqual(updated.count("Session="), 1)
        self.assertIn("Session=niri\n", updated)

    def test_reject_ambiguous_sections_or_invalid_session(self):
        with self.assertRaises(ValueError):
            accounts.update_session("[User]\n[User]\n", "niri")
        with self.assertRaises(ValueError):
            accounts.update_session("", "niri\nSystemAccount=true")

    def test_atomic_write_does_not_touch_other_users(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "badrabbit"
            other = Path(directory) / "another-user"
            other.write_text("[User]\nSession=gnome\n")
            accounts.write_session(path, "niri")
            first = path.stat()
            accounts.write_session(path, "niri")
            self.assertEqual(path.stat().st_ino, first.st_ino)
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
            self.assertEqual(other.read_text(), "[User]\nSession=gnome\n")
            link = Path(directory) / "link"
            link.symlink_to(other)
            with self.assertRaises(ValueError):
                accounts.write_session(link, "niri")


@unittest.skipIf(os.geteuid() == 0, "sync-nvidia deliberately refuses root")
class NvidiaSyncTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.driver = self.root / "nvidia-driver.json"
        self.driver.write_text(json.dumps({"version": "615.71.09", "sha256": "old"}))
        shutil.copy2(ARCH / "sync-nvidia.sh", self.root)
        binaries = self.root / "bin"
        binaries.mkdir()
        (binaries / "python").symlink_to(sys.executable)
        for name, script in {
            "pacman": '#!/usr/bin/env bash\nprintf "nvidia-utils %s\\n" "${TEST_VERSION:-615.71.09-1}"\n',
            "nix": '#!/usr/bin/env bash\n[[ ${TEST_FAIL:-0} == 0 ]] || exit 1\nprintf \'{"hash":"sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="}\\n\'\n',
        }.items():
            path = binaries / name
            path.write_text(script)
            path.chmod(0o755)
        self.environment = dict(os.environ, PATH=f"{binaries}:{os.environ['PATH']}")

    def run_sync(self, *args, **variables):
        return subprocess.run(
            [str(self.root / "sync-nvidia.sh"), *args],
            env=dict(self.environment, **variables), capture_output=True, text=True,
        )

    def test_check_detects_mismatch_without_rewriting(self):
        self.assertEqual(self.run_sync("--check").returncode, 0)
        before = self.driver.read_bytes()
        self.assertNotEqual(self.run_sync("--check", TEST_VERSION="616.10-1").returncode, 0)
        self.assertEqual(self.driver.read_bytes(), before)

    def test_update_strips_epoch_and_release_and_is_idempotent(self):
        result = self.run_sync(TEST_VERSION="1:616.10-3")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.driver.read_text())["version"], "616.10")
        first = self.driver.stat()
        self.assertEqual(self.run_sync(TEST_VERSION="1:616.10-3").returncode, 0)
        self.assertEqual(self.driver.stat().st_ino, first.st_ino)

    def test_failed_download_or_bad_version_preserves_pin(self):
        before = self.driver.read_bytes()
        self.assertNotEqual(self.run_sync(TEST_FAIL="1").returncode, 0)
        self.assertNotEqual(self.run_sync(TEST_VERSION="bad-version").returncode, 0)
        self.assertEqual(self.driver.read_bytes(), before)


if __name__ == "__main__":
    unittest.main()
