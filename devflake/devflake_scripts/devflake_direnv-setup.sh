#!/usr/bin/env bash
# direnv-setup
set -eo pipefail

# --- Direnv: Configure and reload ---

run_envrc_setup() {
  echo "🔄 Setting up Direnv..."

  if [[ -f "$PROJECT_DIR/.envrc" ]]; then

    cd "$PROJECT_DIR" || exit 1

    direnv allow

    cd "$PROJECT_DIR" || exit 1

    direnv allow

    nix flake update

    direnv reload

    echo "Direnv configured."
  else
    echo ".envrc missing. Skipping direnv allow."
  fi
}

create_envrc() {
  # Create .envrc file
  if [[ ! -f "$PROJECT_DIR/.envrc" ]]; then
    cd $PROJECT_DIR || exit 1
    cat <<'EOF' >".envrc"
# Strict mode
set -euo pipefail

# Use Nix Flake
use flake .

# github
#export GITHUB_ORGANIZATION=

# Only “use flake .” at the top of the repo (RELATIVE_PATH is empty at flake root)
if [[ -z "${RELATIVE_PATH:-}" ]]; then
  use flake .
fi

# Git root detection
export PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
export RELATIVE_PATH=$(git rev-parse --show-prefix   2>/dev/null || true)

# If we’re not at the git root, try to find a .envrc up to 10 dirs up
if [[ -n "$PROJECT_ROOT" && "$PWD" != "$PROJECT_ROOT" ]]; then
  :
else
  find-parent-envrc() {
    local dir="." depth=0 max=10
    while (( depth < max )); do
      if [[ -f "$dir/.envrc" ]]; then
        cd "$dir" && pwd
        return 0
      fi
      dir="$dir/.."
      ((depth++))
    done
    return 1
  }

  if parent=$(find-parent-envrc); then
    # avoid re-sourcing your own .envrc
    if [[ "$parent" != "$PWD" ]]; then
      # shellcheck source=/dev/null
      source "$parent/.envrc"
    fi
  fi
fi

# dotenv support
# dotenv
EOF
  echo "Created .envrc"
else
  echo ".envrc already exists. Keeping the existing file."
fi

}
