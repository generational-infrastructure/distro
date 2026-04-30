# NixOS VM test for the test-machine host.
#
# Headless verification of the wiring around niri, the noctalia
# opencrow-chat plugin, opencrow socket backend, and llama-swap.
#
# We cannot validate rendered output (no GPU in the test runner). What we
# DO verify:
#   - greetd starts and opens a PAM session for the test user
#   - the user manager (user@1000.service) comes up
#   - niri.service activates and exposes a Wayland socket
#   - noctalia-shell is spawned by niri
#   - opencrow-chat plugin is symlinked into the test user's noctalia dir
#   - opencrow container comes up with socket backend
#   - the chat socket is accessible on the host
#   - a message sent through the socket reaches opencrow and a reply
#     comes back
#
# Interactive validation of the shell happens in the GUI VM
# (`nix build .#test-vm && ./result/bin/run-test-machine-vm`).
{ pkgs, inputs, ... }:

let
  testChat = ./test-opencrow-chat.py;
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

      # python3 is needed by the test script that verifies message flow.
      environment.systemPackages = [ pkgs.python3 ];
    };

  testScript =
    { nodes, ... }:
    let
      uid = toString nodes.test-machine.users.users.test.uid;
    in
    ''
      import json
      machine.wait_for_unit("multi-user.target")

      with subtest("greetd autostarts the niri session"):
          machine.wait_for_unit("greetd.service")
          # pam_systemd starts user@1000.service when greetd opens the session;
          # use wait_until_succeeds because the start job may not be queued yet.
          machine.wait_until_succeeds(
              "systemctl is-active user@${uid}.service",
              timeout=30,
          )

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

      with subtest("opencrow-chat plugin is autoloaded"):
          # The plugin symlink must exist in both plugins/ and plugins-autoload/.
          machine.wait_until_succeeds(
              "test -L /home/test/.config/noctalia/plugins/opencrow-chat",
              timeout=30,
          )
          machine.wait_until_succeeds(
              "test -L /home/test/.config/noctalia/plugins-autoload/opencrow-chat",
              timeout=30,
          )
          # plugins.json should show opencrow-chat as auto-enabled.
          machine.wait_until_succeeds(
              "test -f /home/test/.config/noctalia/plugins.json",
              timeout=30,
          )
          # Give noctalia time to scan plugins and save state.
          import time; time.sleep(3)
          plugins = machine.succeed("cat /home/test/.config/noctalia/plugins.json")
          pj = json.loads(plugins)
          states = pj.get("states", {})
          enabled = any(
              s.get("enabled") is True
              for k, s in states.items()
              if "opencrow-chat" in k
          )
          assert enabled, f"opencrow-chat not auto-enabled in plugins.json: {pj}"

      with subtest("opencrow container starts"):
          machine.wait_for_unit("container@opencrow-local.service", timeout=120)
          machine.wait_until_succeeds(
              "systemctl --machine=opencrow-local is-active opencrow.service",
              timeout=60,
          )
          machine.execute(
              "journalctl --machine=opencrow-local -u opencrow.service --no-pager -n 50"
          )

      with subtest("chat socket is accessible"):
          machine.wait_for_file("/run/opencrow-local/chat.sock", timeout=30)
          # Socket symlink for noctalia plugin
          machine.wait_until_succeeds(
              "systemctl --user --machine=test@.host is-active opencrow-socket-link.service",
              timeout=30,
          )
          machine.wait_for_file("/run/user/${uid}/opencrow-chat.sock", timeout=30)

      with subtest("send message and receive reply"):
          machine.copy_from_host("${testChat}", "/tmp/test-chat.py")
          machine.succeed(
              "python3 /tmp/test-chat.py /run/user/${uid}/opencrow-chat.sock"
          )
    '';
}
