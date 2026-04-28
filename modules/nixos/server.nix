# Local AI OS server profile.
#
# Headless baseline for a user's own GPU offload box. Imports the LLM server
# module but leaves firewall exposure scoped to explicit mesh interfaces.
{ lib, pkgs, ... }:
{
  imports = [ ./llm-server.nix ];

  distro.llm-server.enable = lib.mkDefault true;

  services.openssh = {
    enable = lib.mkDefault true;
    settings.PasswordAuthentication = lib.mkDefault false;
  };

  networking.firewall.allowPing = lib.mkDefault true;

  nix.settings.experimental-features = lib.mkDefault [
    "nix-command"
    "flakes"
  ];

  environment.systemPackages = with pkgs; [
    git
    curl
    jq
    pciutils
    nvtopPackages.full
  ];
}
