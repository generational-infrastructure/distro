# Test-machine host configuration.
#
# Pure config — no module imports. Modules come from distro.nix,
# wired in by default.nix (blueprint) or the test harness.
{ config, inputs, ... }:

let
  userSK = "0000000000000000000000000000000000000000000000000000000000000001";
  userPK = "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798";
  botSK  = "0000000000000000000000000000000000000000000000000000000000000002";
  botPK  = "c6047f9441ed7d6d3045406e95c07cd85c778e4b8cef3ca7abac09b95c709ee5";
  relay  = "ws://127.0.0.1:7777";
in
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

  services.geninf-strfry = {
    enable = true;
    bind = "127.0.0.1";
    port = 7777;
  };

  services.nostr-chatd = {
    enable = true;
    noctaliaPlugin = true;
    noctaliaPluginUsers = [ "test" ];
    peerPubkey = botPK;
    relays = [ relay ];
    secretCommand = "cat /etc/nostr-test-user-key";
  };

  environment.etc."nostr-test-user-key" = {
    text = userSK;
    mode = "0444";
  };
  # Bot env file with private key. Bind-mounted into the opencrow
  # container via the environmentFiles option.
  environment.etc."nostr-test-bot.env" = {
    text = "OPENCROW_NOSTR_PRIVATE_KEY=${botSK}\n";
    mode = "0444";
  };

  services.opencrow-nostr = {
    enable = true;
    relays = [ relay ];
    llmUrl = "http://127.0.0.1:8012";
    piPackage = inputs.llm-agents.packages.x86_64-linux.pi;
    environmentFiles = [ "/etc/nostr-test-bot.env" ];
    profile = {
      name = "testbot";
      displayName = "Test Bot";
      about = "Integration test bot";
    };
  };

  services.llama-swap.enable = true;

  system.stateVersion = "25.05";
}
