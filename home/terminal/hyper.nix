{ pkgs, ... }:

{
  home.packages = with pkgs; [
    hyper
  ];

  # Hyper configuration
  home.file.".hyper.js".text = ''
    module.exports = {
      config: {
        updateChannel: 'stable',
        fontSize: 14,
        fontFamily: '"SpaceMono Nerd Font", Menlo, "DejaVu Sans Mono", Consolas, "Lucida Console", monospace',
        fontWeight: 'normal',
        fontWeightBold: 'bold',
        lineHeight: 1,
        letterSpacing: 0,
        cursorColor: 'rgba(248,28,229,0.8)',
        cursorAccentColor: '#000',
        cursorShape: 'BLOCK',
        cursorBlink: false,
        foregroundColor: '#fff',
        backgroundColor: '#000',
        selectionColor: 'rgba(248,28,229,0.3)',
        borderColor: '#333',
        css: `
          .hyper_main {
            background-color: rgba(30, 30, 46, 0.85) !important; /* Catppuccin Base with opacity */
            backdrop-filter: blur(10px);
            border: 1px solid #f5c2e7; /* Bocchi Pink Border */
            border-radius: 10px;
          }
          .header_header {
            background-color: rgba(30, 30, 46, 0.9) !important;
          }
          .tabs_nav {
            border-bottom: 1px solid #f5c2e7 !important;
          }
          .tab_tab {
            border: none !important;
            color: #cdd6f4 !important;
          }
          .tab_active {
            background-color: rgba(245, 194, 231, 0.2) !important; /* Pink tint */
            color: #f5c2e7 !important;
          }
        `,
        termCSS: '',
        showHamburgerMenu: '',
        showWindowControls: '',
        padding: '12px 14px',
        colors: {
          black: '#000000',
          red: '#C51E14',
          green: '#1DC121',
          yellow: '#C7C329',
          blue: '#0A2FC4',
          magenta: '#ED1556',
          cyan: '#20C5C6',
          white: '#C7C7C7',
          lightBlack: '#686868',
          lightRed: '#FD6F6B',
          lightGreen: '#67F86F',
          lightYellow: '#FFFA72',
          lightBlue: '#6A76FB',
          lightMagenta: '#FD7CFC',
          lightCyan: '#68FDFE',
          lightWhite: '#FFFFFF',
        },
        shell: '${pkgs.zsh}/bin/zsh',
        shellArgs: ['--login'],
        env: {},
        bell: 'SOUND',
        copyOnSelect: false,
        defaultSSHApp: true,
        quickEdit: true,
        macOptionSelectionMode: 'vertical',
        webGLRenderer: true,
        webLinksActivationKey: '',
        disableLigatures: true,
        disableAutoUpdates: false,
        screenReaderMode: false,
        preserveCWD: true,
      },
      plugins: [],
      localPlugins: [],
      keymaps: {},
    };
  '';
}
