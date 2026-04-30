# Noctalia AI chat plugin.
#
# Base integration layer.  Single import for users who already run
# noctalia-shell.  Provides the opencrow-chat panel plugin, the opencrow
# agent backend, and llama-swap LLM serving.
#
# Importing this module enables opencrow-local + the noctalia plugin by
# default; override with `services.opencrow-local.enable = false;` (or
# `noctaliaPlugin = false`) if you only want to pull in the option set.
{ inputs, ... }:
let
  inherit (inputs.nixpkgs) lib;
in
{
  imports = [
    inputs.opencrow.nixosModules.default
    (import ./opencrow.nix { inherit inputs; })
    ./llama-swap.nix
  ];

  services.opencrow-local = {
    enable = lib.mkDefault true;
    noctaliaPlugin = lib.mkDefault true;
  };
}
