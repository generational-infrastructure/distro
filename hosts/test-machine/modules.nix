# Shared module list for the test-machine host.
#
# Both the blueprint entry point (default.nix) and the NixOS integration
# test (checks/test-machine.nix) import this so the machine definition
# stays in one place.
[
  ../../modules/nixos/distro.nix
  ./configuration.nix
]
