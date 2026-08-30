{
  description = "cmake_template reproducible C++ development shell and image";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      packagesFor = pkgs: with pkgs; [
        gcc
        clang
        lld
        cmake
        ninja
        git
        doxygen
        graphviz
        pkg-config
        wayland
        libxkbcommon
        libGL
      ];
    in {
      devShells = forAllSystems (system:
        let pkgs = import nixpkgs { inherit system; };
        in {
          default = pkgs.mkShell {
            packages = packagesFor pkgs;
          };
        });

      packages = forAllSystems (system:
        let pkgs = import nixpkgs { inherit system; };
        in {
          docker = pkgs.dockerTools.buildLayeredImage {
            name = "cmake-template-nix";
            tag = "latest";
            contents = packagesFor pkgs;
            config = {
              WorkingDir = "/app";
              Entrypoint = [ "cmake" "--workflow" "--preset=gcc-full" ];
            };
          };
          default = self.packages.${system}.docker;
        });
    };
}
