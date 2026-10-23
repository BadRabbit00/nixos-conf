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

  # { name = drv; } -> home.file для всех skillRoots.
  skillFiles = skills: lib.listToAttrs (lib.concatMap (root:
    lib.mapAttrsToList (name: drv: lib.nameValuePair "${root}/${name}" (recursive drv)) skills)
    skillRoots);

  # Поштучные записи home.file: { "<dst>/<n><ext>" = { source = "<src>/<n><ext>"; }; }
  # Используется там, где каталог уже объявлен целиком другим модулем (ecc)
  # и дописать в него можно только отдельными файлами.
  perName = { dst, src, names, ext ? "", recursiveDirs ? false }:
    lib.listToAttrs (map (n: lib.nameValuePair "${dst}/${n}${ext}"
      (if recursiveDirs then recursive "${src}/${n}${ext}" else { source = "${src}/${n}${ext}"; }))
      names);

  # Имена из локального каталога (не IFD: читается при evaluation из репо).
  dirNames = dir: builtins.attrNames (builtins.readDir dir);
  mdNames = dir: map (lib.removeSuffix ".md") (dirNames dir);

  # Памятка про Nix-доктрину, вшивается после frontmatter в каждый .md агента.
  banner = ./nix-toolkit/banner.md;

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
