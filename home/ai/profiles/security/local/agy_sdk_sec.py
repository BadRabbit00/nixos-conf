"""agy-sdk-sec: ИБ-профиль Циллы на Google Antigravity SDK и локальной модели.

Конфиг (JSON) собирает Nix: адрес llama-server, модель, файлы инструкции,
каталоги скиллов, MCP-серверы и allow-list команд. Без -p — интерактивный
REPL, с -p — один запрос, ответ в stdout.

Политика инструментов:
  * run_command из allow-list (одиночная команда в каталоге проекта, без
    метасимволов оболочки, глобов и опасных флагов, все пути — внутри
    проекта и не .env) выполняется сразу;
  * любая другая команда, создание и правка файлов, чтение .env — только
    после «y»;
    без терминала (stdin не TTY) запрос считается отказом;
  * файловые инструменты не выходят за каталог проекта (workspace_only).
"""

import argparse
import asyncio
import contextlib
import json
import os
import re
import shlex
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from google.antigravity import Agent, LocalOpenAIAgentConfig, types
from google.antigravity.hooks import policy
from google.antigravity.utils import interactive

# Любой из этих символов делает строку не одной командой: цепочка, конвейер,
# перенаправление, подстановка. Такие строки всегда идут на подтверждение.
SHELL_META = re.compile(r"[;&|`$<>(){}\\\n\r]")

# Раскрытия, которые оболочка делает уже после проверки: глобы (файл с именем
# «-delete» в чужом репо превратится во флаг), `~`, комментарий. В кавычках
# они безопасны, поэтому смотрим только вне '...' и "...".
QUOTED = re.compile(r"'[^']*'|\"[^\"]*\"")
UNQUOTED_EXPANSION = re.compile(r"[*?\[\]~#]|(?:^|\s)=")

FILE_WRITE_TOOLS = (types.BuiltinTools.CREATE_FILE.value, types.BuiltinTools.EDIT_FILE.value)
ENV_READ_TOOLS = (types.BuiltinTools.VIEW_FILE.value, types.BuiltinTools.SEARCH_DIR.value)

ENABLED_TOOLS = [
    types.BuiltinTools.LIST_DIR,
    types.BuiltinTools.SEARCH_DIR,
    types.BuiltinTools.FIND_FILE,
    types.BuiltinTools.VIEW_FILE,
    types.BuiltinTools.CREATE_FILE,
    types.BuiltinTools.EDIT_FILE,
    types.BuiltinTools.RUN_COMMAND,
    types.BuiltinTools.ASK_QUESTION,
]


def command_line(args: dict[str, Any]) -> str:
    """Командная строка run_command. В localharness ключ один — CommandLine;
    не строка — значит не знаем, что выполнится, и идём на подтверждение."""
    value = args.get("CommandLine")
    return value if isinstance(value, str) else ""


def in_workspaces(cwd: Any, workspaces: list[str]) -> bool:
    """True, если каталог запуска команды лежит внутри одного из workspace."""
    if not isinstance(cwd, str) or not cwd:
        return False
    real = os.path.realpath(cwd)
    for ws in workspaces:
        root = os.path.realpath(ws)
        if os.path.commonpath([real, root]) == root:
            return True
    return False


# Источники сканеров вида dir:., sbom:x, file://. — дальше обычный путь.
# `//` снимается только у file: (`dir://etc` у syft — это /etc).
SCHEME = re.compile(r"^(?:dir:|sbom:|file://)")


def pinned_flags(prefix: str) -> tuple[str, ...]:
    """Флаги префикса: повторить их дальше (`--metrics=on`) нельзя."""
    return tuple(t.split("=", 1)[0] for t in shlex.split(prefix) if t.startswith("--"))


@dataclass(frozen=True)
class ReadSpec:
    """Читающая утилита: флаги из `flags` (и `solo`), без них — только позиционные.
    `bare=False` — позиционные только вместе с флагом из `flags`."""

    flags: frozenset[str]
    solo: frozenset[str]
    bare: bool = True


