# Профиль «код»: обычный ~/.claude и обычный `claude`. Сюда же целятся ECC
# (скиллы, агенты, команды, правила, хуки), nix-toolkit, ask-models и
# сторонние скиллы из ../../skills; MCP-серверы добавляет ../../mcp.
{
  ai.profiles.code = {
    dir = ".claude";
    wrapper = null;
    instructions = ./CLAUDE.md; # Лилит + Nix-доктрина + ECC-петля
  };
}
