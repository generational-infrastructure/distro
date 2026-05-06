# Convenience alias — exposes the bootable ISO image as
# `packages.<system>.installer-iso` so it can be fetched with
# `nix build .#installer-iso` without spelling out the full
# `nixosConfigurations.installer.config.system.build.isoImage` path.
{ flake, ... }: flake.nixosConfigurations.installer.config.system.build.isoImage
