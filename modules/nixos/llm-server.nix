# Server-side LLM offload profile.
#
# Runs the llama-swap module as an OpenAI-compatible endpoint for desktop
# machines. The service is intentionally self-hosted: models are pinned by Nix
# in modules/nixos/llama-swap.nix, and clients point llm-router at this endpoint.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.distro.llm-server;
  llamaPort = config.services.llama-swap.port;
in
{
  imports = [ ./llama-swap.nix ];

  options.distro.llm-server = {
    enable = lib.mkEnableOption "Local AI OS LLM offload server";

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "Address for llama-swap to listen on.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8012;
      description = "OpenAI-compatible llama-swap port.";
    };

    firewallInterfaces = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "wg0"
        "tailscale0"
        "kinq0"
      ];
      description = ''
        Interfaces on which to expose the LLM server port. Keep empty for
        localhost-only/firewall-closed deployments; prefer a mesh interface over
        opening this on the public Internet.
      '';
    };

    cudaCapabilities = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "12.0" ];
      description = ''
        Optional CUDA capabilities to pass to nixpkgs, e.g. [ "12.0" ] for a
        Blackwell/RTX 5090 class server. Leave empty to use nixpkgs defaults.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.config.cudaCapabilities = lib.mkIf (cfg.cudaCapabilities != [ ]) cfg.cudaCapabilities;

    services.llama-swap = {
      enable = true;
      listenAddress = lib.mkDefault cfg.listenAddress;
      port = lib.mkDefault cfg.port;
    };

    networking.firewall.interfaces = lib.genAttrs cfg.firewallInterfaces (_: {
      allowedTCPPorts = [ llamaPort ];
    });

    environment.systemPackages = [
      pkgs.curl
      pkgs.jq
      config.services.llama-swap.llama-server-package
    ];
  };
}
