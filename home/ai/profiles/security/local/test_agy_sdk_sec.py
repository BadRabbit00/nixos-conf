"""Тесты allow-list команд agy-sdk-sec: что проходит без подтверждения."""

import asyncio
import json
import os
import tempfile
import unittest

from google.antigravity.hooks import policy as policy_mod
from google.antigravity.proto import localharness_pb2

from agy_sdk_sec import (
    CommandPolicy, build_policies, command_line, in_workspaces, is_auto_allowed, is_env_file, touches_env,
)
from google.antigravity import types

POL = CommandPolicy.load(
    {
        "gitleaks git": [],
        "semgrep scan --metrics=off": ["p/", "auto", "http", "--config=p/", "-cp/", "-cauto", "-chttp"],
        "grype dir:.": ["db", "registry:", "--from", "-t"],
        "syft scan dir:.": ["registry:", "--from", "-t", "--template"],
        "gitleaks dir": [],
        "bandit": [],
        "osv-scanner scan source --offline": [],
        "trufflehog filesystem . --no-verification": [],
        "git log --no-ext-diff --no-textconv": ["--output", "--ext-diff", "--textconv"],
        "find": ["-exec", "-ok", "-delete", "-fprint"],
        "mkdir -p .sec/reports": [],
        "trufflehog git file://. --no-verification": [],
    },
    {
        "cat": {"flags": ["-n"]},
        "head": {"flags": ["-n"]},
        "grep": {"flags": ["-n", "--include"]},
        "git branch": {
            "bare": False,
            "flags": ["--list", "-a", "--contains"],
            "solo": ["-v"],
        },
    },
)


