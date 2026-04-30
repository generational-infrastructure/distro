# Test-machine host configuration.
#
# Pure config — no module imports. Modules come from distro.nix,
# wired in by default.nix (blueprint) or the test harness.
{ ... }:

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

  # Override distro default user for greetd auto-login.
  services.greetd.settings.default_session.user = "test";

  # Use a small model for CI.
  services.opencrow-local.model = "qwen2.5:0.5b";
  system.stateVersion = "25.05";
}