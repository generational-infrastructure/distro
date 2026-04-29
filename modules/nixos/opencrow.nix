# Opinionated opencrow wrapper for local use with socket backend + Ollama LLM.
#
# Wraps the upstream services.opencrow NixOS module, providing:
# - Socket backend (local UNIX socket, no relay/keys needed)
# - Ollama provider with models.json auto-generation
# - Noctalia plugin installation (optional)
# The upstream opencrow NixOS module is imported by distro.nix.
{ inputs }:
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.opencrow-local;

  stateDir = "/var/lib/opencrow-${cfg.instanceName}";

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

  pluginDir = ../../programs/opencrow-chat-plugin;
in
{
  options.services.opencrow-local = {
    enable = lib.mkEnableOption "opencrow with local socket backend and Ollama LLM";

    instanceName = lib.mkOption {
      type = lib.types.str;
      default = "local";
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
      default = "gemma4:e2b";
      description = "Model name to request from the LLM server.";
    };

    socketName = lib.mkOption {
      type = lib.types.str;
      default = "OpenCrow";
      description = "Display name shown in status events.";
    };

    piPackage = lib.mkOption {
      type = lib.types.package;
      default = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi;
      defaultText = lib.literalExpression "inputs.llm-agents.packages.\${pkgs.stdenv.hostPlatform.system}.pi";
      description = "The pi coding agent package.";
    };

    environmentFiles = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      description = "Environment files with secrets.";
    };

    credentialFiles = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      default = { };
      description = "Systemd credential files passed to the container.";
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
      description = "Extra keys for pi's settings.json.";
    };

    noctaliaPlugin = lib.mkEnableOption "noctalia opencrow-chat panel plugin" // {
      description = ''
        Symlink the opencrow-chat QML plugin into each user's
        ~/.config/noctalia/plugins/opencrow-chat directory.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Enable llama-swap by default — opencrow-local's default llmUrl
    # points at llama-swap's port (8012).
    services.llama-swap.enable = lib.mkDefault true;
    # models.json for pi provider discovery + noctalia socket symlink.
    systemd.tmpfiles.rules =
      let
        socketDir = "/run/opencrow-${cfg.instanceName}";
      in
      [
        "L+ ${stateDir}/pi-agent/models.json - - - - ${modelsJson}"
        # Host-accessible directory for the chat socket. The state dir
        # itself is 0750 (owned by the container's dynamic user), so we
        # put the socket in a separate world-accessible run dir and
        # bind-mount it into the container.
        "d ${socketDir} 0777 root root -"
      ];

    # Plugin symlink for every user session.
    systemd.user.tmpfiles.rules = lib.optionals cfg.noctaliaPlugin [
      "d %h/.config/noctalia/plugins 0755 - - -"
      "L+ %h/.config/noctalia/plugins/opencrow-chat - - - - ${pluginDir}"
    ];

    # Symlink opencrow's socket and clear stale QML cache on plugin updates.
    # Runs as a user service since XDG_RUNTIME_DIR is per-user.
    systemd.user.services.opencrow-socket-link = lib.mkIf cfg.noctaliaPlugin {
      description = "Symlink opencrow chat socket for noctalia plugin";
      after = [ "graphical-session.target" ];
      wantedBy = [ "graphical-session.target" ];
      # Restart when the plugin store path changes (triggers QML cache clear).
      restartTriggers = [ "${pluginDir}" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "link-opencrow-socket" ''
          ln -sf /run/opencrow-${cfg.instanceName}/chat.sock "$XDG_RUNTIME_DIR/opencrow-chat.sock"
          # Clear QML cache so noctalia picks up updated plugin files.
          rm -rf "''${XDG_CACHE_HOME:-$HOME/.cache}/noctalia-qs/qmlcache" \
                 "''${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/qmlcache"
        '';
        ExecStop = "${pkgs.coreutils}/bin/rm -f %t/opencrow-chat.sock";
      };
    };

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

      # Bind-mount the host socket dir into the container so opencrow
      # can create the socket and the host user can connect to it.
      extraBindMounts."/run/opencrow-sock" = {
        hostPath = "/run/opencrow-${cfg.instanceName}";
        isReadOnly = false;
      };

      environment = {
        OPENCROW_BACKEND = "socket";
        OPENCROW_SOCKET_PATH = "/run/opencrow-sock/chat.sock";
        OPENCROW_SOCKET_NAME = cfg.socketName;
        OPENCROW_PI_PROVIDER = "local";
        OPENCROW_PI_MODEL = cfg.model;
        OPENCROW_PI_IDLE_TIMEOUT = "1h";
        OPENCROW_LOG_LEVEL = "info";
      }
      // cfg.extraEnvironment;
    };
  };
}
