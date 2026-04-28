# Desktop-side LLM integration.
#
# Provides:
# - ask-local: a small on-device OpenAI-compatible llama.cpp lane
# - llm-router: localhost OpenAI-compatible endpoint that sends small/no-tool
#   requests to the desktop lane and larger/tool requests to a server lane
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.distro.llm-client;
in
{
  options.distro.llm-client = {
    enable = lib.mkEnableOption "Local AI OS desktop LLM client integration";

    askLocal = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Install the ask-local CLI.";
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.callPackage ../../packages/ask-local { };
        defaultText = lib.literalExpression "pkgs.callPackage ../../packages/ask-local { }";
        description = "ask-local package to install/run.";
      };

      serve = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Run ask-local --serve as a system service.";
        };

        host = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "ask-local server bind address.";
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = 8088;
          description = "ask-local server port.";
        };
      };
    };

    router = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Run the llm-router localhost service.";
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.callPackage ../../packages/llm-router { };
        defaultText = lib.literalExpression "pkgs.callPackage ../../packages/llm-router { }";
        description = "llm-router package to run.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 8090;
        description = "localhost port for the router.";
      };

      localEndpoint = lib.mkOption {
        type = lib.types.str;
        default = "http://${cfg.askLocal.serve.host}:${toString cfg.askLocal.serve.port}";
        defaultText = "http://127.0.0.1:8088";
        description = "OpenAI-compatible desktop-local endpoint.";
      };

      upstreamEndpoint = lib.mkOption {
        type = lib.types.str;
        default = "http://127.0.0.1:8012";
        description = ''
          OpenAI-compatible offload endpoint. Point this at the user's GPU server,
          for example http://gpu-server.mesh:8012.
        '';
      };

      tokenCap = lib.mkOption {
        type = lib.types.ints.positive;
        default = 4096;
        description = "Approximate input-token cap for routing requests locally.";
      };
    };

    setSessionVariables = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Export OPENAI_BASE_URL to the local router for graphical/login sessions.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages =
      lib.optionals cfg.askLocal.enable [ cfg.askLocal.package ]
      ++ lib.optionals cfg.router.enable [ cfg.router.package ];

    environment.sessionVariables = lib.mkIf (cfg.router.enable && cfg.setSessionVariables) {
      OPENAI_BASE_URL = "http://127.0.0.1:${toString cfg.router.port}/v1";
      LLM_ROUTER_LOCAL = cfg.router.localEndpoint;
      LLM_ROUTER_UPSTREAM = cfg.router.upstreamEndpoint;
    };

    systemd.services.distro-ask-local = lib.mkIf cfg.askLocal.serve.enable {
      description = "Desktop-local llama.cpp server (ask-local)";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      environment = {
        ASK_LOCAL_HOST = cfg.askLocal.serve.host;
        ASK_LOCAL_PORT = toString cfg.askLocal.serve.port;
        XDG_DATA_HOME = "/var/lib/distro-ask-local";
        XDG_CACHE_HOME = "/var/cache/distro-ask-local";
      };
      serviceConfig = {
        ExecStart = "${lib.getExe cfg.askLocal.package} --serve";
        Restart = "on-failure";
        RestartSec = "5s";
        StateDirectory = "distro-ask-local";
        CacheDirectory = "distro-ask-local";
        SupplementaryGroups = [
          "render"
          "video"
        ];
      };
    };

    systemd.services.distro-llm-router = lib.mkIf cfg.router.enable {
      description = "Local AI OS LLM request router";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      environment = {
        LLM_ROUTER_PORT = toString cfg.router.port;
        LLM_ROUTER_LOCAL = cfg.router.localEndpoint;
        LLM_ROUTER_UPSTREAM = cfg.router.upstreamEndpoint;
        LLM_ROUTER_TOKEN_CAP = toString cfg.router.tokenCap;
        XDG_STATE_HOME = "/var/lib/distro-llm-router";
      };
      serviceConfig = {
        ExecStart = lib.getExe cfg.router.package;
        Restart = "on-failure";
        RestartSec = "5s";
        StateDirectory = "distro-llm-router";
        DynamicUser = true;
        NoNewPrivileges = true;
      };
    };
  };
}
