{
  description = "distro";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-unstable";
    blueprint.url = "github:numtide/blueprint";
    blueprint.inputs.nixpkgs.follows = "nixpkgs";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs:
    inputs.blueprint {
      inherit inputs;
      # NixOS modules/tests only make sense on Linux; keep blueprint from
      # generating darwin checks that cannot evaluate nixosTest.
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      nixpkgs.config.allowUnfree = true;
    };
}
