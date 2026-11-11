# Профиль «дизайн»: свой каталог ~/.claude-design и обёртка `claude-design`.
# Для дизайнера, а не разработчика: ни ECC, ни хуков, ни кодерских правил.
# Логин отдельный: первый запуск попросит /login, Figma — /mcp.
#
#   skills.nix  скиллы (designer-skills, Anthropic, ui-ux-pro-max, emil, цвет, моушн),
#               запинены по rev/hash; там же команды designer-skills
#   impeccable  скилл и 4 агента из флейка impeccable-nix
#   banner.md   памятка про Nix, вшивается в каждый SKILL.md
#   CLAUDE.md   инструкции: отвечать по-русски, замерять, а не прикидывать на глаз
#
# Инструменты попадают в PATH только внутри claude-design; окружение запинено
# flake.lock. MCP: figma (подключается в ../../mcp/default.nix).
{ lib, pkgs, inputs, ... }:

let
  designSkills = import ./skills.nix { inherit lib pkgs; };

  # Скилл и агенты impeccable собирает отдельный флейк; пакет берём под нашу систему.
  impeccable = inputs.impeccable-nix.packages.${pkgs.stdenv.hostPlatform.system}.impeccable-skill;
  # Список явный: читать каталог агентов на eval значило бы IFD.
  impeccableAgents = [
    "impeccable-asset-producer"
    "impeccable-documenter"
    "impeccable-finish-reviewer"
    "impeccable-manual-edit-applier"
  ];

  # Сравнение макета с референсом: SSIM (scikit-image), палитры и выравнивание
  # (numpy, opencv), скриншоты страниц (playwright).
  python = pkgs.python3.withPackages (ps: with ps; [
    pillow numpy opencv4 scikit-image playwright
  ]);
in
{
  ai.profiles.design = {
    instructions = ./CLAUDE.md;
    skills = designSkills.skills // { impeccable = "${impeccable}/skills/impeccable"; };
    # Команды /start-here, /critique-* и остальные: Claude Code берёт их из
    # <dir>/commands. Каталог рекурсивный, чтобы рядом можно было класть свои.
    files = {
      commands = {
        source = designSkills.commands;
        recursive = true;
      };
    } // lib.listToAttrs (map
      (n: lib.nameValuePair "agents/${n}.md" { source = "${impeccable}/agents/${n}.md"; })
      impeccableAgents);

    tools = [
      pkgs.imagemagick # magick: compare, identify, палитры, наложения
      pkgs.inkscape    # SVG: экспорт и конвертация
      pkgs.potrace     # растр -> вектор (pixel2motion)
      pkgs.chromium    # скриншоты и рендер HTML
      pkgs.nodejs      # скрипты ui-ux-pro-max (.cjs), примеры GSAP/Lottie
      python
    ];

    env = {
      # python-playwright берёт браузеры из стора, а не качает их в ~/.cache.
      PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
      PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "true";
      PUPPETEER_SKIP_DOWNLOAD = "1";
      # impeccable по умолчанию шлёт обезличенную телеметрию; в профиле она выключена.
      IMPECCABLE_NO_TELEMETRY = "1";
    };
  };
}
