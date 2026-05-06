# Runs treefmt against the flake source and fails if any file would be
# reformatted. Without this, `nix flake check` only builds the formatter
# wrapper (via `pkgs-formatter`) and never exercises it on the tree, so
# formatting drift escapes CI even though `nix fmt` would catch it.
{
  inputs,
  pkgs,
  flake,
  ...
}:
(inputs.treefmt-nix.lib.evalModule pkgs ./../treefmt.nix).config.build.check flake
