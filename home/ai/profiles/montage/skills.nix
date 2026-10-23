# Скиллы профиля montage: цвет, моушн, анимация, сценарии, звук, музыка и
# общий видеопродакшн. Каждый репозиторий запинен по rev/hash (fetchgit,
# у больших — sparseCheckout только нужных каталогов), из него берутся лишь
# каталоги со SKILL.md, после frontmatter вшивается banner.md. Скрипты
# скиллов остаются на месте и работают на инструментах из PATH обёртки
# claude-montage (см. default.nix: ffmpeg, python с numpy/opencv/…, node,
# remotion, hyperframes, manim, whisper).
#
# Не взято намеренно: всё, что завязано на DaVinci Resolve / Premiere
# (color-grade-ai, davinci-resolve-mcp), MCP-серверы (bitwize, davinci),
# облачные провайдеры из OpenMontage/video-toolkit (runpod, modal, kling,
# seedance, heygen, …), JohnHeibel/ClaudeAnimationBase (нет SKILL.md, это
# стартер-репозиторий для p5.js).
#
# Обновление: nix shell nixpkgs#nix-prefetch-git -c nix-prefetch-git --url
#   https://github.com/<owner>/<repo> [--sparse-checkout "a\nb"]  -> rev, hash.
{ lib, pkgs }:

