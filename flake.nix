{
  description = "cmake_template reproducible C++ development shells";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in {
      devShells = forAllSystems (system:
        let pkgs = import nixpkgs { inherit system; };
        in {
          default = pkgs.mkShell {
            packages = with pkgs; [
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
          };
        });
    };
}
