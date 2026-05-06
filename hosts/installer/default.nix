# Blueprint entry point for the `installer` host — the bootable
# graphical installer ISO image.
#
# Build the ISO with:
#   nix build .#nixosConfigurations.installer.config.system.build.isoImage
{
  inputs,
  flake,
  hostName,
}:
{
  class = "nixos";
  value = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = {
      inherit inputs flake hostName;
    };
    modules = [
      { nixpkgs.hostPlatform = "x86_64-linux"; }
      ../../modules/nixos/installer-iso.nix
    ];
  };
}
