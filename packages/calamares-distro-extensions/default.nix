# Distro fork of upstream `calamares-nixos-extensions`.
#
# We reuse the upstream derivation untouched and only replace files:
#   - config/settings.conf        - drop the `packagechooser` step
#   - config/modules/welcome.conf  - drop internet requirement (offline)
#   - modules/nixos/main.py        - emit a wrapper flake whose inputs are
#                                    locked to pre-staged store paths so
#                                    the install resolves offline.
#
# Files live under ./files/ and are copied over the upstream tree in
# postPatch. A patch-file approach was rejected: the upstream main.py is
# 900+ lines and our rewrite touches most of it, which makes diff-based
# maintenance more fragile than wholesale replacement.
#
# `base` is overridable so the nixpkgs overlay in `installer-iso.nix`
# can shadow `calamares-nixos-extensions` with this fork without hitting
# infinite recursion (passes `prev.calamares-nixos-extensions`).
#
# `distroFlake` is the /nix/store path of the distro flake source. The
# wrapper flake's `inputs.distro` is locked against it at install time.
#
# `flakeInputs` is the outer flake's `inputs` attrset. We read distro's
# `flake.lock` to discover which input names distro declares, and emit a
# `{ name → store path }` mapping into `main.py` for every match. At
# install time `main.py` runs
#   nix flake lock <wrapper> --override-input distro path:<distroFlake>
#                            --override-input distro/<name> path:<path> ...
# which materialises a `flake.lock` with every input resolved against
# the live ISO's nix store — no network needed.
#
# Defaults to {} so the package still builds for unit tests / ad-hoc
# inspection; those builds get an empty override map and `main.py`'s
# substitution slot stays a JSON `{}`.
{
  pkgs,
  base ? pkgs.calamares-nixos-extensions,
  distroFlake ? "@DISTRO_FLAKE_UNSET@",
  flakeInputs ? { },
  ...
}:
let
  inherit (pkgs) lib;

  hasRealDistroFlake = distroFlake != "@DISTRO_FLAKE_UNSET@";

  # Direct input names declared by distro's flake.lock. Source of truth
  # for which inputs need an `--override-input distro/<name>` at install
  # time.
  distroDirectInputNames =
    if hasRealDistroFlake then
      let
        distroLock = builtins.fromJSON (builtins.readFile "${distroFlake}/flake.lock");
      in
      builtins.attrNames distroLock.nodes.root.inputs
    else
      [ ];

  # `{ name → outPath }` for every direct distro input the outer flake
  # provides. Names absent from `flakeInputs` are silently skipped — the
  # outer flake might intentionally leave a transitive input unset (in
  # which case the install will need network for that one); throwing
  # here would break package builds in scenarios where that's
  # acceptable. Missing inputs surface at install time, not build time.
  inputOverrides = lib.genAttrs (builtins.filter (n: flakeInputs ? ${n}) distroDirectInputNames) (
    n: builtins.toString flakeInputs.${n}.outPath
  );
in
base.overrideAttrs (old: {
  pname = "calamares-distro-extensions";
  postPatch = (old.postPatch or "") + ''
    cp -f ${lib.cleanSource ./files/settings.conf} config/settings.conf
    cp -f ${lib.cleanSource ./files/welcome.conf} config/modules/welcome.conf
    cp -f ${lib.cleanSource ./files/main.py}       modules/nixos/main.py
    substituteInPlace modules/nixos/main.py \
      --replace-fail '@DISTRO_FLAKE@' '${toString distroFlake}' \
      --replace-fail '@INPUT_OVERRIDES@' '${builtins.toJSON inputOverrides}'
  '';
})