let
  ai = import ../../lib.nix { inherit lib pkgs; };
  banner = ./banner.md;
  version = "0-unstable-2026-10-23";

  set = pname: src: skills: extra: ai.mkSkillSet { inherit pname version src skills banner extra; };
  # { имя = "<dir>/имя"; } и вариант с префиксом в имени скилла.
  under = dir: names: lib.genAttrs names (n: "${dir}/${n}");
  prefixed = prefix: dir: names: lib.listToAttrs (map (n: lib.nameValuePair "${prefix}-${n}" "${dir}/${n}") names);

  srcs = {
    gsap = pkgs.fetchgit {
      url = "https://github.com/greensock/gsap-skills";
      rev = "aed9cfd3277740755f6bfc1155c7aa645403b760";
      hash = "sha256-dAjDpjKP16Lw7sFjfaH6UjWy+2y9hPVLCO9CEaaZni4=";
    };
    colorExpert = pkgs.fetchgit {
      url = "https://github.com/meodai/skill.color-expert";
      rev = "5bf7c7704d56bccc6aeea38c36bcf449abe56a6c";
      hash = "sha256-64oe3TdO7whoqyhIVDFfS2jQ9VCLZuevlHeQhf9Ya4o=";
    };
    motionDesign = pkgs.fetchgit {
      url = "https://github.com/iart-ai/motion-design-skills";
      rev = "3c129f769d90a1328c209c386492333c9ac62312";
      hash = "sha256-aHUWziGntt1SYCj5JV7Cn4mIeRx/FDGIBRJb3SS9cPA=";
    };
    remotion = pkgs.fetchgit {
      url = "https://github.com/remotion-dev/skills";
      rev = "6c67adcd9cdbe6eb84d76342da89b225f9161cb2";
      hash = "sha256-5CiYB1K0j5XiZ78Kn27rqf0Fmsupk7dFUYR7z1k+IMA=";
    };
    learnColorGrading = pkgs.fetchgit {
      url = "https://github.com/adur1990/learn-color-grading";
      rev = "6f48399369838d8ee7e1d6024b86c0f96e3d1df5";
      hash = "sha256-Fw4z2+6lW1DHBcOqDSK44cclAZlNpf1jGCpgRSW2u1Y=";
    };
    lottie = pkgs.fetchgit {
      url = "https://github.com/diffusionstudio/lottie";
      rev = "3c72912fad543897f90045ed4d355813837927fc";
      hash = "sha256-Wj7YQKojHypeic/cg1c3O+yllFLQbaaOy7whvdPQnGg=";
    };
    pixel2motion = pkgs.fetchgit {
      url = "https://github.com/nolangz/pixel2motion";
      rev = "e9faedb28930df0da2acf17da00c80730a78cfe8";
      hash = "sha256-7aJe7/a0ERHtZXshpkaPjXd9ZDti/5qScdYDyoXNEmo=";
    };
    screenwriting = pkgs.fetchgit {
      url = "https://github.com/jtydhr88/screenwriting-skills";
      rev = "51115f18d160aa8b2ac5813e4432b6f0b425358f";
      hash = "sha256-x4VUHqsPidkEFTwuwayhlUkEcNjcKIXlut1D1B/thkc=";
    };
    colorCorrect = pkgs.fetchgit {
      url = "https://github.com/louisedesadeleer/color-correct";
      rev = "4c38e5cff615eef58ec3b3197a02b8df472a5f50";
      hash = "sha256-cICV7HdY9nSxU/xHHYnCugk3Wte4aE0wt+KjwvqrOSs=";
    };
    elevenlabs = pkgs.fetchgit {
      url = "https://github.com/elevenlabs/skills";
      rev = "238659af298e321e0ddb62ef2fcf8f5bf0b5e59f";
      hash = "sha256-dqCiUbuPM8w5VL/beOptX8TRQCckrRj2eU1Foe5L+H0=";
    };
    claudeVideo = pkgs.fetchgit {
      url = "https://github.com/agricidaniel/claude-video";
      rev = "4253a2b7c6db74ac809429a4c69075b55e8a77ff";
      hash = "sha256-2ByOwyQ127XjEa30chrmK2H+ssZvsiJ4phyfOzVv/WU=";
    };
    manim = pkgs.fetchgit {
      url = "https://github.com/adithya-s-k/manim_skill";
      rev = "cef045011722d285692e3381d12d4d637da56e18";
      hash = "sha256-CESWKMHvCN6Dtc8Fk8V9pP2txQ6b0Y7180GawMciTWc=";
    };
    claudeMusic = pkgs.fetchgit {
      url = "https://github.com/AgriciDaniel/claude-music";
      rev = "5aa0173a6b329e059568bef4253e2a62efe8b412";
      hash = "sha256-fallIELzNFNsaMi41bl/ZC8a8HgNZZt2PfTNsKU+rio=";
    };
    piemonte = pkgs.fetchgit {
      url = "https://github.com/piemonte/skills";
      rev = "f26ecec8a55cb84ff464ea82532c9b82a123ee8e";
      hash = "sha256-2lWsY7KbgFsPpuhImrL23LL0b7dT51/7Vf0Bk078SyQ=";
    };
    bitwize = pkgs.fetchgit {
      url = "https://github.com/bitwize-music-studio/claude-ai-music-skills";
      rev = "597d928fb2c8316ee13159771405813174aa01de";
      hash = "sha256-b9DhScaWziT8PgrauToSKQ/YUnmvTcl7vtFysYpRpRg=";
      sparseCheckout = [ "skills" ];
    };
    jpComposition = pkgs.fetchgit {
      url = "https://github.com/jtydhr88/japanese-composition-skills";
      rev = "fe52df3f31625e911b654060130433f43b620b76";
      hash = "sha256-c2MDNXYhJ2vczoVCSQgj7ZLNoRuSes1KtV0lwPUlwU4=";
    };
    reelbench = pkgs.fetchgit {
      url = "https://github.com/eternityspring/reelbench-skills";
      rev = "0d2743ade386195caeb6d156da2810cdf6e35a03";
      hash = "sha256-4yTQ+A4fwGaU7gzeE0pCRZGOp8NobuIxe8/1wuHomgQ=";
    };
    openMontage = pkgs.fetchgit {
      url = "https://github.com/calesthio/OpenMontage";
      rev = "c8066452325cb57c8fc1ba8c2a71b6e8842e6b65";
      hash = "sha256-0kC46K4Rx0sLvsfaKWetPd3ZwPYN2IUH0alNVyMGsVo=";
      sparseCheckout = [ ".agents/skills" ];
    };
    viral = pkgs.fetchgit {
      url = "https://github.com/sharon-laicc/viral-video-decomposer";
      rev = "34093598d48bda6492f687c5eae3472b782d0637";
      hash = "sha256-T/MnO36HDgdsiqj+1c4gZBcJnu0/C5b0GcdIGGQHc+Y=";
    };
    explainroo = pkgs.fetchgit {
      url = "https://github.com/vincentsch/explainroo";
      rev = "e95232c8d535ed2aa390e7b1caee0d1326dd9e83";
      hash = "sha256-CuhJBaYomg29RdyZoDHvuVHURjD/T2GwPOkkych+9FY=";
    };
    onetake = pkgs.fetchgit {
      url = "https://github.com/feitangyuan/onetake";
      rev = "013a61ac8d98883c73733f59c06e49e9ba444f14";
      hash = "sha256-1Wz6vJG4FPlVojkHqJ4EE1Asic/qjgqR6hSyH+yo1BY=";
    };
    motionmaxxing = pkgs.fetchgit {
      url = "https://github.com/Tejashmakwana/motionmaxxing";
      rev = "8c8ec0f2a6f6c9a0da15cd24f7b1298ab298368c";
      hash = "sha256-cPcVB+YjOfYkvYf71JdBHaQapcEuqzMI892feZSNbkU=";
      sparseCheckout = [ "library" "references" "runtime" "scripts" "taste" "templates" "docs" ];
    };
    videoToolkit = pkgs.fetchgit {
      url = "https://github.com/digitalsamba/claude-code-video-toolkit";
      rev = "da3f474c1230d161be1384ef97aec27f73b11636";
      hash = "sha256-UUuVAW/27215Uw3U2lGcyoPCeFZF0QlufFvGneb2S3Q=";
      sparseCheckout = [ ".claude/skills" "lib" "scripts" "tools" ];
    };
    gsd = pkgs.fetchgit {
      url = "https://github.com/Tibsfox/gsd-skill-creator";
      rev = "e179dfe911f3b3c2ff8bcd90ecd6ee4738648d17";
      hash = "sha256-hJRKe9lnSs1zWP2o6UlwaCFUGQ2KWADlFKwWZAcHncQ=";
      sparseCheckout = [ "examples/skills/media/audio-engineering" ];
    };
    hyperframes = pkgs.fetchgit {
      url = "https://github.com/heygen-com/hyperframes";
      rev = "bd4cae7e3582e2da9eee3903bc0780d9d03c98b2";
      hash = "sha256-CJfoY8QFKuQvDOvuH3JebSMhocaylRivevex5tufV+Q=";
      sparseCheckout = [ "skills" ".agents/skills" ];
    };
    shotcraft = pkgs.fetchgit {
      url = "https://github.com/Vincentwei1021/video-shotcraft";
      rev = "43bd349a136651865ecfa6ea1cf012f6e957d304";
      hash = "sha256-8kIlrZ+1FIsszvA6KZ8YPnVHTVACGymUz7YSC5eVQW4=";
      sparseCheckout = [ "references" "shot-polish" "template" "agents" "workbench" "publish" ];
    };
  };
