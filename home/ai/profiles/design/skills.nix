# Скиллы профиля design: дизайн-мышление (Owl-Listener/designer-skills, 111 скиллов
# и 34 команды), визуальные скиллы Anthropic, наши ui-ux-pro-max и emil, плюс
# цвет, моушн, GSAP и Lottie из тех же репозиториев, что у montage.
# Каждый репозиторий запинен по rev/hash, после frontmatter вшивается banner.md.
#
# Пины color-expert, pixel2motion, motion-design-skills, gsap, lottie повторяют
# montage/skills.nix (тот же rev/hash — в сторе это один и тот же путь, лишней
# загрузки нет). Общий файл пинов не выделен: montage вне этого изменения;
# при следующем обновлении пинов их стоит вынести в один файл.
#
# Обновление: nix flake prefetch github:<owner>/<repo>/<rev> --json | jq -r .hash
{ lib, pkgs }:

let
  ai = import ../../lib.nix { inherit lib pkgs; };
  banner = ./banner.md;
  version = "0-unstable-2026-11-11";

  set = pname: src: skills: extra: ai.mkSkillSet { inherit pname version src skills banner extra; };
  under = dir: names: lib.genAttrs names (n: "${dir}/${n}");

  srcs = {
    designer = pkgs.fetchFromGitHub {
      owner = "Owl-Listener";
      repo = "designer-skills";
      rev = "9a6930cf84a822eb458624bd11c61aac5bbdf224";
      hash = "sha256-V4d/jmOVXKxWDsxA7/oLycD3OWhjW9OYeTHKuHFPyCQ=";
    };
    anthropic = pkgs.fetchFromGitHub {
      owner = "anthropics";
      repo = "skills";
      rev = "2c5958ecac7cee2b583967a2c4981d0f4a75c579";
      hash = "sha256-dRCZrNarCCJFuvATgfW6qmwwVS5HGFXNVGOhbVZd7LA=";
    };
    colorExpert = pkgs.fetchgit {
      url = "https://github.com/meodai/skill.color-expert";
      rev = "5bf7c7704d56bccc6aeea38c36bcf449abe56a6c";
      hash = "sha256-64oe3TdO7whoqyhIVDFfS2jQ9VCLZuevlHeQhf9Ya4o=";
    };
    pixel2motion = pkgs.fetchgit {
      url = "https://github.com/nolangz/pixel2motion";
      rev = "e9faedb28930df0da2acf17da00c80730a78cfe8";
      hash = "sha256-7aJe7/a0ERHtZXshpkaPjXd9ZDti/5qScdYDyoXNEmo=";
    };
    motionDesign = pkgs.fetchgit {
      url = "https://github.com/iart-ai/motion-design-skills";
      rev = "3c129f769d90a1328c209c386492333c9ac62312";
      hash = "sha256-aHUWziGntt1SYCj5JV7Cn4mIeRx/FDGIBRJb3SS9cPA=";
    };
    gsap = pkgs.fetchgit {
      url = "https://github.com/greensock/gsap-skills";
      rev = "aed9cfd3277740755f6bfc1155c7aa645403b760";
      hash = "sha256-dAjDpjKP16Lw7sFjfaH6UjWy+2y9hPVLCO9CEaaZni4=";
    };
    lottie = pkgs.fetchgit {
      url = "https://github.com/diffusionstudio/lottie";
      rev = "3c72912fad543897f90045ed4d355813837927fc";
      hash = "sha256-Wj7YQKojHypeic/cg1c3O+yllFLQbaaOy7whvdPQnGg=";
    };
  };

  # Скиллы designer-skills по плагинам. Список явный (без чтения каталога на
  # eval); проверка в checkListed падает, если апстрим добавит скилл, которого здесь нет.
  designerPlugins = {
    designer-toolkit = [
      "case-study" "design-negotiation" "design-rationale" "design-system-adoption"
      "design-token-audit" "presentation-deck" "ux-writing"
    ];
    design-ops = [
      "design-critique" "design-debt-audit" "design-impact-reporting" "design-qa-checklist"
      "design-review-process" "design-sprint-plan" "handoff-spec" "team-workflow"
      "version-control-strategy"
    ];
    design-research = [
      "affinity-diagram" "behavioural-analytics" "card-sort-analysis" "diary-study-plan" "empathy-map"
      "interview-script" "jobs-to-be-done" "journey-map" "qual-quant-triangulation"
      "research-repository" "summarize-interview" "survey-design" "usability-test-plan" "user-persona"
    ];
    design-systems = [
      "accessibility-audit" "component-spec" "design-system-governance" "design-token"
      "documentation-template" "icon-system" "localization-design" "motion-system" "naming-convention"
      "pattern-library" "theming-system"
    ];
    interaction-design = [
      "animation-principles" "conversational-ux" "doherty-threshold" "error-handling-ux"
      "feedback-patterns" "fitts-law" "form-design" "gesture-patterns" "hicks-law" "interfaces-that-feel"
      "jakobs-law" "loading-states" "micro-interaction-spec" "millers-law" "navigation-patterns"
      "onboarding-design" "peak-end-rule" "search-ux" "serial-position-effect" "state-machine"
      "teslers-law" "zeigarnik-effect"
    ];
    prototyping-testing = [
      "a-b-test-design" "accessibility-test-plan" "click-test-plan" "concept-selection"
      "heuristic-evaluation" "parallel-concepts" "prototype-strategy" "test-scenario"
      "user-flow-diagram" "wireframe-spec"
    ];
    ui-design = [
      "aesthetic-usability" "color-system" "dark-mode-design" "data-visualization" "illustration-style"
      "law-of-closure" "law-of-common-region" "law-of-continuity" "law-of-figure-ground"
      "law-of-proximity" "law-of-similarity" "layout-grid" "platform-conventions" "readable-measure"
      "responsive-design" "spacing-system" "typography-scale" "visual-hierarchy" "von-restorff-effect"
    ];
    ux-strategy = [
      "business-design" "competitive-analysis" "content-strategy" "design-brief" "design-principles"
      "experience-map" "information-architecture" "metrics-definition" "north-star-vision"
      "opportunity-framework" "service-blueprint" "stakeholder-alignment"
    ];
    visual-critique = [
      "critique-affordance" "critique-brand-consistency" "critique-color" "critique-composition"
      "critique-information-density" "critique-typography" "critique-visual-hierarchy"
    ];
  };

  designerSkills = lib.foldl' (acc: plugin: acc // under "${plugin}/skills" designerPlugins.${plugin}) { }
    (lib.attrNames designerPlugins);

  checkListed = ''
    # Новый скилл в апстриме не должен молча выпасть из списка.
    for dir in */skills/*/; do
      [ -d "$out/$(basename "$dir")" ] || { echo "unlisted skill: $dir" >&2; exit 1; }
    done
  '';

  # Команды плагинов -> одна плоская папка. Одноимённые (test-plan есть в
  # design-research и prototyping-testing) получают префикс плагина, остальные
  # имена не меняются, так что /start-here и прочие работают как в документации.
  commands = pkgs.stdenvNoCC.mkDerivation {
    pname = "designer-skills-commands";
    inherit version;
    src = srcs.designer;
    dontConfigure = true;
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      for f in */commands/*.md; do
        n=$(basename "$f")
        dups=$(printf '%s\n' */commands/"$n" | wc -l)
        if [ "$dups" -gt 1 ]; then n="$(dirname "$(dirname "$f")")-$n"; fi
        [ ! -e "$out/$n" ] || { echo "command collision: $n" >&2; exit 1; }
        cp "$f" "$out/$n"
      done
      runHook postInstall
    '';
    meta.license = lib.licenses.mit;
  };

  ours = import ../../skills/ui-ux-pro-max.nix { inherit lib pkgs; }
    // import ../../skills/emil.nix { inherit lib pkgs; };

  skills =
    set "designer-skills" srcs.designer designerSkills checkListed
    // set "anthropic-design-skills" srcs.anthropic
      (under "skills" [ "theme-factory" "brand-guidelines" "canvas-design" "frontend-design" ]) ""
    // set "color-expert" srcs.colorExpert { color-expert = "."; } ""
    // set "pixel2motion" srcs.pixel2motion { pixel2motion = "."; } ""
    // set "gsap-skills" srcs.gsap (under "skills" [
      "gsap-core" "gsap-frameworks" "gsap-performance" "gsap-plugins" "gsap-react"
      "gsap-scrolltrigger" "gsap-timeline" "gsap-utils"
    ]) ""
    // set "lottie-skills" srcs.lottie { text-to-lottie = "skills/text-to-lottie"; } ""
    # animation-principles есть и в designer-skills (на него ссылаются соседние
    # скиллы), и в motion-design-skills: второй переименован, иначе один затрёт другой.
    // set "motion-design-skills" srcs.motionDesign
      (under "skills" [
        "after-effects" "beat-sync-editing" "color-motion" "logo-animation"
        "motion-art-direction" "motion-background" "remotion-video" "shot-composition"
      ] // { motion-animation-principles = "skills/animation-principles"; })
      ''sed -i 's/^name: animation-principles$/name: motion-animation-principles/' "$out/motion-animation-principles/SKILL.md"''
    // ours;
in
{
  inherit skills commands;
}