class Project(unittest.TestCase):
    """Временный проект: в нём файлы, рядом — «чужой» каталог."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        base = os.path.realpath(self._tmp.name)
        self.ws = os.path.join(base, "proj")
        self.outside = os.path.join(base, "secret")
        os.makedirs(os.path.join(self.ws, "src"))
        os.makedirs(self.outside)
        open(os.path.join(self.ws, "a.txt"), "w").close()
        os.symlink(self.outside, os.path.join(self.ws, "link"))
        open(os.path.join(self.ws, ".env"), "w").close()
        os.symlink(".env", os.path.join(self.ws, "notes"))

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def ok(self, cmd: str, cwd: str | None = None) -> bool:
        return is_auto_allowed(cmd, POL, cwd or self.ws, self.ws)


class AutoAllowTest(Project):
    def test_allows_listed_command_with_arguments(self) -> None:
        self.assertTrue(self.ok("gitleaks git . --redact -v"))
        self.assertTrue(self.ok("git log --no-ext-diff --no-textconv --oneline -5"))
        self.assertTrue(self.ok("mkdir -p .sec/reports"))
        self.assertTrue(self.ok("trufflehog git file://. --no-verification --json"))

    def test_prefix_matches_whole_words_only(self) -> None:
        self.assertFalse(self.ok("catapult"))
        self.assertFalse(self.ok("gitleaks gitx"))
        self.assertFalse(self.ok("mkdir -p /etc"))

    def test_rejects_unlisted_commands(self) -> None:
        for cmd in ("rm -rf .", "curl https://example.com", "", "rg foo", "jq . a.txt", "sort a.txt"):
            with self.subTest(cmd=cmd):
                self.assertFalse(self.ok(cmd))

    def test_rejects_shell_chaining_and_redirection(self) -> None:
        for cmd in (
            "cat a; rm -rf .", "cat a && curl x", "cat a | sh", "cat a > b",
            "cat $(id)", "cat `id`", "cat a\nrm b", "cat <(id)", "cat a & sleep 1",
        ):
            with self.subTest(cmd=cmd):
                self.assertFalse(self.ok(cmd))

    def test_rejects_unbalanced_quotes_globs_and_tilde(self) -> None:
        for cmd in ("cat 'a", "find . -dele?e", "cat ~/.ssh/config", "cat *", "cat [ab]", "cat a # x", "cat =ls"):
            with self.subTest(cmd=cmd):
                self.assertFalse(self.ok(cmd))
        self.assertTrue(self.ok("find . -name '*.py'"))

    def test_empty_prefix_is_rejected(self) -> None:
        with self.assertRaises(ValueError):
            CommandPolicy.load({"": []}, {})


class ScannerTest(Project):
    def test_risky_tokens_ask(self) -> None:
        self.assertFalse(self.ok("find . -delete"))
        self.assertFalse(self.ok("find . -name x -execdir rm {} +"))
        self.assertFalse(self.ok("git log --no-ext-diff --no-textconv --output=x"))
        self.assertFalse(self.ok("git log --no-ext-diff --no-textconv -p --textconv"))
        self.assertFalse(self.ok("grype db update"))

    def test_scanners_only_offline(self) -> None:
        self.assertTrue(self.ok("semgrep scan --metrics=off --config rules/ --json ."))
        self.assertFalse(self.ok("semgrep scan --metrics=off --config p/default ."))
        self.assertFalse(self.ok("semgrep scan --metrics=off --config=p/default ."))
        self.assertFalse(self.ok("semgrep scan --metrics=off --config auto ."))
        self.assertFalse(self.ok("semgrep scan --config rules/ ."))
        self.assertFalse(self.ok("grype dir:. registry:alpine"))
        self.assertFalse(self.ok("grype alpine:latest"))
        self.assertFalse(self.ok("grype dir:. --from registry"))
        self.assertTrue(self.ok("syft scan dir:. -o cyclonedx-json=.sec/reports/sbom.cdx.json"))

    def test_git_without_textconv_flags_asks(self) -> None:
        self.assertFalse(self.ok("git log -p"))
        self.assertFalse(self.ok("git grep foo"))


class BypassTest(Project):
    """Обходы из ревью: склеенные значения, fmt=путь, dir://, повтор флагов."""

    def test_glued_short_values_are_checked(self) -> None:
        for cmd in (
            "semgrep scan --metrics=off --config rules/ -o/home/x/.zshrc .",
            "gitleaks dir . -r/tmp/x", "bandit -r . -o/tmp/x",
            "semgrep scan --metrics=off -cp/default .", "semgrep scan --metrics=off -cauto .",
            "semgrep scan --metrics=off '-chttps://attacker.tld/x' .",
        ):
            with self.subTest(cmd=cmd):
                self.assertFalse(self.ok(cmd))
        self.assertTrue(self.ok("bandit -r . -ll -f json -o .sec/reports/b.json"))

    def test_format_equals_path_values(self) -> None:
        for cmd in ("syft scan dir:. -o json=/tmp/x", "syft scan dir:. --output=json=/tmp/x",
                    "syft scan dir:. -o json=../x", "syft scan dir:. -o a,/tmp/x"):
            with self.subTest(cmd=cmd):
                self.assertFalse(self.ok(cmd))

    def test_double_slash_scheme_is_absolute(self) -> None:
        for cmd in ("syft scan dir:. dir://etc/ssh", "grype dir:. sbom://etc/x.json",
                    "gitleaks dir file:///etc"):
            with self.subTest(cmd=cmd):
                self.assertFalse(self.ok(cmd))

    def test_pinned_flags_cannot_be_overridden(self) -> None:
        for cmd in ("semgrep scan --metrics=off --metrics=on --config rules/ .",
                    "osv-scanner scan source --offline --offline=false .",
                    "trufflehog filesystem . --no-verification --no-verification=false"):
            with self.subTest(cmd=cmd):
                self.assertFalse(self.ok(cmd))

    def test_templates_and_exec_configs(self) -> None:
        for cmd in ("syft scan dir:. -o template=out.txt -t tmpl", "gitleaks dir . -r .git/config",
                    "gitleaks dir . -r src/../.git/hooks/x", "bandit -r . -o .envrc", "cat .vscode/tasks.json"):
            with self.subTest(cmd=cmd):
                self.assertFalse(self.ok(cmd))