in
# ---- Цвет --------------------------------------------------------------------
# Колорист: диагноз -> грейд -> до/после, 9 луков, ffmpeg + numpy/PIL.
set "color-correct" srcs.colorCorrect { color-correct = "."; } ""
# Сравнение кадра с референсом: точка чёрного, микроконтраст, тени/света.
// set "learn-color-grading" srcs.learnColorGrading { learn-color-grading = "skills/learn-color-grading"; } ""
# Наука о цвете, 144 справочника.
// set "color-expert" srcs.colorExpert { color-expert = "."; } ""

# ---- Моушн и анимация ---------------------------------------------------------
# Официальные скиллы Remotion (12).
// set "remotion-skills" srcs.remotion (under "skills" [
  "remotion-best-practices" "remotion-captions" "remotion-create" "remotion-docs"
  "remotion-interactivity" "remotion-maps" "remotion-markup" "remotion-multimedia"
  "remotion-render" "remotion-saas" "remotion-studio" "remotion-upgrade" ]) ""
# Теория моушн-дизайна: тайминг, типографика, цвет, композиция, AE.
// set "motion-design-skills" srcs.motionDesign (under "skills" [
  "after-effects" "animation-principles" "beat-sync-editing" "color-motion" "logo-animation"
  "motion-art-direction" "motion-background" "remotion-video" "shot-composition" ]) ""
