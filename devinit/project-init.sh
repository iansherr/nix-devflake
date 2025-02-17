#!/usr/bin/env bash

# Ian's Nix Development Environment Flake Initialization Script
# This script initializes a new project directory with a flake.nix file
# and a .envrc file for direnv. It also creates a .gitignore file and
# a .pre-commit-config.yaml file with some basic hooks.
# The script will prompt for the project name and the environment type.
# The environment type can be one of the following:
# - sscript: Lua scripting environment
# - python: Python development environment
# - web: Node.js and Python web development environment
# - rust: Rust development environment
# - go: Go development environment
# - java: Java development environment
# The script will also prompt for a git origin repository to add.
#
# Usage: ./project-init.sh [project-name] [environment]
# Example: ./project-init.sh my-project python
#
# This script is part of the Nix Devflake project:
# github.com/iansherr/nix-devflake
#


# Enable strict mode
set -euo pipefail

# Get the script's directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Default devinit directory
DEVELOPMENT_DIR=".devenv/devinit"

# Detect if running inside .devenv/devinit or project root
if [[ "$SCRIPT_DIR" =~ .*/$DEVELOPMENT_DIR$ ]]; then
  # Running from within .devenv/devinit, set project directory to its parent
  PRE_PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
else
  # Running from the project directory itself
  PRE_PROJECT_DIR="$PWD"
fi


ensure_development_dir() {
  # Define where the flake should be located
  local dev_dir="${SCRIPT_DIR}"

   # Prevent infinite recursion by checking if we're already in the Nix environment
  if [[ "${IN_BOOTSTRAP_ENV:-}" == "1" ]]; then
    echo "✅ Already inside the Nix development environment, continuing execution..."
    return
  fi


  # Ensure Nix is installed
  if ! command -v nix &>/dev/null; then
    echo "Nix is not installed. Would you like to install it now? (y/n)"
    read -rp "Enter choice: " install_nix
    if [[ "$install_nix" =~ ^[Yy]$ ]]; then
      echo "Installing Nix..."
      curl -L https://install.determinate.systems/nix | bash -s -- install
      echo "Nix installed successfully. Please restart your terminal or run: source /etc/profile"
    else
      echo "Nix is required. Exiting."
      exit 1
    fi
  fi

  # Ensure Nix experimental features are enabled
  if ! grep -q "experimental-features = nix-command flakes" ~/.config/nix/nix.conf 2>/dev/null; then
    echo "Configuring Nix for flakes and nix-command..."
    mkdir -p ~/.config/nix
    echo "experimental-features = nix-command flakes" | tee -a ~/.config/nix/nix.conf
  fi

  # Check if `nix develop` works
  if ! nix --extra-experimental-features "nix-command flakes" develop --help &>/dev/null; then
    echo "Error: Nix flakes are not working properly. Please check your Nix installation."
    exit 1
  fi

  # Ensure `flake.nix` exists
  if [[ ! -f "${dev_dir}/flake.nix" ]]; then
    echo "Error: flake.nix not found at ${dev_dir}/flake.nix"
    echo "Debugging: Listing contents of ${dev_dir}:"
    ls -lah "${dev_dir}"

    echo "Would you like to:"
    echo "1) Use the remote flake dynamically (without cloning)"
    echo "2) Clone the default flake from GitHub (iansherr/nix-devflake/devinit)"
    echo "3) Specify an existing directory containing the flake"
    echo "4) Exit"
    read -rp "Choose an option [1/2/3/4]: " choice

    case "$choice" in
      1)
        echo "Using remote flake dynamically..."
        REMOTE_FLAKE="github:iansherr/nix-devflake"
        export IN_BOOTSTRAP_ENV=1
        exec nix develop "${REMOTE_FLAKE}"#bootstrap --command "${SCRIPT_DIR}/$(basename "$0")" "$@"
        ;;
      2)
        echo "Cloning development environment from GitHub..."
        mkdir -p "$dev_dir"
        git clone --depth=1 https://github.com/iansherr/nix-devflake.git /tmp/nix-devflake
        cp -R /tmp/nix-devflake/devinit/* "$dev_dir/"
        rm -rf /tmp/nix-devflake
        ;;
      3)
        read -rp "Provide the path to the directory containing the development flake: " provided_dir
        if [[ -d "$provided_dir" ]] && [[ -f "$provided_dir/flake.nix" ]]; then
          echo "Copying development environment from $provided_dir..."
          mkdir -p "$dev_dir"
          cp -R "${provided_dir}/." "$dev_dir"
        else
          echo "Invalid directory provided. Exiting."
          exit 1
        fi
        ;;
      4)
        echo "Exiting without setting up the development environment."
        exit 1
        ;;
      *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
    esac
  else
    export IN_BOOTSTRAP_ENV=1
    exec nix develop "${PRE_PROJECT_DIR}/${DEVELOPMENT_DIR}/"#bootstrap --command "${SCRIPT_DIR}/$(basename "$0")" "$@"
    echo "Development environment is running in: ${PRE_PROJECT_DIR}/${DEVELOPMENT_DIR}"
  fi
}

# Ensure development environment is prepared
ensure_development_dir


# Debugging Output:
echo "Script Directory: $SCRIPT_DIR"
echo "Project Directory: $PRE_PROJECT_DIR"
echo "Expected Flake Location: $PRE_PROJECT_DIR/$DEVELOPMENT_DIR/flake.nix"


# Ask whether to create a new project directory
read -rp "Do you want to create a new project directory? (y/N): " CREATE_NEW
if [[ "$CREATE_NEW" =~ ^[Yy]$ ]]; then
  read -rp "Enter new project name: " PROJECT_NAME
  PROJECT_DIR="${PWD}/${PROJECT_NAME}"
  mkdir -p "$PROJECT_DIR"
else
  PROJECT_NAME=$(basename "$PWD")
  mkdir -p "$PROJECT_NAME"
  PROJECT_DIR="$PWD/$PROJECT_NAME"
fi

# Move all non-script, non-flake files into the project directory
echo "Moving all non-flake and non-script files to the project directory..."
find . -mindepth 1 -maxdepth 1 \
  ! -path "*${SCRIPT_DIR}*" \
  ! -path "*${PROJECT_DIR}*" \
  ! -path "*${PROJECT_NAME}*" \
  ! -path "*/.devenv" \
  ! -path "*/devinit" \
  ! -name "project-init.sh" \
  ! -name "flake.nix" \
  ! -name "README.md" \
  -exec mv {} "$PROJECT_NAME" \;


