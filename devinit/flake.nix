{
  description = "Development environments for various projects.";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }: let
    # Helper function to iterate over supported systems
    forEachSystem = f: {
      x86_64-linux = f "x86_64-linux";
      x86_64-darwin = f "x86_64-darwin";
      aarch64-darwin = f "aarch64-darwin";
      aarch64-linux = f "aarch64-linux";
      riscv64-linux = f "riscv64-linux";
    };
  in {
    devShells = forEachSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in {
      bootstrap = pkgs.mkShell {
        name = "bootstrap-env";
        buildInputs = with pkgs; [
          bash
          git
          pre-commit
          python310 # For Python projects
          poetry    # For Python dependency management
          nodejs    # For Web projects
          yarn      # For Web dependency management
          rustc     # For Rust projects
          go        # For Go projects
          openjdk   # For Java projects
          maven

          # neovim and plugins build requirements
          cargo
          cmake
          curl
          git
          ncurses
          neovim
          nodejs
          unzip
          yarn

          # Needed by plugins
          fd
          lazygit
          ripgrep
          tree-sitter
          xclip
        ];
        shellHook = ''
          echo "Bootstrap environment loaded."
        '';
      };

      # Optionally add other reusable environments
      default = pkgs.mkShell {
        name = "default-env";
        buildInputs = with pkgs; [
          git
          docker
          pre-commit
        ];
        shellHook = ''
          echo "General-purpose development environment loaded."
        '';
      };
    });
  };
}
