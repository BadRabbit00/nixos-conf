# Чужие модели в одну команду. Шесть обёрток, два режима:
#   ask-*   — только читать и отвечать (Codex: sandbox read-only; agy: --mode plan
#             + --sandbox). Запись в файлы невозможна.
#   write-* — модель правит файлы в рабочем дереве (Codex: sandbox workspace-write;
#             agy: --mode accept-edits + --sandbox: правки авто-одобряются, команды,
#             требующие разрешения, отклоняются). Сеть и чужие каталоги закрыты.
# Модели: astra = gpt-6-astra (Codex CLI); agy = gemini-3.8-flash-high и argon =
# gemini-4-argon-high (Antigravity CLI). Effort задаётся флагом (минимум high).
#
#   <tool> [-m MODEL] [-e EFFORT] [-o OUT.md] (-f PROMPT.md | слова промпта...)
#
# Отчёт: $ASK_MODELS_DIR (по умолчанию ~/.local/state/ask-models)/<repo>/<tool>-<ts>.md
# с шапкой, промптом, ответом, а для write-* ещё и git-диффом после работы модели.
# Команды для Claude — ~/.claude/commands/<tool>.md; для Codex — ~/.codex/prompts/
# (только agy/argon: Codex спрашивать самого себя незачем).
{ lib, pkgs, ... }:

