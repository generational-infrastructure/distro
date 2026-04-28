# NNN Stack desktop: NixOS + Niri + Noctalia.
#
# This is the minimal Wayland-native desktop substrate for the Local AI OS POC:
# scrollable tiling, a cohesive Quickshell shell, and enough fallback tools that
# the system is usable before per-user dotfiles exist.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.distro.nnn;

  terminal = lib.getExe cfg.terminalPackage;
  launcher = lib.getExe cfg.launcherPackage;
  noctalia = lib.getExe cfg.noctaliaPackage;
  xwayland = lib.getExe pkgs.xwayland-satellite;
in
{
  options.distro.nnn = {
    enable = lib.mkEnableOption "the NNN Stack desktop profile (NixOS + Niri + Noctalia)";

    terminalPackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.foot;
      defaultText = lib.literalExpression "pkgs.foot";
      description = "Terminal launched by the default Niri keybindings.";
    };

    launcherPackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.fuzzel;
      defaultText = lib.literalExpression "pkgs.fuzzel";
      description = "Fallback launcher launched by Mod+D.";
    };

    noctaliaPackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.noctalia-shell;
      defaultText = lib.literalExpression "pkgs.noctalia-shell";
      description = "Noctalia shell package spawned inside the Niri session.";
    };

    spawnNoctalia = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Start Noctalia automatically when Niri starts.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.niri.enable = true;

    hardware.graphics.enable = lib.mkDefault true;
    security.polkit.enable = lib.mkDefault true;

    # GDM gives us a reliable graphical login and a Niri session selector. This
    # is deliberately mkDefault so hardware profiles can swap in greetd/cosmic/etc.
    services.xserver.enable = lib.mkDefault true;
    services.displayManager.gdm = {
      enable = lib.mkDefault true;
      wayland = lib.mkDefault true;
    };

    environment.systemPackages = [
      cfg.terminalPackage
      cfg.launcherPackage
      cfg.noctaliaPackage
      pkgs.xwayland-satellite
      pkgs.wl-clipboard
      pkgs.cliphist
      pkgs.brightnessctl
      pkgs.playerctl
      pkgs.pamixer
      pkgs.pavucontrol
      pkgs.nautilus
    ];

    fonts.packages = with pkgs; [
      font-awesome
      nerd-fonts.symbols-only
      noto-fonts
      noto-fonts-color-emoji
    ];

    # System-wide default. Users can override with ~/.config/niri/config.kdl.
    environment.etc."xdg/niri/config.kdl".text = ''
      input {
        keyboard {
          xkb { layout "us"; }
          numlock
        }
        touchpad {
          tap
          natural-scroll
        }
        focus-follows-mouse max-scroll-amount="0%"
      }

      layout {
        gaps 8
        center-focused-column "on-overflow"
        preset-column-widths {
          proportion 0.33333
          proportion 0.5
          proportion 0.66667
        }
        default-column-width { proportion 0.5; }
        focus-ring {
          width 3
          active-color "#7fc8ff"
          inactive-color "#505050"
        }
        border { off; }
      }

      prefer-no-csd
      screenshot-path "~/Pictures/Screenshots/screenshot-%Y-%m-%d-%H-%M-%S.png"

      window-rule {
        geometry-corner-radius 8
        clip-to-geometry true
      }

      spawn-at-startup "${xwayland}"
      ${lib.optionalString cfg.spawnNoctalia ''spawn-at-startup "${noctalia}"''}

      binds {
        Mod+Shift+Slash { show-hotkey-overlay; }

        // Launch
        Mod+Return { spawn "${terminal}"; }
        Mod+T      { spawn "${terminal}"; }
        Mod+D      { spawn "${launcher}"; }

        // Overview
        Mod+O repeat=false { toggle-overview; }

        // Windows
        Mod+Q repeat=false { close-window; }
        Mod+Left  { focus-column-left; }
        Mod+Down  { focus-window-down; }
        Mod+Up    { focus-window-up; }
        Mod+Right { focus-column-right; }
        Mod+H     { focus-column-left; }
        Mod+J     { focus-window-down; }
        Mod+K     { focus-window-up; }
        Mod+L     { focus-column-right; }

        Mod+Ctrl+Left  { move-column-left; }
        Mod+Ctrl+Down  { move-window-down; }
        Mod+Ctrl+Up    { move-window-up; }
        Mod+Ctrl+Right { move-column-right; }
        Mod+Ctrl+H     { move-column-left; }
        Mod+Ctrl+J     { move-window-down; }
        Mod+Ctrl+K     { move-window-up; }
        Mod+Ctrl+L     { move-column-right; }

        Mod+Shift+Left  { focus-monitor-left; }
        Mod+Shift+Right { focus-monitor-right; }

        // Sizing
        Mod+R { switch-preset-column-width; }
        Mod+F { maximize-column; }
        Mod+Shift+F { fullscreen-window; }
        Mod+C { center-column; }
        Mod+Minus { set-column-width "-10%"; }
        Mod+Equal { set-column-width "+10%"; }

        // Float / tabs / consume
        Mod+V       { toggle-window-floating; }
        Mod+Shift+V { switch-focus-between-floating-and-tiling; }
        Mod+W       { toggle-column-tabbed-display; }
        Mod+BracketLeft  { consume-or-expel-window-left; }
        Mod+BracketRight { consume-or-expel-window-right; }

        // Workspaces
        Mod+1 { focus-workspace 1; }
        Mod+2 { focus-workspace 2; }
        Mod+3 { focus-workspace 3; }
        Mod+4 { focus-workspace 4; }
        Mod+5 { focus-workspace 5; }
        Mod+Ctrl+1 { move-column-to-workspace 1; }
        Mod+Ctrl+2 { move-column-to-workspace 2; }
        Mod+Ctrl+3 { move-column-to-workspace 3; }
        Mod+Ctrl+4 { move-column-to-workspace 4; }
        Mod+Ctrl+5 { move-column-to-workspace 5; }
        Mod+Page_Down { focus-workspace-down; }
        Mod+Page_Up   { focus-workspace-up; }

        // Media keys
        XF86AudioRaiseVolume allow-when-locked=true { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+"; }
        XF86AudioLowerVolume allow-when-locked=true { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-"; }
        XF86AudioMute        allow-when-locked=true { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }
        XF86AudioPlay allow-when-locked=true { spawn "playerctl" "play-pause"; }
        XF86AudioPrev allow-when-locked=true { spawn "playerctl" "previous"; }
        XF86AudioNext allow-when-locked=true { spawn "playerctl" "next"; }
        XF86MonBrightnessUp   { spawn "brightnessctl" "set" "+10%"; }
        XF86MonBrightnessDown { spawn "brightnessctl" "set" "10%-"; }

        // Screenshot (niri built-in)
        Print       { screenshot; }
        Shift+Print { screenshot-screen; }
        Alt+Print   { screenshot-window; }

        // Session
        Mod+Shift+E { quit; }
        Ctrl+Alt+Delete { quit; }
      }
    '';
  };
}