class ReadTest(Project):
    def test_only_safe_flags(self) -> None:
        self.assertTrue(self.ok("cat -n a.txt"))
        self.assertTrue(self.ok("head -n 5 a.txt"))
        self.assertTrue(self.ok("grep -n '--include=*.py' foo src/a.py"))
        self.assertFalse(self.ok("grep -r foo ."))
        self.assertFalse(self.ok("cat -v a.txt"))
        self.assertFalse(self.ok("head --lines=5 a.txt"))
        self.assertFalse(self.ok("grep -R foo ."))
        self.assertFalse(self.ok("grep -f patterns.txt -r ."))

    def test_paths_must_stay_in_project(self) -> None:
        self.assertTrue(self.ok("cat src/../a.txt"))
        self.assertTrue(self.ok("cat ../proj/a.txt", cwd=os.path.join(self.ws, "src")))
        for cmd in ("cat /etc/passwd", "cat ../secret/x", "cat link/x", "grep -n foo /", "cat '~'/../../x",
                    "grep --include=/etc foo a.txt"):
            with self.subTest(cmd=cmd):
                self.assertFalse(self.ok(cmd))

    def test_env_files_ask(self) -> None:
        for cmd in ("cat .env", "cat src/.env.local", "head -n 1 prod.env", "grep -n foo .env",
                    "cat .ENV", "cat .envrc", "cat notes"):
            with self.subTest(cmd=cmd):
                self.assertFalse(self.ok(cmd))
        self.assertTrue(self.ok("cat .env.example"))

    def test_git_branch_only_reading_flags(self) -> None:
        self.assertTrue(self.ok("git branch -a"))
        self.assertTrue(self.ok("git branch -v"))
        self.assertTrue(self.ok("git branch --contains HEAD"))
        self.assertTrue(self.ok("git branch --list 'feat*'"))
        self.assertTrue(self.ok("git branch"))
        self.assertFalse(self.ok("git branch -D main"))
        self.assertFalse(self.ok("git branch -vD main"))
        self.assertFalse(self.ok("git branch newref"))
        self.assertFalse(self.ok("git branch -v newref"))


class EnvFileTest(unittest.TestCase):
    def test_env_names(self) -> None:
        for name in (".env", "a/.env", ".env.local", "prod.env", "x/.env/"):
            with self.subTest(name=name):
                self.assertTrue(is_env_file(name))
        for name in (".env.example", "env", "a.txt", "envrc"):
            with self.subTest(name=name):
                self.assertFalse(is_env_file(name))

    def test_touches_env_checks_any_string_arg(self) -> None:
        self.assertTrue(touches_env({"AbsolutePath": "/p/.env"}))
        self.assertFalse(touches_env({"AbsolutePath": "/p/a.py", "Lines": 5}))
        self.assertTrue(touches_env({"Includes": [".env"]}))

    def test_touches_env_through_symlink_and_directory(self) -> None:
        with tempfile.TemporaryDirectory() as d:
            open(os.path.join(d, ".env"), "w").close()
            os.symlink(os.path.join(d, ".env"), os.path.join(d, "notes"))
            os.makedirs(os.path.join(d, "clean"))
            self.assertTrue(touches_env({"AbsolutePath": os.path.join(d, "notes")}))
            self.assertTrue(touches_env({"SearchPath": d}))
            self.assertFalse(touches_env({"SearchPath": os.path.join(d, "clean")}))


class CommandLineTest(unittest.TestCase):
    def test_reads_only_the_harness_key(self) -> None:
        self.assertEqual(command_line({"CommandLine": "ls"}), "ls")
        self.assertEqual(command_line({"command": "ls"}), "")
        self.assertEqual(command_line({"CommandLine": ["ls"], "command": "ls"}), "")
        self.assertEqual(command_line({}), "")


