# Local AI OS desktop profile.
#
# Daily-driver baseline: NNN Stack desktop plus a local/offload LLM client lane.
{ lib, pkgs, ... }:
{
  imports = [
    ./nnn.nix
    ./llm-client.nix
  ];

  distro.nnn.enable = lib.mkDefault true;
  distro.llm-client = {
    enable = lib.mkDefault true;
    askLocal.serve.enable = lib.mkDefault true;
    router.enable = lib.mkDefault true;
  };

  hardware.bluetooth.enable = lib.mkDefault true;
  networking.networkmanager.enable = lib.mkDefault true;

  security.rtkit.enable = lib.mkDefault true;
  services.pipewire = {
    enable = lib.mkDefault true;
    alsa.enable = lib.mkDefault true;
    alsa.support32Bit = lib.mkDefault true;
    pulse.enable = lib.mkDefault true;
    wireplumber.enable = lib.mkDefault true;
  };

  services.fwupd.enable = lib.mkDefault true;
  services.pcscd.enable = lib.mkDefault true;

  # dconf is needed by many desktop apps even outside GNOME.
  programs.dconf.enable = lib.mkDefault true;
  programs.firefox.enable = lib.mkDefault true;
  programs.bash.completion.enable = lib.mkDefault true;

  environment.systemPackages = with pkgs; [
    git
    curl
    jq
    pciutils
    usbutils
    powertop
  ];

  console.keyMap = lib.mkDefault "us";
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
}
