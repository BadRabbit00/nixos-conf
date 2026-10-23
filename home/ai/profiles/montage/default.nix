# Профиль «монтаж»: свой каталог ~/.claude-montage и обёртка `claude-montage`.
# Ни ECC, ни хуков, ни кодерских правил здесь нет; CLAUDE.md, скиллы и MCP —
# только про видео. Логин отдельный: первый запуск попросит /login.
{
  ai.profiles.montage = {
    instructions = ./CLAUDE.md;
    skills = { };   # скиллы для монтажа: имя -> каталог со SKILL.md (как в ../../skills)
    mcp = { };      # MCP-серверы для монтажа: имя -> { type = "stdio"; command = …; }
  };
}
