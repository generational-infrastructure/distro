# Distro module bundle.
#
# Single import that pulls in every NixOS module this distro provides.
# The outer function receives blueprint's publisherArgs at export time,
# so consumers do not need to pass `inputs` via specialArgs.
{ inputs, ... }:
{
  imports = [
    inputs.opencrow.nixosModules.default
    ./niri.nix
    (import ./noctalia.nix { inherit inputs; })
    (import ./opencrow.nix { inherit inputs; })
    ./llama-swap.nix
    ./vm-debug.nix
  ];
}
