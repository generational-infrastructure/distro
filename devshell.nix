{ perSystem, pkgs, ... }:
pkgs.mkShell {
  # Add build dependencies
  packages = [
    perSystem.self.formatter
  ];

  # Add environment variables
  env = { };

  # Load custom bash code
  shellHook = ''

  '';
}
