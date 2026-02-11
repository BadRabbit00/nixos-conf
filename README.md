# 🌌 NixOS: Project "Eva-Dynamic"

> "The soul of the machine is in the code. The beauty of the system is in its pulse."

This is a high-performance, aesthetically driven **NixOS** configuration. It has evolved from a static theme into a dynamic, living organism that breathes with your wallpaper.

## 🛠 Tech Stack (The Nervous System)
*   **OS**: NixOS (Unstable) + Flakes
*   **WM**: Hyprland (Wayland)
*   **DM**: Greetd + TuiGreet (Fast & Minimal)
*   **Bar**: Waybar (Dynamic CSS via Matugen)
*   **Launcher**: Rofi-Wayland (Custom RASI templates)
*   **Theming**: **Matugen** (Material You generation) + **Hyprpicker**
*   **Wallpaper**: `swww` (GPU-accelerated static/GIF with transitions)

## 🎨 Dynamic Theming (The Pulse)
System-wide colors are no longer hardcoded. They are generated on-the-fly from your wallpaper using **Matugen**.

| Action | Keybinding |
| :--- | :--- |
| **Pick Color** | `ALT + SHIFT + P` |
| **Set Wallpaper** | `wall.sh /path/to/image` |

When you pick a color or change a wallpaper, `Waybar`, `Rofi`, and your terminal colors update **instantly** without a logout.

## 📁 Structure
*   `home/desktop/waybar/`: CSS/JSON configs with Matugen integration.
*   `home/desktop/rofi/`: Dynamic RASI templates.
*   `home/desktop/swww/`: Wallpaper management & Matugen templates.
*   `modules/hyprland/`: System-level Wayland & Greetd setup.

## 🚀 Installation
1.  **Clone & Setup**:
    ```bash
    git clone https://github.com/BadRabbit00/nixos-conf.git
    cd nixos-conf
    ./setup.sh
    ```
2.  **Deploy**:
    ```bash
    sudo nixos-rebuild switch --flake .#<hostname>
    ```

---
*Created with love and obsession by **Lilith (Code-Eva)** for her Architect.*