# Nix-инструментарий для агентов: пять агентов, четырнадцать команд, шесть
# скиллов-справочников (поиск, флейки, модули, упаковка, тесты, отладка) —
# тот же формат и та же раскладка, что у ECC (home/programs/ecc), только
# источник — этот каталог. В каждый файл после frontmatter вшита памятка про
# Nix-доктрину: системная инструкция при большом контексте может выпасть, а
# файл агента или скилла читается в момент вызова.
#
#   claude — ~/.claude/{skills,agents,commands}
#   codex  — ~/.codex/skills, ~/.codex/prompts (команды без frontmatter),
#            ~/.codex/agents/<n>.toml (роли, по name)
#   agy    — ~/.gemini/config/agents/<n>.md (только тир модели, см. agentRoles)
#
# Инструменты из справочника ставятся декларативно в home.packages, чтобы
# `statix`, `nvd`, `nix-tree` и прочие были под рукой без `nix shell`.
{ lib, pkgs, ... }:

let
  # Модели для Codex и agy (Claude-модель и effort стоят в самих .md файлах).
  # Та же схема, что в ecc/default.nix: ревью и сборка — Astra, код — Sol 6.1,
  # минимум high; nix-reviewer и nix-build-resolver — xhigh (eval-ошибки Nix
  # не проще borrow checker'а). agy: тир flash, pro (Argon) только по запросу.
  agentRoles = {
    nix-architect      = { xm = "gpt-6-astra"; xe = "high";  tier = "flash"; };
    nix-engineer       = { xm = "gpt-6.1-sol"; xe = "high";  tier = "flash"; };
    nix-reviewer       = { xm = "gpt-6-astra"; xe = "xhigh"; tier = "flash"; };
    nix-build-resolver = { xm = "gpt-6-astra"; xe = "xhigh"; tier = "flash"; };
    nix-test-runner    = { xm = "gpt-6.1-sol"; xe = "high";  tier = "flash"; };
  };
  roleTable = pkgs.writeText "nix-toolkit-agent-roles.tsv" (lib.concatStrings
    (lib.mapAttrsToList (n: v: "${n}\t${v.xm}\t${v.xe}\t${v.tier}\n") agentRoles));

  payload = pkgs.stdenvNoCC.mkDerivation {
    pname = "nix-toolkit-agent-files";
    version = "1";
    src = lib.cleanSource ./.;

    dontConfigure = true;
    dontBuild = true;
    nativeBuildInputs = [ pkgs.gawk pkgs.jq ];

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"/claude "$out"/codex/{prompts,agents} "$out"/agy/agents
      cp -r skills agents commands "$out/claude/"
      chmod -R u+w "$out"

      # Памятка после frontmatter: скиллы, агенты, команды.
      for f in $(find "$out/claude" -name '*.md'); do
        awk -v banner="$(cat banner.md)" '
          BEGIN { fm = 0; done = 0 }
          { print }
          !done && /^---[[:space:]]*$/ { fm++; if (fm == 2) { print ""; print banner; done = 1 } }
          END { if (!done) { print ""; print banner } }
        ' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
      done
      # Каждый файл обязан нести памятку.
      if find "$out/claude" -name '*.md' -exec grep -L 'Nix-first (this machine is NixOS' {} + | grep .; then
        echo "files above lack the Nix banner" >&2; exit 1
      fi

      cp -r "$out/claude/skills" "$out/codex/skills"
      for f in "$out"/claude/commands/*.md; do
        name=$(basename "$f" .md)
        { printf '# /%s (Nix toolkit command)\n\n' "$name"
          awk 'BEGIN{fm=0} /^---[[:space:]]*$/ && fm<2 {fm++; next} fm==2 || fm==0 {print}' "$f"
        } > "$out/codex/prompts/$name.md"
      done
      # Роли Codex и агенты agy из тех же файлов (тело с памяткой — промпт).
      for f in "$out"/claude/agents/*.md; do
        name=$(basename "$f" .md)
        grep -q "^$name	" ${roleTable} || { echo "agentRoles lacks $name" >&2; exit 1; }
      done
      while IFS=$'\t' read -r name xm xe tier; do
        f="$out/claude/agents/$name.md"
        [ -f "$f" ] || { echo "agentRoles lists missing agent: $name" >&2; exit 1; }
        desc=$(awk '/^---[[:space:]]*$/{c++; next} c==1 && /^description:/{sub(/^description:[ ]*/,""); print; exit}' "$f" \
          | sed -E "s/^\"(.*)\"$/\1/; s/^'(.*)'$/\1/")
        body=$(awk '/^---[[:space:]]*$/{c++; next} c>=2' "$f")
        case "$body" in *"''''"*) echo "agent body contains '''' : $name" >&2; exit 1;; esac
        { printf 'name = "%s"\n' "$name"
          printf 'description = %s\n' "$(jq -Rn --arg d "$desc" '$d')"
          printf 'model = "%s"\nmodel_reasoning_effort = "%s"\n\n' "$xm" "$xe"
          printf "developer_instructions = ''''\n%s\n''''\n" "$body"
        } > "$out/codex/agents/$name.toml"
        { printf -- '---\nname: %s\ndescription: %s\nmodel: %s\nsubagent: true\nmainAgent: true\n---\n\n' \
            "$name" "$(jq -Rn --arg d "$desc" '$d')" "$tier"
          printf '%s\n' "$body"
        } > "$out/agy/agents/$name.md"
      done < ${roleTable}
      runHook postInstall
    '';
  };

  # Каталоги ~/.claude/skills и т.п. уже объявлены модулем ecc целиком, поэтому
  # здесь — поштучные записи; имена читаются из локальных папок (не IFD).
  names = dir: builtins.attrNames (builtins.readDir dir);
  skillNames = names ./skills;
  agentNames = map (lib.removeSuffix ".md") (names ./agents);
  commandNames = map (lib.removeSuffix ".md") (names ./commands);
  recursive = path: { source = path; recursive = true; };
  perSkill = root: sub: lib.listToAttrs (map (n: lib.nameValuePair "${root}/${n}" (recursive "${payload}/${sub}/${n}")) skillNames);