class WorkspaceTest(unittest.TestCase):
    def test_cwd_must_be_inside_workspace(self) -> None:
        self.assertTrue(in_workspaces("/srv/proj", ["/srv/proj"]))
        self.assertTrue(in_workspaces("/srv/proj/sub", ["/srv/proj"]))
        self.assertFalse(in_workspaces("/srv/proj2", ["/srv/proj"]))
        self.assertFalse(in_workspaces("/srv/proj/../other", ["/srv/proj"]))
        self.assertFalse(in_workspaces("/", ["/srv/proj"]))
        self.assertFalse(in_workspaces(None, ["/srv/proj"]))
        self.assertFalse(in_workspaces("", ["/srv/proj"]))


class PolicyTest(unittest.TestCase):
    def test_run_command_never_reaches_wildcard_allow(self) -> None:
        rules = build_policies(POL, ["/srv/proj"], ask=lambda tc, reason="": asyncio.sleep(0, result=False))
        cmd = [r for r in rules if r.tool == types.BuiltinTools.RUN_COMMAND.value]
        self.assertEqual(len(cmd), 1)
        self.assertEqual(cmd[0].decision, policy_mod.Decision.ASK_USER)
        handler = cmd[0].ask_user
        call = types.ToolCall(name=types.BuiltinTools.RUN_COMMAND, args={"CommandLine": "rm -rf .", "Cwd": "/srv/proj"})
        self.assertFalse(asyncio.run(handler(call, "")))

    def test_workspace_containment_stays_enabled(self) -> None:
        cfg, _ = policy_mod._to_policy_config_proto(build_policies(POL, ["/srv/proj"]))
        self.assertNotEqual(
            cfg.workspace_containment, localharness_pb2.PolicyConfig.WORKSPACE_CONTAINMENT_DISABLED
        )


@unittest.skipUnless(os.environ.get("SEC_PERMS_JSON"), "SEC_PERMS_JSON: nix eval --json -f ../permissions.nix")
class ShippedPolicyTest(Project):
    """Тот же разбор на настоящем allow-list из permissions.nix."""

    def setUp(self) -> None:
        super().setUp()
        with open(os.environ["SEC_PERMS_JSON"], encoding="utf-8") as f:
            spec = json.load(f)
        self.pol = CommandPolicy.load(spec["commands"], spec["read"])

    def real(self, cmd: str) -> bool:
        return is_auto_allowed(cmd, self.pol, self.ws, self.ws)

    def test_documented_forms_pass(self) -> None:
        for cmd in (
            "semgrep scan --metrics=off --config rules/ --sarif -o .sec/reports/semgrep.sarif .",
            "trivy fs --skip-db-update --skip-java-db-update --skip-check-update --offline-scan -f json -o .sec/reports/t.json .",
            "syft scan dir:. -o cyclonedx-json=.sec/reports/sbom.cdx.json",
            "grype sbom:.sec/reports/sbom.cdx.json -o json --file .sec/reports/grype.json",
            "gitleaks git . --redact --report-format json --report-path .sec/reports/gitleaks.json",
            "git log --no-ext-diff --no-textconv --oneline -5", "cat -n a.txt", "git status",
        ):
            with self.subTest(cmd=cmd):
                self.assertTrue(self.real(cmd))

    def test_review_bypasses_ask(self) -> None:
        for cmd in (
            "semgrep scan --metrics=off -cp/default .", "semgrep scan --metrics=off --metrics=on .",
            "trivy fs --skip-db-update --skip-java-db-update --skip-check-update --offline-scan --skip-db-update=false .",
            "syft scan dir:. -o json=/tmp/x", "syft scan dir:. -o template=r.txt -t t.tmpl", "grype alpine:latest",
            "grype dir:. --from registry", "mcp-scanner --analyzers yara,readiness,prompt_defense,schema --analyzers api",
            "git log --no-ext-diff --no-textconv --show-signature", "rg foo", "jq . a.txt", "pip-audit", "grep -r x .",
        ):
            with self.subTest(cmd=cmd):
                self.assertFalse(self.real(cmd))


if __name__ == "__main__":
    unittest.main()
