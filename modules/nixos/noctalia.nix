# Noctalia Wayland desktop shell.
#
# Installs noctalia-shell (patched with plugins-autoload support) and
# symlinks the opencrow-chat plugin into the autoload directory so it
# is enabled automatically when noctalia starts.
{ inputs }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  noctaliaShell =
    (inputs.noctalia-shell.packages.${pkgs.stdenv.hostPlatform.system}.default).overrideAttrs
      (old: {
        patches = (old.patches or [ ]) ++ [
          ../../patches/noctalia-shell-plugin-autoload.patch
        ];
        # Drop the standalone autoload singleton into the source tree.
        # Keeping the logic in its own file lets the patch above stay tiny
        # (just two hook calls), reducing merge-conflict surface on upgrades.
        postPatch = (old.postPatch or "") + ''
          cp ${../../patches/PluginAutoload.qml} Services/Noctalia/PluginAutoload.qml
        '';
      });
in
{
  config = {
    environment.systemPackages = [ noctaliaShell ];

    # Symlink opencrow-chat into the autoload directory so noctalia
    # auto-enables it and places its bar widget in the center section.
    systemd.user.tmpfiles.rules = [
      "d %h/.config 0755 - - -"
      "d %h/.config/noctalia 0755 - - -"
      "d %h/.config/noctalia/plugins-autoload 0755 - - -"
    ];
  };
}