{ inputs, pkgs, ... }:
pkgs.python3Packages.buildPythonApplication {
  pname = "osm-cli";
  version = "0.1.0";
  pyproject = true;
  src = ./.;
  build-system = [ pkgs.python3Packages.hatchling ];
  meta.mainProgram = "osm-cli";
}
