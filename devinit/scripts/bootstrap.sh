# bootstrap.sh
#!/usr/bin/env bash
set -euo pipefail


run_bootstrap() {
  echo "🔧 Bootstrapping project..."

  # (2) create or pick your new‐project dir:
  while true; do
    read -rp "Create a new name for project directory? (y/N): " yn </dev/tty
    case "$yn" in
      [Yy]*)
        read -rp "Name: " PROJECT_NAME </dev/tty
        [[ -z $PROJECT_NAME ]] && continue
        NEW_PROJECT_DIR="$PWD/$PROJECT_NAME"
        mkdir -p "$NEW_PROJECT_DIR"
        break
        ;;
      *)  # default = current dir
        PROJECT_NAME=$(basename "$PWD")
        NEW_PROJECT_DIR="$PWD/$PROJECT_NAME"
        mkdir -p "$NEW_PROJECT_DIR"
        break
        ;;
    esac
  done

  # (3) Ensure your scripts dir exists in the source tree
  mkdir -p "$PRE_PROJECT_DIR/scripts"

  # (4) Idempotently install the two launchers via install_template:
  install_template ".run"             "$REMOTE_BASE/templates/run-file.sh"
  install_template "scripts/_cli.sh"  "$REMOTE_BASE/templates/_cli-template.sh"

  # (5) And generate your envrc in the source tree:
  install_template ".envrc"           "$REMOTE_BASE/templates/envrc_template.sh"

  echo "Bootstrap done! → cd $NEW_PROJECT_DIR && direnv allow"
}


ensure_development_dir() {
  # Define where the flake should be located
  local dev_dir="$HELPER_ROOT"

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

  # Prevent infinite recursion
  if [[ -z "${IN_BOOTSTRAP_ENV:-}" ]]; then
    export IN_BOOTSTRAP_ENV=1
    # also export FETCH and HELPER_ROOT so the nested script “remembers”
    exec env \
      IN_BOOTSTRAP_ENV=1 \
      FETCH="$FETCH" \
      HELPER_ROOT="$HELPER_ROOT" \
      nix develop --no-write-lock-file "github:iansherr/nix-devflake?dir=devinit#bootstrap" \
      --command bash <<EOF
  $(curl -fsSL "https://raw.githubusercontent.com/iansherr/nix-devflake/dev/devinit/project-init.sh")
EOF
  fi

}


move_files() {
  # Move all files from the script directory to the project directory
  echo "Moving files from $PRE_PROJECT_DIR to $NEW_PROJECT_DIR..."
  find "$PRE_PROJECT_DIR" -mindepth 1 -maxdepth 1 \
    ! -path "*${PRE_PROJECT_DIR}/.git*" \
    ! -path "*${PRE_PROJECT_DIR}/.devenv*" \
    ! -path "*${PRE_PROJECT_DIR}/devinit*" \
    ! -path "*${PRE_PROJECT_DIR}/scripts*" \
    ! -name "project-init.sh" \
    ! -name ".envrc" \
    ! -name "flake.nix" \
    ! -name "README.md" \
    -exec mv {} "$NEW_PROJECT_DIR" \;
}


select_valid_environment() {
  VALID_ENVIRONMENTS=("sscript" "python" "web" "rust" "go" "java")

  while true; do
    echo "Available environments: ${VALID_ENVIRONMENTS[*]}"
    read -rp "Enter environment [sscript]: " ENVIRONMENT </dev/tty
    ENVIRONMENT=${ENVIRONMENT:-sscript}

  # Fix input corruption when running from a pipe
  ENVIRONMENT="$(echo "$ENVIRONMENT" | tr -d '\r' | xargs)"

  if [[ " ${VALID_ENVIRONMENTS[*]} " =~ " ${ENVIRONMENT} " ]]; then
    break
  else
    echo "Invalid choice: '$ENVIRONMENT'. Please select from: ${VALID_ENVIRONMENTS[*]}"
  fi
  done

}
