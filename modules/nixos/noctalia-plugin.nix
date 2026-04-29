# Noctalia AI chat plugin.
#
# Single import for users who already run noctalia-shell.  Provides the
# opencrow-chat panel plugin and the opencrow agent backend — no bar
# provisioning, no compositor changes.
{ inputs, ... }:
{
  imports = [
    inputs.opencrow.nixosModules.default
    (import ./opencrow.nix { inherit inputs; })
  ];
}
