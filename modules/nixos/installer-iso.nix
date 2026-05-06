# Distro graphical installer ISO.
#
# Imports the upstream NixOS Calamares-GNOME live image and:
#   - shadows `calamares-nixos-extensions` via a nixpkgs overlay so
#     all upstream references resolve to our fork
#     (`calamares-distro-extensions`), which drops `packagechooser`
#     and emits a flake-based install referencing the distro flake
#     by its /nix/store path;
#   - bakes that store path into the patched `main.py` at
#     extensions-package build time via the `distroFlake` arg;
#   - pre-stages the distro flake source + a representative installed
#     system closure into the ISO's nix store so `nixos-install`
#     resolves everything offline.
#
# The live env is upstream GNOME; the *installed* env is niri (set
# by `nixosModules.distro` pulled in via the generated flake). That
# mismatch is intentional v1 — the live env doesn't need to match
# what we install.
{
  inputs,
  flake,
  ...
}:
let
  inherit (flake.lib) distroSrc;

in
{
  imports = [
    "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-graphical-calamares-gnome.nix"
  ];

  # Replace upstream extensions package wherever it's referenced.
  # The overlay also threads `flake.outPath` through as `distroFlake`,
  # so the generated wrapper flake's `inputs.distro.url` resolves to
  # an immutable store path rather than a mutable copy under /mnt.
  nixpkgs.overlays = [
    (final: prev: {
      calamares-nixos-extensions = final.callPackage ../../packages/calamares-distro-extensions {
        base = prev.calamares-nixos-extensions;
        distroFlake = distroSrc;
        # Outer flake inputs — the wrapper-lock generator reads
        # distro's own flake.lock to discover which input names to
        # re-point at staged store paths.
        flakeInputs = inputs;
      };
    })
  ];

  # Trade ISO size for build speed: upstream defaults to
  # `zstd -Xcompression-level 19` which takes minutes to recompress
  # whenever any flake source byte changes. Level 5 cuts squashfs
  # build time by ~5x at the cost of a moderately larger image —
  # acceptable since this is a per-machine install medium, not a
  # download artifact.
  isoImage.squashfsCompression = "zstd -Xcompression-level 3";

  # Pre-stage everything `nix-build` + `nixos-install` will touch:
  #
  #   - distroSrc itself (referenced by `path:<store>` in default.nix);
  #   - the toplevel closure of a representative installed system, so
  #     `nixos-install --system <toplevel>` substitutes from the local
  #     store rather than refetching;
  #   - upstream nixpkgs source, so post-install `nixos-rebuild` also
  #     evaluates offline;
  #   - every flake input outPath.  When nix-build evaluates the distro
  #     flake via `builtins.getFlake "path:..."`, it reads flake.lock
  #     and fetchTree's each input.  fetchTree resolves locally if the
  #     source path with the matching narHash is in the store; the
  #     evaluated input outPath has that same narHash.  Without these
  #     entries, every install hits the network for blueprint, opencrow,
  #     noctalia-shell, etc.
  isoImage.storeContents = [
    distroSrc
    flake.nixosConfigurations.installer-target.config.system.build.toplevel
  ];
}
