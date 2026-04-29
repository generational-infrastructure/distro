# nostr-chatd: NIP-17 DM bridge daemon.
#
# Runs as a systemd user service, connects to nostr relays, and exposes
# a UNIX socket (NDJSON protocol) for chat UIs to connect to.
# Works with the noctalia nostr-chat plugin, or any NDJSON client.
#
# Requires: `inputs` available as a module argument (typically via
# specialArgs in the consuming flake).
{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.nostr-chatd;
  # Flake source contains the QML plugin at /nostr-chat
  pluginDir = "${inputs.noctalia-plugins}/nostr-chat";
  # Seed plugins.json so nostr-chat is enabled on first boot.
  # Uses tmpfiles "C" (copy-if-absent) so user edits persist.
  pluginsJson = pkgs.writeText "noctalia-plugins.json" (builtins.toJSON {
    version = 2;
    states.nostr-chat.enabled = true;
  });
in
{
  options.services.nostr-chatd = {
    enable = lib.mkEnableOption "nostr-chatd NIP-17 DM bridge";

    noctaliaPlugin = lib.mkEnableOption "noctalia nostr-chat panel plugin" // {
      description = ''
        Symlink the nostr-chat QML plugin into each user's
        ~/.config/noctalia/plugins/nostr-chat directory.
        Enable the plugin in noctalia's UI on first use.
      '';
    };

    noctaliaPluginUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Users to install the noctalia plugin for.";
      example = [ "pinpox" ];
    };

    peerPubkey = lib.mkOption {
      type = lib.types.str;
      description = "Hex pubkey of the NIP-17 peer (bot) to DM.";
    };

    relays = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "Nostr relays both you and the peer listen on.";
    };

    blossom = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Blossom servers for encrypted file uploads. Empty disables attachments.";
    };

    secretCommand = lib.mkOption {
      type = lib.types.str;
      description = ''
        Shell command that prints your nsec or hex secret key to stdout.
        Runs via sh -c in the user session.
        Examples: "passage show nostr/key", "rbw get 'nostr identity'"
      '';
    };

    displayName = lib.mkOption {
      type = lib.types.str;
      default = "Chat";
      description = "Name shown in the panel header.";
    };

    extraPath = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Extra packages on the daemon's PATH (e.g. for secretCommand).";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = inputs.noctalia-plugins.packages.${pkgs.system}.nostr-chatd;
      description = "The nostr-chatd package to use.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Symlink plugin QML files into each user's noctalia plugins dir
    systemd.tmpfiles.rules = lib.optionals (cfg.noctaliaPlugin && cfg.noctaliaPluginUsers != [ ]) (
      lib.concatMap (user: let
        home = config.users.users.${user}.home;
        dest = "${home}/.config/noctalia/plugins/nostr-chat";
      in [
        # Ensure the full path is owned by the user. Without this,
        # tmpfiles refuses to traverse ownership boundaries (e.g.
        # /home/test owned by test → .config created by greeter as root).
        "d ${home}/.config 0755 ${user} users -"
        "d ${home}/.config/noctalia 0755 ${user} users -"
        "d ${home}/.config/noctalia/plugins 0755 ${user} users -"
        "L+ ${dest} - - - - ${pluginDir}"
        # Seed plugins.json with nostr-chat enabled. "C" = copy only if
        # the file doesn't exist yet, so user edits are preserved.
        "C ${home}/.config/noctalia/plugins.json 0644 ${user} users - ${pluginsJson}"
      ]) cfg.noctaliaPluginUsers
    );

    systemd.user.services.nostr-chatd = {
      description = "Nostr NIP-17 DM bridge";
      after = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      wantedBy = [ "graphical-session.target" ];
      path = cfg.extraPath;
      environment = {
        NOSTR_CHAT_PEER_PUBKEY = cfg.peerPubkey;
        NOSTR_CHAT_RELAYS = lib.concatStringsSep "," cfg.relays;
        NOSTR_CHAT_BLOSSOM = lib.concatStringsSep "," cfg.blossom;
        NOSTR_CHAT_SECRET_CMD = cfg.secretCommand;
        NOSTR_CHAT_DISPLAY_NAME = cfg.displayName;
      };
      serviceConfig = {
        ExecStart = lib.getExe cfg.package;
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
  };
}
