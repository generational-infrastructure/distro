# Unit test for the bash-confirm pi extension (modules/nixos/opencrow/bash-confirm.ts).
#
# Builds a minimal Nix derivation that runs Node's built-in test runner
# against the extension's pure logic — no pi, no opencrow, no VM.
# Catches regressions in the extension's branches (wrong tool, no UI,
# allow, deny, empty command).
{ pkgs, ... }:
pkgs.runCommand "bash-confirm-extension-test"
  {
    src = ../modules/nixos/opencrow;
    nativeBuildInputs = [ pkgs.nodejs_22 ];
  }
  ''
    cp -r $src/. .
    chmod -R +w .
    node --test bash-confirm.test.mjs
    touch $out
  ''
