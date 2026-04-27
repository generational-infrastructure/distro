_: {
  projectRootFile = "flake.nix";

  # Nix
  programs.nixfmt.enable = true;
  programs.deadnix.enable = true;
  programs.deadnix.no-lambda-pattern-names = true;
  programs.statix.enable = true;

  # Bash
  programs.shfmt.enable = true;
  programs.shellcheck.enable = true;

  # Python
  programs.ruff-format.enable = true;
  programs.ruff-check.enable = true;
  programs.ruff-check.extendSelect = [ "I" ];
}
