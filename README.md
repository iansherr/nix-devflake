# Nix DevFlake

## Overview
This [Nix flake](https://nixos.wiki/wiki/Flakes) provides reusable development environments and tools for setting up new projects. It can be used independently or integrated with the main system configuration flake.

## Features
- **Bootstrap Environment**:
  - Universal shell for initializing projects.
  - Includes essential tools like `git`, `pre-commit`, and programming language-specific utilities.
  - Detects whether Nix is installed, and whether flakes are activated.
- **Reusable Shells**:
  - Pre-configured environments for Python, Web, Rust, Go, and Java projects.
- **Project Initialization**:
  - Automates project directory creation and environment setup using `project-init.sh`.

## Usage

### Remote easy install (recommended)
Inside your project directory, run the following command:
```bash
curl -fsSL "https://raw.githubusercontent.com/iansherr/nix-devflake/main/devinit/project-init.sh" | bash
```

### Easy copy install
1. You can copy the init script and flake configuration to a new project directory using the following command:
Create a new directory in your home that's called nix-devflake.

```bash
mkdir ~/nix-devflake
```

2. Then copy the development directory to the nixdev directory.
```bash
git clone https://github.com/iansherr/nix-devflake ~/nix-devflake
```

3. Then create a new directory for your project and copy the development directory to the new project directory.
```bash
mkdir ~/projects/my-project/.devenv && cp -r ~/nix-devflake/ ~/projects/my-project/.devenv
```

4. Then navigate to the new project directory and run the initialization script.
```bash
cd ~/projects/my-project
```
```bash
chmod +x ./devenv/devinit/project-init.sh  ./.devenv/devinit/project-init.sh
```

5. Follow the prompts.



### Manual install
1. Make sure you are inside your project folder:
```bash
cd ~/projects/my-project
```

2. Check if the required files exist:
```bash
ls .devenv/devinit/flake.nix .devenv/devinit/project-init.sh
```
If both files exist, continue.
If they are missing, copy the development flake from your template directory:

3.  Now, enter the Nix bootstrap environment.
```bash
nix develop .#bootstrap
```
This prepares the shell for the project setup.

4. Create a project subdirectory. This keeps the flake and Nix weirdness out of your git repo.
```bash
mkdir my-project
```
So, you should now have a directory structure like this:

```bash
~/my-project/
├── .devenv/
│   ├── devinit/
│       ├── flake.nix
│       ├── project-init.sh
│       ├── README.md
├─ my-project
│  ├── Empty OR Whatever_Project_Files
```

5. Create the relevant flake for your project.
```bash
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
```
Add relevant extras for your project
```bash
cat <<EOF >>flake.nix
            # Python
            python3
            poetry
            black
            flake8
            mypy
            isort
            pylint
EOF
```
Finish the flake file.
```bash
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
```

6. Tell Nix to use the flake.
```bash
echo "use flake ." > .envrc
direnv allow
nix flake update
direnv reload
```

7. Move into the project directory.
```bash
cd my-project
```

8. Have fun.

## License
This project is licensed under the MIT License.
