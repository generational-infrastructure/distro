# Noctalia Wayland desktop shell.
#
# Installs noctalia-shell and seeds per-user configuration so the
# opencrow-chat bar widget and plugin are enabled out of the box.
#
# plugins.json  — L+ (forced symlink, always nix-managed)
# settings.json — C  (copy-if-absent, user edits preserved)
{ inputs, config, lib, pkgs, ... }:
let
  cfg = config.services.noctalia;

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
  options.services.noctalia = {
    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Users to provision noctalia configuration for.";
      example = [ "alice" ];
    };
  };

  config = {
    environment.systemPackages = [
      inputs.noctalia-shell.packages.${pkgs.system}.default
    ];

    # Seed per-user noctalia config directories and files.
    systemd.tmpfiles.rules = lib.optionals (cfg.users != [ ]) (
      lib.concatMap (user: let
        home = config.users.users.${user}.home;
      in [
        "d ${home}/.config 0755 ${user} users -"
        "d ${home}/.config/noctalia 0755 ${user} users -"
        # plugins.json: forced symlink — we always control which plugins
        # are enabled. Noctalia reloads on atomic replacement.
        "L+ ${home}/.config/noctalia/plugins.json - - - - ${pluginsJson}"
        # settings.json: copy-if-absent — seeds the default bar layout
        # with opencrow-chat widget on first boot; user edits persist.
        "C ${home}/.config/noctalia/settings.json 0644 ${user} users - ${settingsJson}"
      ]) cfg.users
    );
  };
}
