# Test-machine host configuration.
#
# Pure config — no module imports. Modules come from distro.nix,
# wired in by default.nix (blueprint) or the test harness.
{ config, inputs, ... }:

{
  networking.hostName = "test-machine";

  boot.loader.systemd-boot.enable = true;
  fileSystems."/" = {
    device = "/dev/vda1";
    fsType = "ext4";
  };

  users.users.test = {
    isNormalUser = true;
    uid = 1000;
    initialPassword = "test";
    extraGroups = [ "wheel" ];
  };

  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${config.programs.niri.package}/bin/niri-session";
      user = "test";
    };
  };

  services.opencrow-local = {
    enable = true;
    model = "qwen2.5:0.5b";
    llmUrl = "http://127.0.0.1:8012";
    piPackage = inputs.llm-agents.packages.x86_64-linux.pi;
    socketName = "Test Bot";
    noctaliaPlugin = true;
  };

  services.llama-swap.enable = true;

  system.stateVersion = "25.05";
}
