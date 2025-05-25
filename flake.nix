{
  description = "Shared devflakes for multiple environments";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }: {
    devShells = let
      forEachSystem = f: {
        x86_64-linux = f "x86_64-linux";
        x86_64-darwin = f "x86_64-darwin";
        aarch64-linux = f "aarch64-linux";
        aarch64-darwin = f "aarch64-darwin";
        riscv64-linux = f "riscv64-linux";
      };
    in forEachSystem (system: let
        pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };
        common = [
          pkgs.git pkgs.pre-commit pkgs.cmake pkgs.curl pkgs.zoxide pkgs.ncurses
          pkgs.neovim pkgs.unzip pkgs.fd pkgs.lazygit pkgs.jq pkgs.ripgrep
          pkgs.tree-sitter pkgs.xclip pkgs.bashmount
        ];
        extrasMap = rec {
          bootstrap = [ pkgs.bash pkgs.git pkgs.pre-commit pkgs.python310 pkgs.poetry pkgs.nodejs pkgs.yarn pkgs.rustc pkgs.go pkgs.openjdk pkgs.maven ];
          default   = [ pkgs.git pkgs.docker pkgs.pre-commit ];
          sscript   = [ pkgs.nano pkgs.lua pkgs.luajit pkgs.yarn ];
          python    = [ pkgs.python310 pkgs.poetry pkgs.black pkgs.isort pkgs.python312Packages.pytest ];
          web       = [ pkgs.nodejs_23 pkgs.yarn pkgs.prettierd pkgs.nodePackages.prettier pkgs.jdk23 pkgs.python312Packages.pip pkgs.pipx pkgs.python312Packages.pytest pkgs.uv ];
          rust      = [ pkgs.rustc pkgs.cargo pkgs.rust-analyzer pkgs.clippy ];
          go        = [ pkgs.go pkgs.delve pkgs.gopls pkgs.golangci-lint ];
          java      = [ pkgs.maven pkgs.gradle pkgs.eclipse ];
          ai        = [ pkgs.python310 pkgs.uv pkgs.aider-chat pkgs.ollama ];
        };
        mkEnv = env: pkgs.mkShell {
          name = "${env}-${system}";
          buildInputs = common ++ extrasMap.${env};
          shellHook = ''
          echo "Loaded ${system}:${env} devShell"
          if [ -f .pre-commit-config.yaml ]; then pre-commit install || true; fi
          '';
        };
        mkEnvAi = env: pkgs.mkShell {
          name = "${env}-ai-${system}";
          buildInputs = common ++ extrasMap.${env} ++ extrasMap.ai;
          shellHook = ''
          echo "Loaded ${system}:${env}-ai devShell"
          if [ -f .pre-commit-config.yaml ]; then pre-commit install || true; fi
          '';
        };
      in {
        bootstrap   = mkEnv "bootstrap";
        default     = mkEnv "default";
        sscript     = mkEnv "sscript";
        python      = mkEnv "python";
        web         = mkEnv "web";
        rust        = mkEnv "rust";
        go          = mkEnv "go";
        java        = mkEnv "java";
        "sscript-ai" = mkEnvAi "sscript";
        "python-ai"  = mkEnvAi "python";
        "web-ai"     = mkEnvAi "web";
        "rust-ai"    = mkEnvAi "rust";
        "go-ai"      = mkEnvAi "go";
        "java-ai"    = mkEnvAi "java";
      });
  };
}
