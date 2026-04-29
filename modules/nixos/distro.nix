# Distro module bundle.
#
# Single import that pulls in every NixOS module this distro provides.
# Requires `inputs` in module args (specialArgs or _module.args).
{ inputs, ... }:
{
  imports = [
    inputs.opencrow.nixosModules.default
    ./niri.nix
    ./noctalia.nix
    ./opencrow.nix
    ./llama-swap.nix
    ./vm-debug.nix
  ];
}
