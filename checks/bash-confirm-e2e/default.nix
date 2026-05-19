# End-to-end test for the bash-confirm extension wired through opencrow.
#
# Runs the real opencrow binary (from the overridden flake input) against
# a stub `pi` script that fakes the LLM/extension layer: every prompt
# triggers an extension_ui_request{method=confirm} and logs whatever
# response opencrow forwards back. The driver script connects to
# opencrow's chat socket, plays the user role (allow + deny), and asserts
# the stub observed the right responses.
#
# No VM: opencrow runs as a normal process in the build sandbox. The
# socket-level systemd plumbing is exercised separately by
# checks.test-machine (which also boots the chat plugin under niri).
{ pkgs, inputs, ... }:
let
  inherit (inputs.opencrow.packages.${pkgs.stdenv.hostPlatform.system}) opencrow;
  stubPi = pkgs.writeShellApplication {
    name = "pi";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      exec python3 ${./stub-pi.py} "$@"
    '';
  };
in
pkgs.runCommand "bash-confirm-e2e-test"
  {
    nativeBuildInputs = [ pkgs.python3 ];
  }
  ''
    set -euo pipefail
    work=$TMPDIR/work
    mkdir -p "$work"
    python3 ${./driver.py} ${pkgs.lib.getExe opencrow} ${pkgs.lib.getExe stubPi} "$work"
    touch $out
  ''
