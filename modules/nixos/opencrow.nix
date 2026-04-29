# Opinionated opencrow wrapper for nostr backend + local Ollama LLM.
#
# Wraps the upstream services.opencrow NixOS module, providing:
# - Nostr backend as default
# - Ollama provider with models.json auto-generation
# - Sensible defaults for relays, timeouts, and logging
# Requires `inputs` in module args (specialArgs or _module.args).
#
# The upstream opencrow NixOS module is imported by distro.nix.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.opencrow-nostr;
in
{

  options.services.opencrow-nostr = {
    enable = lib.mkEnableOption "opencrow with nostr backend and local Ollama LLM";

    instanceName = lib.mkOption {
      type = lib.types.str;
      default = "nostr";
      description = ''
        Name for the opencrow instance. The upstream module prefixes this
        with "opencrow-", so e.g. "geninf" yields container opencrow-geninf.
        Use "default" for the unprefixed name "opencrow".
      '';
    };

    llmUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:8012";
      description = "Base URL of an OpenAI-compatible LLM server (without /v1 suffix).";
    };

    model = lib.mkOption {
      type = lib.types.str;
      default = "gemma-4:e2b";
      description = "Model name to request from the LLM server.";
    };

    relays = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "Nostr relay WebSocket URLs.";
    };

    dmRelays = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Nostr DM relay URLs (NIP-17). Falls back to relays if empty.";
    };

    blossomServers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Blossom server URLs for encrypted file uploads.";
    };

    allowedUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "npubs or hex pubkeys allowed to interact. Empty allows all.";
    };

    profile = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Bot profile name (NIP-01 kind 0).";
      };
      displayName = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Bot profile display name.";
      };
      about = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Bot profile bio.";
      };
      picture = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Bot profile picture URL.";
      };
    };

    privateKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to file containing nostr private key (hex or nsec). Alternative: use environmentFiles.";
    };

    environmentFiles = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      description = "Environment files with secrets (OPENCROW_NOSTR_PRIVATE_KEY, API keys, etc.).";
    };

    credentialFiles = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      default = { };
      description = "Systemd credential files passed to the container.";
    };

    piPackage = lib.mkOption {
      type = lib.types.package;
      description = "The pi coding agent package.";
    };

    extraEnvironment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Additional environment variables.";
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Extra packages available inside the container.";
    };

    skills = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      default = { };
      description = "Extra skill directories for pi.";
    };

    extensions = lib.mkOption {
      type = lib.types.attrsOf (lib.types.either lib.types.bool lib.types.path);
      default = { };
      description = "Pi extensions to enable (true for bundled, path for custom).";
    };

    piSettings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Extra keys for pi's settings.json (merged with auto-generated provider config).";
    };
  };

  config = lib.mkIf cfg.enable {
    # models.json for pi provider discovery. Pi reads this separately
    # from settings.json. The state dir is bind-mounted into the
    # container, so a host-side symlink is visible inside.
    systemd.tmpfiles.rules =
      let
        stateDir =
          if cfg.instanceName == "default"
          then "/var/lib/opencrow"
          else "/var/lib/opencrow-${cfg.instanceName}";
        modelsJson = pkgs.writeText "models-${cfg.instanceName}.json" (
          builtins.toJSON {
            providers.local = {
              baseUrl = "${cfg.llmUrl}/v1";
              api = "openai-completions";
              apiKey = "dummy";
              compat = {
                supportsDeveloperRole = false;
                supportsReasoningEffort = false;
              };
              models = [
                { id = cfg.model; }
              ];
            };
          }
        );
      in
      [
        "L+ ${stateDir}/pi-agent/models.json - - - - ${modelsJson}"
      ];

    services.opencrow.instances.${cfg.instanceName} = {
      enable = true;
      inherit (cfg)
        piPackage
        skills
        extensions
        extraPackages
        environmentFiles
        credentialFiles
        piSettings
        ;

      environment =
        {
          OPENCROW_BACKEND = "nostr";
          OPENCROW_PI_PROVIDER = "local";
          OPENCROW_PI_MODEL = cfg.model;
          OPENCROW_PI_IDLE_TIMEOUT = "1h";
          OPENCROW_LOG_LEVEL = "info";

          OPENCROW_NOSTR_RELAYS = lib.concatStringsSep "," cfg.relays;
          OPENCROW_NOSTR_NAME = cfg.profile.name;
          OPENCROW_NOSTR_DISPLAY_NAME = cfg.profile.displayName;
          OPENCROW_NOSTR_ABOUT = cfg.profile.about;
          OPENCROW_NOSTR_PICTURE = cfg.profile.picture;
        }
        // lib.optionalAttrs (cfg.dmRelays != [ ]) {
          OPENCROW_NOSTR_DM_RELAYS = lib.concatStringsSep "," cfg.dmRelays;
        }
        // lib.optionalAttrs (cfg.blossomServers != [ ]) {
          OPENCROW_NOSTR_BLOSSOM_SERVERS = lib.concatStringsSep "," cfg.blossomServers;
        }
        // lib.optionalAttrs (cfg.allowedUsers != [ ]) {
          OPENCROW_NOSTR_ALLOWED_USERS = lib.concatStringsSep "," cfg.allowedUsers;
        }
        // lib.optionalAttrs (cfg.privateKeyFile != null) {
          OPENCROW_NOSTR_PRIVATE_KEY_FILE = toString cfg.privateKeyFile;
        }
        // cfg.extraEnvironment;
    };
  };
}
