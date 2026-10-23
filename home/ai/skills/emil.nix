# Скиллы Эмиля Ковальски (Sonner, Vercel, Linear): анимации, дизайн-инжиниринг,
# мобильный веб, Swift. Чистый markdown — ни скриптов, ни рантайма; npx в
# рецептах — это команды для самого проекта, а не установка тулзов в систему.
# https://github.com/emilkowalski/skills (MIT)
{ lib, pkgs }:

let
  names = [
    "emil-design-eng"
    "animate"
    "animate-expo"
    "review-animations"
    "improve-animations"
    "find-animation-opportunities"
    "animation-performance"
    "animation-vocabulary"
    "apple-design"
    "write-swift"
    "pick-ui-library"
    "prototype"
    "mobile-native"
    "break-ui"
    "ask-sonner"
  ];

  skills = pkgs.stdenvNoCC.mkDerivation {
    pname = "emilkowalski-skills";
    version = "0-unstable-2026-10-11";

    src = pkgs.fetchFromGitHub {
      owner = "emilkowalski";
      repo = "skills";
      rev = "2d228630ba1446365f614a108cb8252f1feda202";
      hash = "sha256-4/xWVt4HqB1nwqdLMFC3No07vkEWqRcQDtqNY8FHwh8=";
    };

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall
      mkdir "$out"
      for skill in ${lib.escapeShellArgs names}; do
        cp -r "skills/$skill" "$out/$skill"
        cp LICENSE "$out/$skill/LICENSE"
      done
      # Новый скилл в апстриме не должен молча выпасть из names.
      for dir in skills/*/; do
        [ -d "$out/$(basename "$dir")" ] || { echo "unlisted skill: $dir" >&2; exit 1; }
      done
      runHook postInstall
    '';

    meta = {
      description = "Emil Kowalski's design engineering and animation skills";
      homepage = "https://github.com/emilkowalski/skills";
      license = lib.licenses.mit;
    };
  };
in
lib.genAttrs names (name: "${skills}/${name}")
