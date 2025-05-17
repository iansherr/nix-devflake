#!/usr/bin/env bash
# flakegen.sh
set -euo pipefail

# --- Flakegen: Generate flake.nix based on environment ---

run_flakegen() {
  # Generate the project-specific flake
if [[ ! -f "$PROJECT_DIR/flake.nix" ]]; then
  cd "$PROJECT_DIR" || exit 1
  cat <<EOF >flake.nix
{
  description = "${PROJECT_NAME} development environment";

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
        default = pkgs.mkShell {
          name = "${ENVIRONMENT}dev";
          buildInputs = with pkgs; [

            # common
            git
            pre-commit

            # neovim and plugins build requirements
            cmake
            curl

            zoxide
            ncurses
            neovim
            unzip

            # Needed by plugins
            fd
            lazygit
            jq
            ripgrep
            tree-sitter
            xclip

            # OS
            bashmount

EOF

  # Add environment-specific tools
  case "$ENVIRONMENT" in
  sscript)
    cat <<EOF >>flake.nix
            nano
            lua
            luau
            luajit
            yarn
EOF
    ;;
  # Add environment-specific tools
  python)
    cat <<EOF >>flake.nix
            python310
            python312Full
            poetry
            black
            isort
            python312Packages.pytest
EOF
    ;;
  web)
    cat <<EOF >>flake.nix
            nodejs_23
            yarn
            prettierd
            nodePackages.prettier

            python310
            python312Full

            jdk23
            python312Packages.pytest

            # switching to uv
            uv

            # backwards support for pip and pipx
            python312Packages.pip
            pipx

EOF
    ;;
  rust)
    cat <<EOF >>flake.nix
            rustc
            cargo
            rust-analyzer
            clippy
EOF
    ;;
  go)
    cat <<EOF >>flake.nix
            go
            delve
            gdlv
            gopls
            golangci-lint
EOF
    ;;
  java)
    cat <<EOF >>flake.nix
            nodejs_23
            maven
            gradle
            eclipses.eclipse-sdk
EOF
    ;;
  *)
    echo "Unknown environment: $ENVIRONMENT"
    exit 1
    ;;
  esac


  # Finish flake.nix
  cat <<EOF >>flake.nix
        ];

        shellHook = ''
          echo "${ENVIRONMENT} development environment loaded!"
          if [ -f .pre-commit-config.yaml ]; then
            echo "Pre-commit config detected. Installing hooks..."
            pre-commit install
          fi
        '';
      };
    });
  };
}
EOF

  echo "Created ${ENVIRONMENT} flake.nix"

  if [[ ! -s "flake.nix" ]]; then
    echo "Error: flake.nix was not written properly!"
    read -rp "Do you want to delete and recreate it? (y/N): " DELETE_FLAKE </dev/tty
    if [[ "$DELETE_FLAKE" =~ ^[Yy]$ ]]; then
      rm -f flake.nix
      echo "Recreating flake.nix..."
      exec "$0" "$@" # Restart script
    else
      echo "Keeping existing flake.nix. Exiting."
      exit 1
    fi
  fi
else
  echo "flake.nix already exists. Verifying..."
  if ! grep -q "description" flake.nix; then
    echo "flake.nix appears corrupted. Recreating..."
    rm flake.nix
    exec "$0" "$@" # Restart script
  fi
fi
}
