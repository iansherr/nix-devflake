#!/usr/bin/env bash
set -euo pipefail

# --- Bootstrap: Create essential files (.run, scripts/, _cli.sh, .envrc, .gitignore) ---

run_bootstrap() {
  echo "🔧 Bootstrapping project..."


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


  # Ensure development environment is prepared
  if [[ -z "${IN_BOOTSTRAP_ENV:-}" ]]; then
    ensure_development_dir
  fi

  # Ask whether to create a new project directory
  while true; do
    read -rp "Do you want to create a new project directory? (y/N): " CREATE_NEW </dev/tty
    case "$CREATE_NEW" in
    [Yy]*)
      read -rp "Enter new project name: " PROJECT_NAME
      [[ -z "$PROJECT_NAME" ]] && {
        echo "Project name cannot be empty."
        continue
      }
      PROJECT_DIR="${PWD}/${PROJECT_NAME}"
      mkdir -p "$PROJECT_DIR"
      break
      ;;
    [Nn]* | "")
      PROJECT_NAME=$(basename "$PWD")
      mkdir -p "$PROJECT_NAME"
      PROJECT_DIR="$PWD/$PROJECT_NAME"
      break
      ;;
    *)
      echo "Invalid input. Please enter 'y' or 'n'."
      ;;
    esac
  done


  local dev_root="$PWD"

  # Create .run if missing
  if [[ ! -f "$PRE_PROJECT_DIR/.run" ]]; then
    echo "Creating .run..."
    curl -fsSL "https://raw.githubusercontent.com/iansherr/nix-devflake/main/devinit/templates/run-file.sh" -o "$PRE_PROJECT_DIR/.run"
    chmod +x "$PRE_PROJECT_DIR/.run"
  fi

  # Create scripts/ folder if missing
  if [[ ! -d "$PRE_PROJECT_DIR/scripts" ]]; then
    echo "Creating scripts/..."
    mkdir "$PRE_PROJECT_DIR/scripts"
  fi

  # Create _cli.sh if missing
  if [[ ! -f "$PRE_PROJECT_DIR/scripts/_cli.sh" ]]; then
    echo "Creating _cli.sh..."
    curl -fsSL "https://raw.githubusercontent.com/iansherr/nix-devflake/main/devinit/templates/_cli-template.sh" -o "$PRE_PROJECT_DIR/scripts/_cli.sh"
    chmod +x "$PRE_PROJECT_DIR/scripts/_cli.sh"
  fi

  # Create .envrc if missing
  if [[ ! -f "$PRE_PROJECT_DIR/.envrc" ]]; then
    echo "Creating .envrc..."
    create_envrc

  echo "Bootstrap complete! Run 'direnv allow' if needed."
  fi
}




ensure_development_dir() {
  # Define where the flake should be located
  local dev_dir="${PRE_PROJECT_DIR}/${DEVELOPMENT_DIR}"

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
    exec env IN_BOOTSTRAP_ENV=1 nix develop --no-write-lock-file "github:iansherr/nix-devflake?dir=devinit#bootstrap" --command bash <<EOF
$(curl -fsSL "https://raw.githubusercontent.com/iansherr/nix-devflake/main/devinit/project-init.sh")
EOF
  fi

  # Ensure .devenv directory exists
  mkdir -p "$dev_dir"

  # Ensure flake.nix exists or prompt the user
  if [[ ! -f "${dev_dir}/flake.nix" ]]; then
    echo "Error: flake.nix not found at ${dev_dir}/flake.nix"
    echo "Would you like to:"
    echo "1) Use the remote flake dynamically (without cloning)"
    echo "2) Clone the default flake from GitHub (iansherr/nix-devflake/devinit)"
    echo "3) Specify an existing directory containing the flake"
    echo "4) Exit"

    read -rp "Choose an option [1/2/3/4]: " choice

    case "$choice" in
    1)
      echo "Using remote flake dynamically..."
      REMOTE_FLAKE="github:iansherr/nix-devflake?dir=devinit"
      exec nix develop --no-write-lock-file "${REMOTE_FLAKE}#bootstrap" --command bash "$0" "$@"
      ;;
    2)
      echo "Cloning flake from GitHub..."
      git clone --depth=1 https://github.com/iansherr/nix-devflake "${dev_dir}"
      ;;
    3)
      read -rp "Enter the path to an existing flake directory: " CUSTOM_FLAKE_DIR
      if [[ -d "$CUSTOM_FLAKE_DIR" && -f "$CUSTOM_FLAKE_DIR/flake.nix" ]]; then
        dev_dir="$CUSTOM_FLAKE_DIR"
      else
        echo "Invalid directory. Exiting."
        exit 1
      fi
      ;;
    4)
      echo "Exiting."
      exit 1
      ;;
    *)
      echo "Invalid choice. Exiting."
      exit 1
      ;;
    esac
  fi

  # Enter the local development environment
  if [[ -z "${IN_BOOTSTRAP_ENV:-}" ]]; then
    export IN_BOOTSTRAP_ENV=1
    # Enter the local development environment
    exec nix develop "${dev_dir}" --command bash -c
  fi

}


move_files() {
  # Move all files from the script directory to the project directory
  echo "Moving files from $SCRIPT_DIR to $PROJECT_DIR..."
  find "$SCRIPT_DIR" -mindepth 1 -maxdepth 1 \
    ! -path "*${SCRIPT_DIR}/.git*" \
    ! -path "*${SCRIPT_DIR}/.devenv*" \
    ! -path "*${SCRIPT_DIR}/devinit*" \
    ! -name "project-init.sh" \
    ! -name "flake.nix" \
    ! -name "README.md" \
    -exec mv {} "$PROJECT_DIR" \;
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