@dataclass(frozen=True)
class CommandPolicy:
    """Allow-list из ../permissions.nix: префикс команды → правила аргументов."""

    commands: tuple[tuple[tuple[str, ...], tuple[str, ...]], ...]
    read: tuple[tuple[tuple[str, ...], ReadSpec], ...]

    @classmethod
    def load(cls, commands: dict[str, list[str]], read: dict[str, dict[str, Any]]) -> "CommandPolicy":
        cmds = tuple((tuple(shlex.split(p)), tuple(risky) + pinned_flags(p)) for p, risky in commands.items())
        reads = tuple(
            (tuple(shlex.split(p)), ReadSpec(frozenset(s.get("flags", [])), frozenset(s.get("solo", [])),
                                             bool(s.get("bare", True))))
            for p, s in read.items()
        )
        if not all(p for p, _ in cmds + reads):
            raise ValueError("allow-list: пустой префикс разрешил бы любую команду")
        return cls(cmds, reads)


def is_env_file(path: str) -> bool:
    """`.env`, `prod.env`, `.env.local`, `.envrc` — секреты; `.env.example` — нет."""
    name = os.path.basename(path.rstrip("/")).lower()
    if name == ".env.example":
        return False
    return name in (".env", ".envrc") or name.startswith(".env.") or name.endswith(".env")


# Каталоги и файлы, которые потом исполняют git, direnv и редакторы: писать
# в них отчёт сканера (`-o .git/config`) — значит подложить код человеку.
EXEC_CONFIG = frozenset({".git", ".direnv", ".vscode", ".envrc"})


def inside(path: str, cwd: str, workspace: str) -> bool:
    """Путь (относительно cwd) после разворота симлинков лежит в проекте,
    не в .git/.direnv/.vscode и не указывает на .env."""
    real = os.path.realpath(os.path.join(cwd, path))
    root = os.path.realpath(workspace)
    if os.path.commonpath([real, root]) != root:
        return False
    rel = os.path.relpath(real, root)
    raw = os.path.normpath(path).split(os.sep)
    if EXEC_CONFIG & set(rel.split(os.sep)) or EXEC_CONFIG & set(raw):
        return False
    return not (is_env_file(path) or is_env_file(real))


def values_of(tok: str) -> list[str]:
    """Всё, что может быть путём или адресом внутри аргумента: сам позиционный
    аргумент, значение `--флаг=…`, склеенное `-oЗНАЧЕНИЕ`, части `fmt=путь`
    и `a,b`."""
    whole = [tok]
    if tok.startswith("--"):
        if "=" not in tok:
            return []
        tok, whole = tok.split("=", 1)[1], []
    elif tok.startswith("-"):
        if len(tok) <= 2:
            return []
        tok, whole = tok[2:], []
    return whole + [p for p in re.split(r"[=,]", tok) if p]


def value_ok(value: str, cwd: str, workspace: str) -> bool:
    value = SCHEME.sub("", value, count=1)
    if "://" in value or value.startswith("/"):
        return False
    return inside(value, cwd, workspace)


def args_in_project(args: list[str], cwd: str, workspace: str) -> bool:
    """Каждый позиционный аргумент и каждое значение флага — путь внутри
    проекта. Шаблоны и числа тоже проверяются как пути: ложный вопрос
    дешевле дыры."""
    return all(value_ok(v, cwd, workspace) for tok in args for v in values_of(tok))


def has_risky(rest: list[str], risky: tuple[str, ...]) -> bool:
    """Токен или его значение (`-cp/default`, `--config=auto`) начинается с
    опасного префикса."""
    for tok in rest:
        candidates = [tok] + ([tok[2:]] if tok.startswith("-") and not tok.startswith("--") else [])
        if any(c.startswith(r) for c in candidates for r in risky):
            return True
    return False


def match_prefix(tokens: list[str], entries: tuple[tuple[tuple[str, ...], Any], ...]):
    """Самый длинный префикс (слова целиком) из allow-list."""
    best = None
    for prefix, rule in entries:
        if tuple(tokens[: len(prefix)]) == prefix and (best is None or len(prefix) > len(best[0])):
            best = (prefix, rule)
    return best


