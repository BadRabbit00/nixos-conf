{ pkgs, ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    withRuby = false;
    withPython3 = false;

    plugins = with pkgs.vimPlugins; [
      # UI/UX
      render-markdown-nvim
      zen-mode-nvim
      twilight-nvim
      lualine-nvim
      nvim-web-devicons
      
      # LSP & Completion
      nvim-lspconfig
      luasnip
      cmp_luasnip
      nvim-cmp
      cmp-nvim-lsp
      cmp-buffer
      cmp-path
      
      # Automation
      bullets-vim
      nvim-surround
      conform-nvim
      
      # Media & Preview
      markdown-preview-nvim
      clipboard-image-nvim
    ];

    extraPackages = with pkgs; [
      marksman
      markdownlint-cli2
      prettier
      hunspell
      hunspellDicts.ru_RU
      hunspellDicts."en_US-large"
    ];

    extraConfig = ''
      lua << EOF
      -- --- UI & General ---
      vim.opt.number = true
      vim.opt.relativenumber = true
      vim.opt.shiftwidth = 2
      vim.opt.tabstop = 2
      vim.opt.expandtab = true
      vim.opt.spell = true
      vim.opt.spelllang = { 'en_us', 'ru_ru' }
      vim.opt.termguicolors = true

      -- Leader key
      vim.g.mapleader = " "

      -- --- Lualine (Word Count & Spellcheck) ---
      local function word_count()
        if vim.fn.mode() == 'v' or vim.fn.mode() == 'V' then
          return tostring(vim.fn.wordcount().visual_words) .. " words"
        else
          return tostring(vim.fn.wordcount().words) .. " words"
        end
      end

      require('lualine').setup {
        options = { theme = 'auto', globalstatus = true },
        sections = {
          lualine_x = { 'spell', word_count, 'filetype' },
        }
      }

      -- --- Render Markdown ---
      require('render-markdown').setup({
        heading = {
          sign = false,
          position = 'inline',
          icons = { '󰲡 ', '󰲣 ', '󰲥 ', '󰲧 ', '󰲩 ', '󰲫 ' },
        },
        checkbox = {
          enabled = true,
          unchecked = { icon = '󰄱 ' },
          checked = { icon = '󰄲 ' },
        },
      })

      -- --- Zen Mode & Twilight ---
      require("zen-mode").setup {
        window = { width = .85 },
        plugins = {
          twilight = { enabled = true },
          options = {
            enabled = true,
            ruler = false,
            showcmd = false,
          },
        },
      }
      vim.keymap.set("n", "<leader>z", ":ZenMode<CR>", { desc = "Toggle Zen Mode" })

      -- --- Conform (Formatting) ---
      require("conform").setup({
        formatters_by_ft = {
          markdown = { "prettier", "markdownlint-cli2" },
        },
        format_on_save = {
          timeout_ms = 500,
          lsp_fallback = true,
        },
      })

      -- --- LSP (Marksman) ---
      local lspconfig = require('lspconfig')
      lspconfig.marksman.setup{}

      -- --- Completion (nvim-cmp) ---
      local cmp = require('cmp')
      local luasnip = require('luasnip')
      cmp.setup({
        snippet = {
          expand = function(args) luasnip.lsp_expand(args.body) end,
        },
        mapping = cmp.mapping.preset.insert({
          ['<C-b>'] = cmp.mapping.scroll_docs(-4),
          ['<C-f>'] = cmp.mapping.scroll_docs(4),
          ['<C-Space>'] = cmp.mapping.complete(),
          ['<CR>'] = cmp.mapping.confirm({ select = true }),
        }),
        sources = cmp.config.sources({
          { name = 'nvim_lsp' },
          { name = 'luasnip' },
          { name = 'buffer' },
          { name = 'path' },
        })
      })

      -- --- Snippets (LuaSnip) ---
      local s = luasnip.snippet
      local t = luasnip.text_node
      local i = luasnip.insert_node

      luasnip.add_snippets("markdown", {
        s("vzk", {
          t("[viezka]"), t({"", ""}),
          i(1),
          t({"", "[/viezka]"}),
        }),
        s("code", {
          t([[ [code lang="]]), i(1, "text"), t([[ " title="]]), i(2), t({[["] ]], ""}),
          i(3),
          t({"", "[/code]"}),
        }),
        s("url", {
          t("[url="), i(1), t("]"), i(2), t("[/url]"),
        }),
        s("warning", {
          t("[warning]"), t({"", ""}),
          i(1),
          t({"", "[/warning]"}),
        }),
      })

      -- --- Clipboard Image ---
      require('clipboard-image').setup({
        default = {
          img_dir = "images",
          img_dir_txt = "images",
          affix = "![](%s)"
        }
      })
      vim.keymap.set("n", "<leader>i", ":PasteImg<CR>", { desc = "Paste Image" })

      -- --- Markdown Preview ---
      -- Auto-start preview for markdown files
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "markdown",
        callback = function()
          vim.cmd("MarkdownPreview")
        end,
      })

      -- --- nvim-surround ---
      require("nvim-surround").setup({})

      EOF
    '';
  };
}
