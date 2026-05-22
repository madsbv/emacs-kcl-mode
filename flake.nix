{
  description = "Emacs major modes and tooling for KCL";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          libExt = pkgs.stdenv.hostPlatform.extensions.sharedLibrary;
        in
        {
          tree-sitter-kcl = pkgs.stdenv.mkDerivation {
            pname = "tree-sitter-kcl";
            version = "unstable-2026-05-22";

            src = pkgs.fetchFromGitHub {
              owner = "kcl-lang";
              repo = "tree-sitter-kcl";
              rev = "b0b2eb38009e04035a6e266c7e11e541f3caab7c";
              hash = "sha256-Aeu1j77GdsNpo9PU+FcqN3ttT0eLaDKY4n8buftMiDc=";
            };

            buildPhase = ''
              runHook preBuild
              $CC ${pkgs.lib.optionalString pkgs.stdenv.isDarwin "-dynamiclib"} ${pkgs.lib.optionalString (!pkgs.stdenv.isDarwin) "-shared"} -fPIC -O2 -I src \
                -o libtree-sitter-kcl${libExt} src/parser.c src/scanner.c
              runHook postBuild
            '';

            installPhase = ''
              runHook preInstall
              install -Dm755 libtree-sitter-kcl${libExt} "$out/lib/libtree-sitter-kcl${libExt}"
              runHook postInstall
            '';
          };
        }
      );

      checks = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          tree-sitter-kcl = self.packages.${system}.tree-sitter-kcl;
        in
        {
          default = pkgs.stdenvNoCC.mkDerivation {
            pname = "emacs-kcl-mode-check";
            version = "0.1.0";
            src = self;

            nativeBuildInputs = [
              pkgs.emacs
              pkgs.git
              pkgs.kcl
              pkgs.kcl-language-server
              pkgs.gnumake
            ];

            buildPhase = ''
              runHook preBuild
              export HOME="$TMPDIR/home"
              mkdir -p "$HOME/.emacs.d"
              export KCL_LANGUAGE_SERVER="${pkgs.kcl-language-server}/bin/kcl-language-server"
              export KCL_TREE_SITTER_LOAD_PATH="${tree-sitter-kcl}/lib"
              make all
              runHook postBuild
            '';

            installPhase = ''
              runHook preInstall
              touch "$out"
              runHook postInstall
            '';
          };
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          tree-sitter-kcl = self.packages.${system}.tree-sitter-kcl;
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.emacs
              pkgs.git
              pkgs.kcl
              pkgs.kcl-language-server
              pkgs.gnumake
            ];

            shellHook = ''
              export KCL_LANGUAGE_SERVER="${pkgs.kcl-language-server}/bin/kcl-language-server"
              export KCL_TREE_SITTER_LOAD_PATH="${tree-sitter-kcl}/lib"
            '';
          };
        }
      );
    };
}
