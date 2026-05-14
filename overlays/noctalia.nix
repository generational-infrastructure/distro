# Overlay that replaces `pkgs.noctalia-shell` with distro's recommended
# build: nixpkgs's package + distro's plugins-autoload patch.
#
# Applied automatically by `nixosModules.noctalia` (and therefore by
# `nixosModules.noctalia-bar` / `nixosModules.distro`). Standalone
# consumers who run their own noctalia-shell — for instance via
# home-manager wrapping the package to inject `NOCTALIA_SETTINGS_FILE` —
# can opt in directly:
#
#   nixpkgs.overlays = [ inputs.distro.overlays.noctalia ];
#
# After which `pkgs.noctalia-shell` resolves to the patched build and
# the autoload scan picks up any plugin distro symlinks into
# `~/.config/noctalia/plugins-autoload/`.
#
# The overlay patches `prev.noctalia-shell` rather than substituting a
# pinned flake-input build, so dependencies share the consumer's nixpkgs
# instance and only one nixpkgs is evaluated. The patch tracks the QML
# layout of noctalia ≥ 4.7.6 (what current nixpkgs ships).
{ flake, ... }:
_final: prev: {
  noctalia-shell = flake.lib.patchNoctaliaShell prev.noctalia-shell;
}