def read_args_ok(rest: list[str], spec: ReadSpec) -> bool:
    allowed = spec.flags | spec.solo
    if any(t.startswith("-") and t.split("=", 1)[0] not in allowed for t in rest):
        return False
    if not spec.bare and any(not t.startswith("-") for t in rest):
        # `git branch NAME` создаёт ветку: позиционные — только в режиме списка.
        return any(t.split("=", 1)[0] in spec.flags for t in rest)
    return True


def is_auto_allowed(cmd: str, pol: CommandPolicy, cwd: str, workspace: str) -> bool:
    """True, если команда — одиночная, из allow-list, без опасных флагов и
    трогает только файлы проекта."""
    if not cmd.strip() or SHELL_META.search(cmd):
        return False
    if UNQUOTED_EXPANSION.search(QUOTED.sub("''", cmd)):
        return False
    try:
        tokens = shlex.split(cmd)
    except ValueError:
        return False

    hit_cmd = match_prefix(tokens, pol.commands)
    hit_read = match_prefix(tokens, pol.read)
    if hit_cmd and (not hit_read or len(hit_cmd[0]) >= len(hit_read[0])):
        prefix, risky = hit_cmd
        rest = tokens[len(prefix):]
        if has_risky(rest, risky):
            return False
    elif hit_read:
        prefix, spec = hit_read
        rest = tokens[len(prefix):]
        if not read_args_ok(rest, spec):
            return False
    else:
        return False
    return args_in_project(rest, cwd, workspace)


async def confirm(tc: types.ToolCall, reason: str = "") -> bool:
    """Подтверждение человеком. Без терминала — отказ: в headless-прогоне
    (`-p`, cron, пайп) спросить некого, а «y» из stdin — не человек.
    Вопрос идёт в stderr, чтобы не попасть в ответ при `-p … > report.md`."""
    if not sys.stdin.isatty():
        return False
    with contextlib.redirect_stdout(sys.stderr):
        return await interactive.ask_user_handler(tc, reason)


# Сколько записей обходить в поиске .env под каталогом search_dir.
ENV_WALK_LIMIT = 20000


def strings_in(value: Any) -> list[str]:
    """Все строки в аргументах инструмента, включая вложенные списки и словари."""
    if isinstance(value, str):
        return [value]
    if isinstance(value, dict):
        return [s for v in value.values() for s in strings_in(v)]
    if isinstance(value, (list, tuple)):
        return [s for v in value for s in strings_in(v)]
    return []


def dir_has_env(path: str) -> bool:
    """Под каталогом есть .env (или обход слишком большой, чтобы сказать «нет»)."""
    seen = 0
    for _root, dirs, files in os.walk(path):
        seen += len(dirs) + len(files)
        if seen > ENV_WALK_LIMIT or any(is_env_file(f) for f in files):
            return True
    return False


def touches_env(args: dict[str, Any]) -> bool:
    """Аргумент инструмента указывает на .env — по имени, через симлинк или
    как каталог, под которым .env лежит (поиск по дереву вычитал бы его)."""
    for value in strings_in(args):
        real = os.path.realpath(value)
        if is_env_file(value) or is_env_file(real):
            return True
        if os.path.isdir(real) and dir_has_env(real):
            return True
    return False


def build_policies(pol: CommandPolicy, workspaces: list[str], ask=confirm) -> list[policy.Policy]:
    def allowed(args: dict[str, Any]) -> bool:
        cwd = args.get("Cwd")
        return in_workspaces(cwd, workspaces) and is_auto_allowed(
            command_line(args), pol, os.path.realpath(cwd), workspaces[0])

    async def allow_or_ask(tc: types.ToolCall, reason: str = "") -> bool:
        # Одно безусловное правило: run_command никогда не доходит до «*»,
        # даже если между двумя проверками allow-list поменялась ФС.
        return allowed(tc.args or {}) or await ask(tc, reason)

    rules = [policy.ask_user(types.BuiltinTools.RUN_COMMAND.value, handler=allow_or_ask,
                             name="sec_command")]
    rules += [policy.ask_user(t, handler=ask, name="sec_confirm_write") for t in FILE_WRITE_TOOLS]
    # Секреты читаются только с вопросом: specific ask сильнее wildcard allow.
    rules += [policy.ask_user(t, handler=ask, when=touches_env, name="sec_confirm_env") for t in ENV_READ_TOOLS]
    # Файловые инструменты — только внутри проекта. Без этого правила
    # wildcard-allow выключает workspace containment харнесса.
    rules += policy.workspace_only(workspaces)
    # Чтение, поиск и MCP (semgrep без отправки данных) — без вопросов.
    # Не policy.allow_all(): правило с этим именем харнесс читает как «без containment».
    rules.append(policy.allow("*", name="sec_default_allow"))
    return rules


