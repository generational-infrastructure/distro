# Noctalia bar with AI chat integration.
#
# Builds on noctalia-plugin (opencrow + llama-swap) and adds the
# noctalia desktop shell bar.  Use this to add the AI chat bar to any
# Wayland compositor (GNOME, Sway, Hyprland, \u2026).
{ inputs, ... }:
{ ... }:
{
  imports = [
    inputs.self.nixosModules.noctalia-plugin
    inputs.self.nixosModules.noctalia
  ];
}
