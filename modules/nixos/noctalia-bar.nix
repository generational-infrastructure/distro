# Noctalia bar with AI chat integration.
#
# Single import that provides the noctalia desktop shell bar and the
# opencrow-chat plugin.  Use this to add the AI chat bar to any
# Wayland compositor (GNOME, Sway, Hyprland, …).
{ inputs, ... }:
{
  imports = [
    inputs.opencrow.nixosModules.default
    ./noctalia.nix
    ./opencrow.nix
  ];
}