def build_config(cfg: dict[str, Any], resume: str | None, workspace: str) -> LocalOpenAIAgentConfig:
    identity = "\n\n".join(Path(p).read_text(encoding="utf-8") for p in cfg["instructions"])
    state = Path(os.path.expanduser(cfg["stateDir"]))
    state.mkdir(mode=0o700, parents=True, exist_ok=True)  # в беседах — вывод сканеров
    os.chmod(state, 0o700)
    for name in ("conversations", "app-data"):
        (state / name).mkdir(mode=0o700, exist_ok=True)

    mcp_servers = [
        types.McpStdioServer(name=name, command=m["command"], args=m["args"], env=m["env"])
        for name, m in cfg["mcp"].items()
    ]
    pol = CommandPolicy.load(cfg["commands"], cfg["read"])
    workspaces = [workspace]

    return LocalOpenAIAgentConfig(
        model=cfg["model"],
        base_url=cfg["baseUrl"],
        system_instructions=types.TemplatedSystemInstructions(identity=identity),
        capabilities=types.CapabilitiesConfig(
            enabled_tools=ENABLED_TOOLS,
            enable_subagents=False,
            agent_behavior=types.AgentBehavior.INTERACTIVE,
        ),
        compaction_config=types.CompactionConfig(token_threshold=cfg["compactAt"]),
        policies=build_policies(pol, workspaces),
        # ask_question читает stdin: без терминала отвечать некому.
        hooks=[interactive.AskQuestionHook()] if sys.stdin.isatty() else [],
        mcp_servers=mcp_servers,
        skills_paths=cfg["skillsPaths"],
        workspaces=workspaces,
        conversation_id=resume,
        save_dir=str(state / "conversations"),
        app_data_dir=str(state / "app-data"),
    )


async def one_shot(config: LocalOpenAIAgentConfig, prompt: str) -> None:
    async with Agent(config) as agent:
        response = await agent.chat(prompt)
        async for token in response:
            sys.stdout.write(token)
            sys.stdout.flush()
        print()
        print(f"[conversation: {agent.conversation_id}]", file=sys.stderr)


def main() -> None:
    parser = argparse.ArgumentParser(prog="agy-sdk-sec", description=__doc__.splitlines()[0])
    parser.add_argument("--config", required=True, help=argparse.SUPPRESS)
    parser.add_argument("-p", "--prompt", help="один запрос без REPL; ответ — в stdout")
    parser.add_argument("--resume", metavar="ID", help="продолжить сохранённую беседу")
    args = parser.parse_args()
    if args.prompt is not None and not args.prompt.strip():
        parser.error("-p: пустой запрос")

    # Workspace — то, что агент читает без спроса. Дом или корень целиком —
    # это ключи, токены и чужие проекты: запускай из каталога проекта.
    workspace = os.path.realpath(os.getcwd())
    if workspace in (os.path.realpath(os.path.expanduser("~")), "/"):
        parser.error(f"запусти из каталога проекта, а не из {workspace}")

    cfg = json.loads(Path(args.config).read_text(encoding="utf-8"))
    config = build_config(cfg, args.resume, workspace)
    try:
        if args.prompt is not None:
            asyncio.run(one_shot(config, args.prompt))
        else:
            asyncio.run(interactive.run_interactive_loop(config))
    except KeyboardInterrupt:
        sys.exit(130)


if __name__ == "__main__":
    main()
