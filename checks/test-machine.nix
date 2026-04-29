# NixOS VM test for the test-machine host.
#
# Headless verification of the wiring around niri, the noctalia nostr-chat
# plugin, nostr-chatd bridge, strfry relay, and opencrow agent.
#
# We cannot validate rendered output (no GPU in the test runner). What we
# DO verify:
#   - greetd starts and opens a PAM session for the test user
#   - the user manager (user@1000.service) comes up
#   - niri.service activates and exposes a Wayland socket
#   - noctalia-shell is spawned by niri
#   - nostr-chatd plugin is symlinked into the test user's noctalia dir
#   - strfry relay is listening
#   - nostr-chatd user service starts and creates its unix socket
#   - opencrow container comes up
#   - a message sent through nostr-chatd reaches opencrow and a reply
#     comes back on the same socket
#
# Interactive validation of the shell happens in the GUI VM
# (`nix build .#test-vm && ./result/bin/run-test-machine-vm`).
{ pkgs, inputs, ... }:

let
  testNostrChat = ./test-nostr-chat.py;
in
pkgs.testers.runNixOSTest {
  name = "test-machine";
  node.specialArgs = { inherit inputs; };

  nodes.test-machine =
    { lib, pkgs, ... }:
    {
      imports = import ../hosts/test-machine/modules.nix;

      # The host pins a real disk; the test framework provides its own.
      fileSystems = lib.mkForce { };
      boot.loader.systemd-boot.enable = lib.mkForce false;

      virtualisation = {
        memorySize = 4096;
        cores = 4;
        writableStore = true;
      };

      # python3 is needed by the test script that verifies nostr message flow.
      environment.systemPackages = [ pkgs.python3 ];
    };

  testScript =
    { nodes, ... }:
    let
      uid = toString nodes.test-machine.config.users.users.test.uid;
    in
    ''
      machine.wait_for_unit("multi-user.target")

      with subtest("greetd autostarts the niri session"):
          machine.wait_for_unit("greetd.service")
          # pam_systemd starts user@1000.service when greetd opens the session
          machine.wait_for_unit("user@${uid}.service")

      with subtest("niri.service starts under the user manager"):
          machine.wait_until_succeeds(
              "systemctl --user --machine=test@.host is-active niri.service",
              timeout=30,
          )

      with subtest("niri exposes its Wayland socket"):
          machine.wait_for_file("/run/user/${uid}/wayland-1", timeout=30)

      with subtest("niri spawned noctalia-shell"):
          machine.wait_until_succeeds(
              "test -d /run/user/${uid}/quickshell",
              timeout=30,
          )
          machine.wait_until_succeeds(
              "ls /sys/fs/cgroup/user.slice/user-${uid}.slice/"
              "user@${uid}.service/app.slice/ "
              "| grep -q 'app-niri-noctalia.*\\.scope'",
              timeout=30,
          )

      with subtest("nostr-chat plugin is symlinked"):
          machine.wait_until_succeeds(
              "test -L /home/test/.config/noctalia/plugins/nostr-chat",
              timeout=30,
          )

      with subtest("strfry relay is listening"):
          machine.wait_for_unit("strfry.service")
          machine.wait_for_open_port(7777)

      with subtest("nostr-chatd user service starts"):
          machine.wait_until_succeeds(
              "systemctl --user --machine=test@.host is-active nostr-chatd.service",
              timeout=60,
          )
          machine.wait_for_file("/run/user/${uid}/nostr-chatd.sock", timeout=30)

      with subtest("opencrow container starts"):
          machine.wait_for_unit("container@opencrow-nostr.service", timeout=120)
          # Verify the opencrow service is running inside the container.
          # `systemctl --machine=` reaches into the container without a TTY.
          machine.wait_until_succeeds(
              "systemctl --machine=opencrow-nostr is-active opencrow.service",
              timeout=60,
          )
          # Dump opencrow logs for debugging.
          machine.execute(
              "journalctl --machine=opencrow-nostr -u opencrow.service --no-pager -n 50"
          )

      with subtest("send message and receive reply"):
          # Copy the test script into the VM and run it.
          machine.copy_from_host("${testNostrChat}", "/tmp/test-nostr-chat.py")
          machine.succeed(
              "python3 /tmp/test-nostr-chat.py /run/user/${uid}/nostr-chatd.sock"
          )
    '';
}