let
  ai = import ../lib.nix { inherit lib pkgs; };
  reportDir = ''"''${ASK_MODELS_DIR:-$HOME/.local/state/ask-models}"'';

  # Разбор аргументов, промпт из файла / слов / stdin, путь отчёта, шапка.
  common = ''
    model=$DEFAULT_MODEL; effort=$DEFAULT_EFFORT; out=""; prompt_file=""
    while [ $# -gt 0 ]; do
      case "$1" in
        -m) model=$2; shift 2 ;;
        -e) effort=$2; shift 2 ;;
        -o) out=$2; shift 2 ;;
        -f) prompt_file=$2; shift 2 ;;
        -h|--help) echo "$USAGE"; exit 0 ;;
        --) shift; break ;;
        -*) echo "unknown flag: $1" >&2; echo "$USAGE" >&2; exit 2 ;;
        *) break ;;
      esac
    done
    case "$effort" in low|medium|high|xhigh|max) ;; *) echo "bad effort: $effort" >&2; exit 2 ;; esac
    if [ -n "$prompt_file" ]; then
      [ -r "$prompt_file" ] || { echo "prompt file not readable: $prompt_file" >&2; exit 2; }
    elif [ $# -gt 0 ]; then
      prompt_file=$(mktemp -t ask-prompt.XXXXXX); printf '%s\n' "$*" > "$prompt_file"
    elif [ ! -t 0 ]; then
      prompt_file=$(mktemp -t ask-prompt.XXXXXX); cat > "$prompt_file"
    else
      echo "$USAGE" >&2; exit 2
    fi
    repo=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
    rev=$(git -C "$repo" rev-parse --short HEAD 2>/dev/null || echo "-")
    ts=$(date +%Y%m%d-%H%M%S)
    [ -n "$out" ] || out=${reportDir}/$(basename "$repo")/$TOOL-$ts.md
    mkdir -p "$(dirname "$out")"
    answer=$(mktemp -t ask-answer.XXXXXX)
    {
      printf '# %s\n\n' "$TOOL"
      printf -- '- date: %s\n- model: %s\n- effort: %s\n- mode: %s\n- repo: %s @ %s\n- cwd: %s\n\n' \
        "$(date -Iseconds)" "$model" "$effort" "$MODE" "$repo" "$rev" "$PWD"
      printf '## Prompt\n\n'; cat "$prompt_file"; printf '\n\n## Answer\n\n'
    } > "$out"
    echo "[$TOOL] $model/$effort ($MODE) -> $out" >&2
  '';

  finish = ''
    cat "$answer" >> "$out"
    cat "$answer"
    rm -f "$answer"
    if [ "$MODE" = write ] && git -C "$repo" rev-parse --git-dir >/dev/null 2>&1; then
      { printf '\n\n## Changes (git status / diff --stat after the run)\n\n```\n'
        git -C "$repo" status --short; echo; git -C "$repo" diff --stat
        printf '```\n'
      } >> "$out"
      echo "[$TOOL] changed files:" >&2; git -C "$repo" status --short >&2
    fi
    echo "[$TOOL] report: $out" >&2
  '';

  usage = name: extra: ''
    USAGE='${name} [-m MODEL] [-e low|medium|high|xhigh|max] [-o OUT.md] (-f PROMPT.md | prompt words...)
    ${extra} Report -> ~/.local/state/ask-models/<repo>/.'
  '';

  # Codex CLI (GPT-6-Astra). exec читает промпт из stdin, ответ пишет через -o.
  codexTool = { name, mode, sandbox, effort }: pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = [ pkgs.codex pkgs.git pkgs.coreutils ];
    text = ''
      TOOL=${name}; MODE="${mode}"; DEFAULT_MODEL=gpt-6-astra; DEFAULT_EFFORT=${effort}
      ${usage name "GPT via Codex CLI headless, sandbox ${sandbox} (${if mode == "ask" then "cannot write files" else "may edit the workspace, no network"})."}
      ${common}
      codex exec --skip-git-repo-check --color never \
        -s ${sandbox} -m "$model" -c "model_reasoning_effort=\"$effort\"" \
        -o "$answer" < "$prompt_file" > /dev/null
      ${finish}
    '';
  };

  # Antigravity CLI (Gemini). plan = без правок; accept-edits = правки авто-одобрены.
  agyTool = { name, mode, model, effort }: pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = [ pkgs.antigravity-cli pkgs.git pkgs.coreutils ];
    text = ''
      TOOL=${name}; MODE="${mode}"; DEFAULT_MODEL=${model}; DEFAULT_EFFORT=${effort}
      ${usage name "Gemini via Antigravity CLI headless, ${if mode == "ask" then "plan mode: cannot write files" else "accept-edits: may edit the workspace"}, sandboxed. Models: agy models."}
      ${common}
      agy --print "$(cat "$prompt_file")" --model "$model" --effort "$effort" \
        --mode ${if mode == "ask" then "plan" else "accept-edits"} --sandbox \
        --output-format text > "$answer"
      ${finish}
    '';
  };

  tools = [
    (codexTool { name = "ask-astra";   mode = "ask";   sandbox = "read-only";       effort = "xhigh"; })
    (codexTool { name = "write-astra"; mode = "write"; sandbox = "workspace-write"; effort = "xhigh"; })
    (agyTool   { name = "ask-agy";     mode = "ask";   model = "gemini-3.8-flash-high"; effort = "high"; })
    (agyTool   { name = "write-agy";   mode = "write"; model = "gemini-3.8-flash-high"; effort = "high"; })
    (agyTool   { name = "ask-argon";   mode = "ask";   model = "gemini-4-argon-high";   effort = "high"; })
    (agyTool   { name = "write-argon"; mode = "write"; model = "gemini-4-argon-high";   effort = "high"; })
  ];

  inherit (ai) banner roots;
  commandNames = ai.mdNames ./commands;
  codexNames = builtins.filter (n: !(lib.hasSuffix "astra" n)) commandNames;
  commands = pkgs.runCommand "ask-models-commands" { nativeBuildInputs = [ pkgs.gawk ]; } ''
    mkdir -p "$out"/claude "$out"/codex
    for f in ${./commands}/*.md; do
      n=$(basename "$f")
      awk -v banner="$(cat ${banner})" '
        BEGIN { fm = 0; done = 0 }
        { print }
        !done && /^---[[:space:]]*$/ { fm++; if (fm == 2) { print ""; print banner; done = 1 } }
      ' "$f" > "$out/claude/$n"
      { printf '# /%s\n\n' "''${n%.md}"
        awk 'BEGIN{fm=0} /^---[[:space:]]*$/ && fm<2 {fm++; next} fm==2 || fm==0 {print}' "$out/claude/$n"
      } > "$out/codex/$n"
    done
  '';
in
{
  home.packages = tools;

  home.file =
    ai.perName { dst = "${roots.claude}/commands"; src = "${commands}/claude"; names = commandNames; ext = ".md"; }
    // ai.perName { dst = "${roots.codex}/prompts"; src = "${commands}/codex"; names = codexNames; ext = ".md"; };
}