# Официальные скиллы GSAP (8).
// set "gsap-skills" srcs.gsap (under "skills" [
  "gsap-core" "gsap-frameworks" "gsap-performance" "gsap-plugins" "gsap-react"
  "gsap-scrolltrigger" "gsap-timeline" "gsap-utils" ]) ""
# HyperFrames: HTML -> видео, официальные скиллы и .agents-набор.
// set "hyperframes-skills" srcs.hyperframes (under "skills" [
  "hyperframes" "hyperframes-cli" "hyperframes-registry" "media-use" "remotion-to-hyperframes" "slideshow" ]
  // under ".agents/skills" [ "captions-overlay" "changelog-video" "cut-the-curve" "motion-doctrine" "oversized-cursor" "seam-craft" ]) ""
# Растровый логотип -> плавный SVG (numpy, PIL, playwright).
// set "pixel2motion" srcs.pixel2motion { pixel2motion = "."; } ""
# Ролики без склеек: одна непрерывная камера. assets/gallery (23 МБ превью) не нужны.
// set "onetake" srcs.onetake { onetake = "."; } ''rm -rf "$out/onetake/assets" "$out/onetake/gallery"''
# Из «ИИ-слопа» в работу моушн-дизайнера (библиотека, референсы, рантайм three/gsap).
// set "motionmaxxing" srcs.motionmaxxing { motionmaxxing = "."; } ""
# 152 карточки кадров и 209 превью движений для продуктовых роликов (Remotion-workbench).
// set "video-shotcraft" srcs.shotcraft { video-shotcraft = "."; } ""
# Lottie из текста.
// set "lottie-skills" srcs.lottie { text-to-lottie = "skills/text-to-lottie"; } ""
# Manim (3Blue1Brown).
// set "manim-skills" srcs.manim (under "skills" [ "manim-composer" "manimce-best-practices" "manimgl-best-practices" ]) ""

# ---- Сценарии и разбор --------------------------------------------------------
# 26 скиллов по драматургии (тексты на китайском, отвечает на языке вопроса).
// set "screenwriting-skills" srcs.screenwriting (under "plugins/screenwriting/skills" [
  "chekhov-dramaturgy" "ozu-screenplay-style" "succession-series-writing" "sw-american-case-studies"
  "sw-character-conflict" "sw-chinese-opera-banqiang" "sw-chinese-opera-banqiang-cases" "sw-chinese-opera-qupai"
  "sw-chinese-opera-qupai-cases" "sw-chinese-series-practice" "sw-dialogue" "sw-format-adaptation"
  "sw-genre-anatomy" "sw-industry-business" "sw-japanese-screenwriting" "sw-korean-french-screenwriting"
  "sw-premise-theme" "sw-scene-craft" "sw-series-case-studies" "sw-series-engine-bible" "sw-series-structure"
  "sw-sitcom-comedy" "sw-story-structure" "sw-truby-anatomy" "sw-workflow" "sw-writers-room" ]) ""
# Инструменты для ИИ-видео: скраб, раскадровка, синхрон.
// set "reelbench-skills" srcs.reelbench (under "skills" [ "video-scrub" "video-shots" "video-sync" ]) ""
# Разбор вирусных коротких видео по кадрам (ffmpeg).
// set "viral-video-decomposer" srcs.viral { viral-video-decomposer = "skill"; video-structure-analyzer = "plugins/video-structure-analyzer"; } ""

# ---- Звук ---------------------------------------------------------------------
# ElevenLabs (нужен API-ключ): озвучка, STT, SFX, музыка, смена/очистка голоса, дубляж.
// set "elevenlabs-skills" srcs.elevenlabs (prefixed "elevenlabs" "." [
  "dubbing" "music" "sound-effects" "speech-to-text" "text-to-speech" "voice-changer" "voice-isolator" "speech-engine" "setup-api-key" ]) ""