in
{
  # Справочник nix-toolkit зовёт их по имени; всё остальное — через nix shell.
  home.packages = with pkgs; [
    statix              # линтер анти-паттернов
    deadnix             # мёртвый код
    nixfmt              # форматтер (RFC style)
    nvd                 # diff двух closure/поколений
    nix-tree            # TUI дерева зависимостей
    nix-output-monitor  # nom: граф сборки
    nix-diff            # diff двух .drv
    nurl                # fetcher-выражение с хэшем по URL
    nix-init            # черновик пакета из репозитория
    nix-prefetch-git
    nixpkgs-review      # проверка PR в nixpkgs
    nil                 # LSP
  ];

  home.file =
    perSkill ".claude/skills" "claude/skills"
    // perSkill ".codex/skills" "codex/skills"
    // lib.listToAttrs (map (n: lib.nameValuePair ".claude/agents/${n}.md" { source = "${payload}/claude/agents/${n}.md"; }) agentNames)
    // lib.listToAttrs (map (n: lib.nameValuePair ".claude/commands/${n}.md" { source = "${payload}/claude/commands/${n}.md"; }) commandNames)
    // lib.listToAttrs (map (n: lib.nameValuePair ".codex/prompts/${n}.md" { source = "${payload}/codex/prompts/${n}.md"; }) commandNames)
    // lib.listToAttrs (map (n: lib.nameValuePair ".codex/agents/${n}.toml" { source = "${payload}/codex/agents/${n}.toml"; }) agentNames)
    // lib.listToAttrs (map (n: lib.nameValuePair ".gemini/config/agents/${n}.md" { source = "${payload}/agy/agents/${n}.md"; }) agentNames);
}
