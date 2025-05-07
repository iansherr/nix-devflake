# Strict mode
set -euo pipefail

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

# Now load your local .run and scripts if present
if [[ -f "${PROJECT_ROOT:-.}/.run" ]]; then
  source "${PROJECT_ROOT:-.}/.run"
elif [[ -f "./.devenv/devinit/.run" ]]; then
  source "./.devenv/devinit/.run"
elif [[ -f "./devinit/.run" ]]; then
  source "./devinit/.run"
fi

# Add any scripts/ to PATH
if [[ -d "${PROJECT_ROOT:-.}/scripts" ]]; then
  PATH_add "${PROJECT_ROOT:-.}/scripts"
elif [[ -d "./.devenv/devinit/scripts" ]]; then
  PATH_add "./.devenv/devinit/scripts"
elif [[ -d "./devinit/scripts" ]]; then
  PATH_add "./devinit/scripts"
fi


# dotenv support
# dotenv
