# bootstrap.sh
#!/usr/bin/env bash
set -euo pipefail


run_bootstrap() {
  echo "🔧 Bootstrapping project..."

  PROJECT_NAME=$(basename "$PWD")

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

  echo "Bootstrap done!"
}


ensure_development_dir() {
  # where our local flake lives if we copied it
  local local_flake="$HELPER_ROOT"
  # the canonical “remote” flake
  local remote_flake="github:iansherr/nix-devflake?dir=devflake"
  local remote_bootstrap="github:iansherr/nix-devflake?dir=devflake#bootstrap"


  # Prevent infinite recursion
  if [[ -n "${IN_BOOTSTRAP_ENV:-}" ]]; then
    return
  fi

  export IN_BOOTSTRAP_ENV=1

  case "$FETCH" in
    local-copy|remote-copy)
      echo "▶ Entering local devflake at $local_flake"
      exec nix develop "$local_flake" --command bash "$0" "$@"
      ;;

    local-stream)
      echo "▶ Using local-stream mode; continuing in this shell"
      # nothing more to do—your scripts have already been loaded via fetch_helper
      ;;

    remote-stream)
      echo "▶ Streaming bootstrap from devinit ($remote_bootstrap)…"

    *)
      echo "⚠ Unknown FETCH mode: $FETCH"
      exit 1
      ;;
  esac
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
