# Общий инвентарь модулей home/ai: где каждый агент ищет свои файлы, как
# разложить один набор по всем агентам и как влить свой кусок в конфиг,
# которым агент владеет сам. Чистые функции, без побочных эффектов.
{ lib, pkgs }:

rec {
  # Корни пользовательских конфигов, относительно $HOME.
  roots = {
    claude = ".claude";        # $CLAUDE_CONFIG_DIR не читается HM, см. профили
    codex  = ".codex";         # $CODEX_HOME по умолчанию
    agy    = ".gemini/config"; # глобальный customization root Antigravity
  };

  # Куда у каждого агента кладутся скиллы (формат SKILL.md у всех троих один).
  skillRoots = [ "${roots.claude}/skills" "${roots.codex}/skills" "${roots.agy}/skills" ];

  # Каталог скилла — настоящий каталог из симлинков на файлы в сторе: агенту
  # не нужно уметь ходить по симлинку на каталог, стор остаётся read-only.
  recursive = path: { source = path; recursive = true; };

  # Codex наоборот: молча пропускает скилл, чей SKILL.md — симлинк, но идёт по
  # симлинку на каталог. Поэтому в его корне скилл — один симлинк на каталог в
  # сторе, где SKILL.md обычный файл (проверено на codex-cli 0.162).
  skillEntry = root: drv:
    if root == "${roots.codex}/skills" then { source = drv; } else recursive drv;

  # { name = drv; } -> home.file для всех skillRoots.
  skillFiles = skills: lib.listToAttrs (lib.concatMap (root:
    lib.mapAttrsToList (name: drv: lib.nameValuePair "${root}/${name}" (skillEntry root drv)) skills)
    skillRoots);

  # Для каталога, который HM раскладывает через `recursive` (lndir): каталог
  # симлинков <name> -> src/<name>. lndir переносит симлинк как есть, так что
  # в $HOME каждый скилл ляжет симлинком на каталог — то, что нужно codex.
  dirLinks = name: src: pkgs.runCommand name { } ''
    mkdir "$out"
    for d in ${src}/*; do ln -s "$d" "$out/"; done
  '';

  # Имена из локального каталога (не IFD: читается при evaluation из репо).
  dirNames = dir: builtins.attrNames (builtins.readDir dir);

  # Слияние своего фрагмента в JSON, которым владеет агент (claude пишет туда
  # кэши и счётчики, agy — свои MCP). Не владеем файлом через home.file, а
  # вливаем кусок: $ours[0] в jq-выражении — содержимое frag. Проверка -s, а не
  # -f: агенты оставляют файл нулевой длины, jq на пустом входе падает.
  mergeJson = { file, frag, expr }: ''
    mkdir -p "$(dirname ${file})"
    [ -s ${file} ] || printf '{}\n' > ${file}
    tmp="$(mktemp ${file}.XXXXXX)"
    jq --slurpfile ours ${frag} '${expr}' ${file} > "$tmp"
    mv -f "$tmp" ${file}
  '';

  # То же для TOML (codex config.toml): TOML -> JSON -> jq -> TOML. Круговой
  # прогон теряет комментарии, переживают только значения.
  mergeToml = { file, frag, expr }: ''
    mkdir -p "$(dirname ${file})"
    [ -f ${file} ] || : > ${file}
    tmp="$(mktemp ${file}.XXXXXX)"
    remarshal -if toml -of json < ${file} \
      | jq --slurpfile ours ${frag} '${expr}' \
      | remarshal -if json -of toml > "$tmp"
    mv -f "$tmp" ${file}
  '';

  mergeInputs = [ pkgs.jq pkgs.remarshal pkgs.coreutils ];

  # Набор скиллов из одного репозитория: { имя = каталог со SKILL.md; }.
  #   src      репозиторий (fetchFromGitHub, запинен по rev/hash)
  #   skills   { имя = "путь/внутри/src"; } — что брать; остальное не копируется
  #   banner   файл, вшиваемый после frontmatter каждого SKILL.md (памятка про Nix)
  #   extra    shell-хук после копирования: $out/<имя> — каталоги скиллов
  # Скрипты внутри остаются на месте; интерпретаторы и инструменты, которые они
  # зовут по имени, приходят из PATH обёртки профиля (ai.profiles.<p>.tools).
  mkSkillSet = { pname, version, src, skills, banner, extra ? "", meta ? { } }:
    let
      drv = pkgs.stdenvNoCC.mkDerivation {
        inherit pname version src meta;
        dontConfigure = true;
        dontBuild = true;
        nativeBuildInputs = [ pkgs.gawk ];
        installPhase = ''
          runHook preInstall
          ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: rel: ''
            mkdir -p "$out/${name}"
            cp -r "${rel}/." "$out/${name}/"
            [ -f "$out/${name}/SKILL.md" ] || { echo "no SKILL.md in ${rel}" >&2; exit 1; }
          '') skills)}
          chmod -R u+w "$out"
          # Симлинки на то, что осталось за sparseCheckout (например demos/), висят.
          find "$out" -xtype l -delete
          for f in "$out"/*/SKILL.md; do
            awk -v banner="$(cat ${banner})" '
              BEGIN { fm = 0; done = 0 }
              { print }
              !done && /^---[[:space:]]*$/ { fm++; if (fm == 2) { print ""; print banner; done = 1 } }
              END { if (!done) { print ""; print banner } }
            ' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
          done
          ${extra}
          runHook postInstall
        '';
      };
    in
    lib.mapAttrs (name: _: "${drv}/${name}") skills;
}
