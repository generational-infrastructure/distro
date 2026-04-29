# Noctalia Wayland desktop shell.
#
# Installs noctalia-shell and seeds per-user configuration so the
# opencrow-chat bar widget and plugin are enabled out of the box.
#
# plugins.json  — L+ (forced symlink, always nix-managed)
# settings.json — C  (copy-if-absent, user edits preserved)
#
# Uses systemd.user.tmpfiles so every user session gets the config
# automatically — no explicit user list needed.
{ inputs, config, lib, pkgs, ... }:
let
  pluginsJson = pkgs.writeText "noctalia-plugins.json" (builtins.toJSON {
    version = 2;
    states.opencrow-chat.enabled = true;
  });

  settingsJson = pkgs.writeText "noctalia-settings.json" (builtins.toJSON {
    bar.widgets = {
      left = [
        { id = "Launcher"; }
        { id = "Clock"; }
        { id = "SystemMonitor"; }
        { id = "ActiveWindow"; }
        { id = "MediaMini"; }
      ];
      center = [
        { id = "Workspace"; }
        { id = "plugin:opencrow-chat"; }
      ];
      right = [
        { id = "Tray"; }
        { id = "NotificationHistory"; }
        { id = "Battery"; }
        { id = "Volume"; }
        { id = "Brightness"; }
        { id = "ControlCenter"; }
      ];
    };
  });
in
{
  config = {
    environment.systemPackages = [
      inputs.noctalia-shell.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];

    # Seed noctalia config for every user session.
    systemd.user.tmpfiles.rules = [
      "d %h/.config 0755 - - -"
      "d %h/.config/noctalia 0755 - - -"
      # plugins.json: forced symlink — we always control which plugins
      # are enabled. Noctalia reloads on atomic replacement.
      "L+ %h/.config/noctalia/plugins.json - - - - ${pluginsJson}"
      # settings.json: copy-if-absent — seeds the default bar layout
      # with opencrow-chat widget on first boot; user edits persist.
      "C %h/.config/noctalia/settings.json 0644 - - - ${settingsJson}"
    ];
  };
}
