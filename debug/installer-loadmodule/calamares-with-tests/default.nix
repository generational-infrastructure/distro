# Calamares variant that ships the `loadmodule` test executable.
#
# Upstream nixpkgs `pkgs.calamares` does not build with
# `BUILD_TESTING=ON`, and even when it does, `loadmodule` is
# explicitly *not* installed by Calamares' CMakeLists
# (`src/calamares/CMakeLists.txt`: `# Don't install, these are just
# for enable_testing`). We need it to drive our patched `nixos` job
# module headlessly in NixOS VM tests — it accepts a YAML file via
# `--global` to seed Calamares' globalstorage and runs a single
# module against that, no GUI required.
#
# Strategy:
#   1. Flip `BUILD_TESTING=ON` so the `loadmodule` target is built.
#   2. Copy the binary out of the build tree into `$out/bin` in
#      postInstall (upstream skips the install rule on purpose).
#   3. Reuse the upstream qt wrapper hooks so `loadmodule` finds Qt
#      libs the same way `calamares` does.
{
  pkgs,
  base ? pkgs.calamares,
  ...
}:
base.overrideAttrs (old: {
  pname = "calamares-with-tests";
  cmakeFlags = (old.cmakeFlags or [ ]) ++ [
    "-DBUILD_TESTING=ON"
  ];
  # `loadmodule` is built but not installed by upstream. Place it in
  # `$out/bin` so the qt wrapper picks it up and we can call it from
  # tests via `${calamares-with-tests}/bin/loadmodule`.
  postInstall = (old.postInstall or "") + ''
    install -Dm755 "$(find . -type f -executable -name loadmodule -print -quit)" $out/bin/loadmodule
    # Upstream install rule for loadmodule is intentionally absent, so
    # the binary still carries the build-tree RPATH. Repoint it at the
    # installed Calamares libs so nix's no-/build-references check passes.
    patchelf --set-rpath "$out/lib:$(patchelf --print-rpath $out/bin/loadmodule | tr ':' '\n' | grep -v /build/ | paste -sd:)" $out/bin/loadmodule
  '';
})