# Prompt for environment (default to Python)
if [[ $# -lt 2 ]]; then
  echo "Available environments: 'sscript'/lua, python'/pip, 'web'/node/npm, 'rust'/cargo, 'go,' 'java'"
  read -rp "Enter environment [sscript]: " ENVIRONMENT
  ENVIRONMENT=${ENVIRONMENT:-sscript}
else
  ENVIRONMENT=$2
fi

# Generate the project-specific flake
if [[ ! -f "flake.nix" ]]; then
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
            python312Packages.pip
            pipx
            jdk23
            python312Packages.pytest
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
else
  echo "flake.nix already exists. Keeping the existing file."
fi


# Add a pre-commit configuration
if [[ ! -f "${PROJECT_DIR}/.pre-commit-config.yaml" ]]; then
  cat <<EOF >"${PROJECT_DIR}/.pre-commit-config.yaml"
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.3.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-added-large-files
EOF

# Add language-specific pre-commit hooks
if [ "$ENVIRONMENT" = "python" ]; then
  cat <<EOF >>"${PROJECT_DIR}/.pre-commit-config.yaml"
  - repo: https://github.com/psf/black
    rev: 23.1.0
    hooks:
      - id: black
  - repo: https://github.com/PyCQA/flake8
    rev: 6.0.0
    hooks:
      - id: flake8
EOF
fi
  echo "Created .pre-commit-config.yaml"
else
  echo ".pre-commit-config.yaml already exists. Keeping the existing file."
fi



if [[ ! -f ".envrc" ]]; then
  cat <<EOF >.envrc
# Strict mode
set -euo pipefail

# Use Nix Flake
use flake .

# github
#export GITHUB_ORGANIZATION=

# .env
#dotenv

EOF
  echo "Created .envrc"
else
  echo ".envrc already exists. Keeping the existing file."
fi

echo "Development flake ready and .envrc configured for direnv"


# Move into project directory
cd "$PROJECT_DIR"


# Create a .gitignore file
if [[ ! -f "${PROJECT_DIR}/.gitignore" ]]; then
  cat <<EOF >${PROJECT_DIR}/.gitignore
# Editor and OS-specific files
.vscode/
.devenv/
*.DS_Store
Thumbs.db
*.vimrc
*.vim/
*.tmp
*.swp


# Python
__pycache__/
*.pyc
*.pyo
*.pyd
*.pytest_cache/
.mypy_cache/

# Node.js
node_modules/
npm-debug.log*
yarn-error.log*

# Rust
target/
Cargo.lock

# Go
bin/
pkg/
*.test

# Java
*.class
*.jar
*.war
*.ear
*.iml
.gradle/
target/

# Nix
.result
*.drv
result
result-*


# Pre-commit hooks & package manager cache
.pre-commit-config.yaml
.pre-commit-hooks.yaml
.pre-commit-hooks/
.pip-cache/

# Virtual Environments
.env
.venv/
env/
venv/

# Direnv & Shell Environment
.direnv/
.envrc

# Logs & Temporary Files
*.log
*.swp
*.swo
*.swn
*.tmp
*.bak

# Archives, Compressed and Executable Files
*.tgz
*.zip
*.rar
*.tar
*.gz
*.7z
*.exe
EOF
  echo ".gitignore has been created."
else
  echo ".gitignore already exists. Keeping the existing file."
fi





# Create README.md only if it doesn't exist
if [[ ! -f "${PROJECT_DIR}/README.md" ]]; then
  cat <<EOF >"${PROJECT_DIR}/README.md"
# ${PROJECT_NAME}
EOF
fi

# Ensure Git is initialized
git init
git symbolic-ref HEAD refs/heads/main  # Ensure main branch exists
git add .

# Handle Git Origin Prompt
CURRENT_ORIGIN=$(git remote get-url origin 2>/dev/null || echo "")

if [[ -z "$CURRENT_ORIGIN" ]]; then
  while true; do
    read -rp "Do you want to add a git origin repo? (y/N): " ADD_ORIGIN
    case "$ADD_ORIGIN" in
      [Yy]* )
        read -rp "Enter git origin repo URL: " GIT_ORIGIN
        if [[ -n "$GIT_ORIGIN" ]]; then
          git remote add origin "$GIT_ORIGIN"
          echo "✅ Git remote added: $GIT_ORIGIN"
        else
          echo "❌ Invalid URL. Please enter a valid repository."
        fi
        break
        ;;
      [Nn]* | "" )
        echo "❗ Don't forget to add a remote later: 'git remote add origin {REPO}'"
        break
        ;;
      * )
        echo "❓ Invalid response. Please enter 'y' or 'n'."
        ;;
    esac
  done
else
  echo "🔹 Git remote already exists: $CURRENT_ORIGIN"
  read -rp "Do you want to change it? (y/N): " CHANGE_ORIGIN
  if [[ "$CHANGE_ORIGIN" =~ ^[Yy]$ ]]; then
    read -rp "🔄 Enter new git origin URL: " NEW_GIT_ORIGIN
    git remote set-url origin "$NEW_GIT_ORIGIN"
    echo "✅ Git remote updated: $NEW_GIT_ORIGIN"
  fi
fi


pre-commit install --install-hooks
echo "Pre-commit hooks installed."



cd $PRE_PROJECT_DIR


direnv allow

nix flake update

direnv reload
