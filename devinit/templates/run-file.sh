#!/usr/bin/env bash
set -eo pipefail


#!/usr/bin/env bash
set -euo pipefail

# --- Find dev root (location of .run) ---
DEV_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Source the CLI functions ---
source "${DEV_ROOT}/scripts/_cli.sh"

# --- Setup tab completion ---
_run_completion() {
  local curr_word="${COMP_WORDS[COMP_CWORD]}"
  COMPREPLY=($(compgen -W "$(compgen -A function | grep '^run-' | sed 's/^run-//')" -- "$curr_word"))
}

function __run_complete
    set -l cmds (string replace 'run-' '' (functions -n | grep '^run-'))
    for cmd in $cmds
        echo $cmd
    end
end

complete -c .run -a '(__run_complete)'

if [[ $(basename -- "$0") == ".run" ]]; then
  if declare -F _run_completion >/dev/null 2>&1; then
    complete -F _run_completion .run
  fi
fi

# --- CLI Entrypoint ---
if [[ $# -eq 0 ]]; then
  show-help
  exit 0
fi

name=$1
shift
if compgen -A function | grep -q "^run-${name}$"; then
  "run-${name}" "$@"
else
  echo "ERROR: run-${name} not found."
  exit 123
fi

# Load config
if [[ -f "${DEV_ROOT}/scripts/.runconfig" ]]; then
  source "${DEV_ROOT}/scripts/.runconfig"
fi

# Optional: Load .env if available
if [[ -f "${DEV_ROOT}/scripts/.env" ]]; then
  export $(grep -v '^#' "${DEV_ROOT}/scripts/.env" | xargs)
fi


EOF
  echo "Created .run"
else
  echo ".run already exists. Keeping the existing file."
fi
