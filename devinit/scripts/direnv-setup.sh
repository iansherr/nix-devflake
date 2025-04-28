#!/usr/bin/env bash
set -euo pipefail

# --- Direnv: Configure and reload ---

run_direnv_setup() {
  echo "🔄 Setting up Direnv..."

  if [[ -f ".envrc" ]]; then
    cd "$PRE_PROJECT_DIR" || exit 1

    direnv allow

    nix flake update

    direnv reload

    echo "✅ Direnv configured."
  else
    echo "⚠️ .envrc missing. Skipping direnv allow."
  fi
}

create_envrc() {
  # Create .envrc file
  if [[ ! -f "${PROJECT_DIR}/.envrc" ]]; then
    cat <<EOF >"${PROJECT_DIR}/.envrc"
# Strict mode
set -euo pipefail

# Use Nix Flake
use flake .

# github
#export GITHUB_ORGANIZATION=


export PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
export RELATIVE_PATH=$(git rev-parse --show-prefix   2>/dev/null)

find-parent() {
    local dir=..
    while [[ -d "$dir" ]] && [[ ! -d "$dir/.git" ]]; do
        dir="${dir}/.." ;
    done
    echo "$dir"
}

parent-envrc=$(find-parent)/.envrc
if [[ ! -f "$parent-envrc" ]]; then
    echo "no parent .envrc found"
    exit 1
fi

# shellcheck source=/dev/null
source "$parent-envrc"

# Load .run automatically if it exists
if [[ -f "$PWD/../.run" ]]; then
  source "$PWD/../.run"
fi

# Add scripts to PATH
if [[ -d "$PWD/../scripts" ]]; then
  PATH_add "$PWD/../scripts"
fi

# .env
#dotenv

EOF
  echo "Created .envrc"
else
  echo ".envrc already exists. Keeping the existing file."
fi

}
