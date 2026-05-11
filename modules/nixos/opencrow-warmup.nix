# Boot-time LLM prompt cache warmup for opencrow.
#
# Two coordinated pieces:
#
# 1. A pi extension (`warmup.ts`) registered on the target opencrow
#    instance. On session_start it POSTs a one-token chat completion
#    to llama-swap with the live system prompt so llama.cpp's prefix
#    KV cache is primed.
#
# 2. A systemd unit that, after llama-swap and the opencrow container
#    are up, cold-spawns pi by sending an unsolicited `list-models`
#    over the chat socket — which triggers the extension above.
#
# The completion side-effect also forces llama-swap to load the
# default model into VRAM, so neither weight loading nor system
# prompt processing is paid on the user's first real message.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.opencrow-warmup;
  containerName =
    if cfg.instanceName == "default" then "opencrow" else "opencrow-${cfg.instanceName}";
  sock = "/run/opencrow-${cfg.instanceName}/chat.sock";
in
{
  options.services.opencrow-warmup = {
    enable = lib.mkEnableOption "boot-time LLM prompt cache warmup for opencrow";

    instanceName = lib.mkOption {
      type = lib.types.str;
      default = "local";
      description = ''
        Opencrow instance name to warm up. Must match an entry under
        `services.opencrow.instances`.
      '';
    };

    extension = lib.mkOption {
      type = lib.types.path;
      default = ./opencrow/warmup.ts;
      defaultText = lib.literalExpression "./opencrow/warmup.ts";
      description = "Pi extension that issues the warmup completion.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.opencrow.instances.${cfg.instanceName}.extensions.warmup = cfg.extension;

    systemd.services.opencrow-warmup-trigger = {
      description = "Cold-spawn opencrow pi to prime LLM prompt cache";
      after = [
        "llama-swap.service"
        "container@${containerName}.service"
      ];
      requires = [ "container@${containerName}.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        # The container takes a moment to create the socket after the
        # unit reports started; retry on transient failure.
        Restart = "on-failure";
        RestartSec = 5;
      };
      script = ''
        set -eu
        for _ in $(seq 1 60); do
          [ -S ${sock} ] && break
          sleep 1
        done
        [ -S ${sock} ] || { echo "chat socket missing" >&2; exit 1; }
        printf '%s\n' '{"cmd":"list-models"}' \
          | ${pkgs.socat}/bin/socat -t 30 - UNIX-CONNECT:${sock} >/dev/null
      '';
    };
  };
}