# claude-video: 16 скиллов, локально на ffmpeg; скрипты лежат в корне репо,
# SKILL.md зовут их как scripts/x.py — кладём копию scripts/ в каждый скилл.
// set "claude-video" srcs.claudeVideo (under "skills" [
  "video" "video-analyze" "video-audio" "video-caption" "video-create" "video-download" "video-edit" "video-enhance"
  "video-enhance-audio" "video-export" "video-generate" "video-image" "video-promo" "video-screenshot" "video-shorts" "video-transcode" ])
  ''for d in "$out"/*/; do cp -r scripts "$d/scripts"; done''
# Справочник по громкости (LUFS под площадки) и обработке.
// set "audio-engineering" srcs.gsd { audio-engineering = "examples/skills/media/audio-engineering"; } ""

# ---- Музыка -------------------------------------------------------------------
# bitwize: только знания (тексты, Suno, сведение, мастеринг); их MCP-сервер не ставим.
// set "bitwize-music-skills" srcs.bitwize (under "skills" [
  "lyric-writer" "lyric-refiner" "lyric-reviewer" "suno-engineer" "mastering-engineer" "mix-engineer"
  "pronunciation-specialist" "genre-creator" "album-conceptualizer" "album-art-director" "voice-checker"
  "explicit-checker" "plagiarism-checker" "promo-writer" ]) ""
# Локальная генерация музыки (ACE-Step 1.5): движок на torch — отдельным devShell, скиллы здесь.
// set "claude-music" srcs.claudeMusic (under "skills" [
  "claude-music" "claude-music-analyze" "claude-music-compose" "claude-music-cover" "claude-music-enhance"
  "claude-music-export" "claude-music-generate" "claude-music-library" "claude-music-lora" "claude-music-random"
  "claude-music-repaint" "claude-music-web" ]) ""
# Японские учебники композиции (11 скиллов).
// set "japanese-composition-skills" srcs.jpComposition (under "plugins/japanese-composition/skills" [
  "jp-arrangement" "jp-chord-progressions" "jp-chord-selection" "jp-composition-basics" "jp-harmony-advanced"
  "jp-jazz-adlib" "jp-melody-writing" "jp-mixing" "jp-modulation" "jp-song-structure" "jp-vocal-lyrics-production" ]) ""
# Лайвкодинг музыки.
// set "livecoding-skills" srcs.piemonte { sonic-pi = "sonic-pi"; strudel = "strudel"; } ""

# ---- Общий продакшн ------------------------------------------------------------
# OpenMontage (AGPL): локальные пайплайны без ключей; дубли gsap/remotion/manim/
# hyperframes и облачные провайдеры не берём. Префикс om-, чтобы не биться с claude-video.
// set "openmontage-skills" srcs.openMontage (prefixed "om" ".agents/skills" [
  "ffmpeg" "create-video" "video-edit" "video-toolkit" "video-understand" "video-download" "video-translate"
  "music-to-video" "website-to-video" "motion-graphics" "canvas-procedural-animation" "svg-character-animation"
  "character-rigging" "character-animation-qa" "pose-library-design" "framer-motion" "lottie-bodymovin" "d3-viz"
  "beautiful-mermaid" "visual-style" "synthetic-screen-recording" "playwright-recording" "acestep" "music"
  "sound-effects" "text-to-speech" "speech-to-text" "setup-api-key"
  "threejs-animation" "threejs-fundamentals" "threejs-geometry" "threejs-interaction" "threejs-lighting"
  "threejs-loaders" "threejs-materials" "threejs-postprocessing" "threejs-shaders" "threejs-textures" "threejs-world-generation" ]) ""
# От брифа до ролика со звуком (node-движок в репо; скилл — знания + bin/).
// set "explainroo" srcs.explainroo { explainroo = "skills/explainroo"; } ""
# claude-code-video-toolkit: локальные скиллы без облачных GPU. Префикс vt-.
// set "video-toolkit-skills" srcs.videoToolkit (prefixed "vt" ".claude/skills" [
  "ffmpeg" "moviepy" "remotion" "playwright-recording" "synthetic-ui-demo" ]) ""
