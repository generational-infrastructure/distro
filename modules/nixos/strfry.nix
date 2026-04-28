# strfry Nostr relay with optional peer mirroring.
#
# Runs strfry behind a configurable listen address. Does NOT set up a
# reverse proxy or TLS — that is left to the consuming site (nginx,
# caddy, etc.).
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.geninf-strfry;
in
{
  options.services.geninf-strfry = {
    enable = lib.mkEnableOption "strfry Nostr relay";

    name = lib.mkOption {
      type = lib.types.str;
      default = "Nostr Relay";
      description = "Relay name shown in NIP-11 info document.";
    };

    description = lib.mkOption {
      type = lib.types.str;
      default = "A general-purpose Nostr relay";
      description = "Relay description shown in NIP-11 info document.";
    };

    contact = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Operator contact (NIP-11).";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 7777;
      description = "Port strfry listens on.";
    };

    bind = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address to bind to. Use 0.0.0.0 to listen on all interfaces.";
    };

    syncPeers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "wss://nostr.example.com" ];
      description = ''
        Relays to keep a persistent bidirectional strfry router stream to.
        Each side actively pushes and pulls, so neither depends on the
        other being up to eventually backfill missed events.
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the relay port in the firewall.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.etc."strfry.conf".text = ''
      db = "/var/lib/strfry/"

      relay {
        bind = "${cfg.bind}"
        port = ${toString cfg.port}

        info {
          name = "${cfg.name}"
          description = "${cfg.description}"
          contact = "${cfg.contact}"
        }

        nofiles = 0
        maxWebsocketPayloadSize = 131072
        autoPingSeconds = 55
        enableTCPKeepalive = false

        writePolicy {
          plugin = ""
        }

        logging {
          # On public relays the default (invalidEvents = true) produces
          # ~95k "ephemeral event expired" lines per 10 minutes from
          # clients replaying stale kind-2xxxx events. Not actionable.
          invalidEvents = false
        }
      }
    '';

    systemd.services.strfry = {
      description = "strfry Nostr relay";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.strfry}/bin/strfry --config=/etc/strfry.conf relay";
        Restart = "on-failure";
        RestartSec = 5;

        DynamicUser = true;
        StateDirectory = "strfry";

        # WebSocket connections are long-lived; each client holds an fd.
        LimitNOFILE = 65536;

        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectControlGroups = true;
        ReadWritePaths = [ "/var/lib/strfry" ];
      };
    };

    # Router shares the same LMDB env as the relay; strfry's locking
    # supports multiple processes on one db.
    environment.etc."strfry-router.conf" = lib.mkIf (cfg.syncPeers != [ ]) {
      text = ''
        connectionTimeout = 20

        streams {
          ${lib.concatImapStringsSep "\n" (i: url: ''
            peer${toString i} {
              dir = "both"
              urls = [ "${url}" ]
            }
          '') cfg.syncPeers}
        }
      '';
    };

    systemd.services.strfry-router = lib.mkIf (cfg.syncPeers != [ ]) {
      description = "strfry sync stream";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network-online.target"
        "strfry.service"
      ];
      wants = [ "network-online.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.strfry}/bin/strfry --config=/etc/strfry.conf router /etc/strfry-router.conf";
        Restart = "always";
        RestartSec = 10;

        DynamicUser = true;
        StateDirectory = "strfry";

        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectControlGroups = true;
        ReadWritePaths = [ "/var/lib/strfry" ];
      };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];
  };
}
