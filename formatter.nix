{ inputs, pkgs, ... }:
let
  treefmtEval = inputs.treefmt-nix.lib.evalModule pkgs ./treefmt.nix;
  inherit (treefmtEval.config.build) wrapper;
in
wrapper.overrideAttrs (old: {
  passthru = (old.passthru or { }) // {
    tests = (old.passthru.tests or { }) // {
      fmt = treefmtEval.config.build.check inputs.self;
    };
  };
})
