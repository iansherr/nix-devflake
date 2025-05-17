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
# Usage: ./devflake.sh [project-name] [environment]
# Example: ./devflake.sh my-project python
#
# DIRECTORY LOCATIONS
# - script_dir: Directory where the script is located
# - project_dir: Directory where the project will be created (eg OTHERFILES/project_dir/)
# - development_dir: Directory where the flake should be located (eg OTHERFILES/project_dir/.devflake/devflake)
# - project_name: Name of the project (eg my-project)
#
# This script is part of the Nix Devflake project:
# github.com/iansherr/nix-devflake
#

# Enable strict mode
set -euo pipefail
shopt -s globstar extglob

PROJECT_DIR=$PWD
GITHUB_URL=https://github.com/iansherr/nix-devflake.git
REMOTE_BASE=https://raw.githubusercontent.com/iansherr/nix-devflake/dev/devflake


check_helpers_update() {
  # only if we copied a git checkout locally
  if [[ "${FETCH:-}" == "local-copy" ]] && [[ -d "$HELPER_ROOT/.git" ]]; then
    echo "Checking for devflake updates…"
    git -C "$HELPER_ROOT" fetch --quiet
    local LOCAL=$(git -C "$HELPER_ROOT" rev-parse @)
    local REMOTE=$(git -C "$HELPER_ROOT" rev-parse @{u} 2>/dev/null || echo "$LOCAL")
    if [[ $LOCAL != $REMOTE ]]; then
      read -rp "Helpers out-of-date. Pull origin/main? [Y/n] " yn </dev/tty
      yn=${yn:-Y}
      if [[ $yn =~ ^[Yy] ]]; then
        git -C "$HELPER_ROOT" pull --ff-only
        echo "Helpers updated to $(git -C "$HELPER_ROOT" rev-parse --short HEAD)"
      fi
    fi
  fi
}

fetch_helper() {
  local rel
  local url
  local dest
  rel=$1
  url=$2
  dest="$HELPER_ROOT/$rel"
  case "$FETCH" in
    local-copy)
      mkdir -p "${dest%/*}"
      cp -r "$LOCAL_ROOT/$rel" "$dest"
      chmod +x "$dest" 2>/dev/null || :
      ;;
    remote-copy)
      mkdir -p "$(dirname "$dest")"
      curl -fsSL "$url" -o "$dest"
      chmod +x "$dest"
      ;;
    local-stream)
      sed -n '1,$p' "$LOCAL_ROOT/$rel"
      ;;
    remote-stream)
      curl -fsSL "$url"
      ;;
  esac
}

load_helper() {
  local rel
  local url
  rel=$1
  url=$2
  case "$FETCH" in
    local-copy|remote-copy)
      fetch_helper "$rel" "$url"
      source "$HELPER_ROOT/$rel"
      ;;
    local-stream|remote-stream)
      eval "$(fetch_helper "$rel" "$url")"
      ;;
  esac
}




find_local_devflake() {
  local d start cand
  start="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for d in "$start" $(while [[ $start != / ]]; do start=$(dirname $start); echo $start; done); do
    for cand in devflake .devflake .devenv/devflake; do
      [[ -d "$d/$cand/devflake_scripts" ]] && { echo "$d/$cand"; return; }
    done
  done
}
LOCAL_ROOT=$(find_local_devflake||true)


#  If already in “bootstrap” shell, skip the menu.
#  (and assume we just cloned into .devenv/devflake)
if [[ -z "${FETCH:-}" ]]; then
  if [[ -n $LOCAL_ROOT ]]; then
    echo "Found local devflake at: $LOCAL_ROOT"
    PS3="Load helpers via: "
    select _ in \
      "Copy local → ./.devenv/devflake" \
      "Stream local" \
      "Clone GitHub → ./.devenv/devflake" \
      "Stream GitHub" \
      "Abort"; do
      case $REPLY in
        1)
          # nuke any old leftovers, then mirror your entire local devflake checkout
          rm -rf .devenv/devflake
          mkdir -p .devenv/devflake
          # copy the *contents* of your local checkout into HELPER_ROOT
          cp -r "$LOCAL_ROOT/"* .devenv/devflake
          FETCH=local-copy
          HELPER_ROOT=".devenv/devflake/"
          break
          ;;
        2)
          FETCH=local-stream
          HELPER_ROOT="$LOCAL_ROOT"
          break
          ;;
        3)
          mkdir -p .devenv/devflake \
          && git clone --depth=1 --filter=blob:none "$GITHUB_URL" .devenv/devflake \
          && (cd .devenv/devflake && git sparse-checkout init --cone \
              && git sparse-checkout set dev/devflake/{devflake_scripts,devflake-init.sh,flake.nix} \
              && mv dev/devflake/* . && rm -rf dev) \
          && { FETCH=remote-copy; HELPER_ROOT=.devenv/devflake/; break; } ;;
        4)
          FETCH=remote-stream
          HELPER_ROOT="."
          break
          ;;
        *)
          echo "Aborting."
          exit 1
          ;;
      esac
      break
    done

    if [[ -z "${FETCH:-}" ]]; then
      echo "No fetch method selected; aborting."
      exit 1
    fi

  else
    echo "No local devflake – choose GitHub:"
    PS3="Fetch helpers via: "
    select _ in "Clone GitHub → ./.devenv/devflake" "Stream GitHub" "Abort"; do
      case $REPLY in
        1) mkdir -p .devenv/devflake \
           && git clone --depth=1 --filter=blob:none "$GITHUB_URL" .devenv/devflake \
           && (cd .devenv/devflake && git sparse-checkout init --cone \
               && git sparse-checkout set dev/devflake/{devflake_scripts,devflake-init.sh,flake.nix} \
               && mv dev/devflake/* . && rm -rf dev) \
           && FETCH=remote-copy && HELPER_ROOT=.devenv/devflake/ ;;
        2) FETCH=remote-stream; HELPER_ROOT="." ;;
        *) echo "Aborting."; exit 1 ;;
      esac
      break
    done
  fi

  export FETCH HELPER_ROOT
  check_helpers_update
fi





load_helper devflake_scripts/devflake_bootstrap.sh    "$REMOTE_BASE/devflake_scripts/devflake_bootstrap.sh"
load_helper devflake_scripts/devflake_flakegen.sh     "$REMOTE_BASE/devflake_scripts/devflake_flakegen.sh"
load_helper devflake_scripts/devflake_git-setup.sh    "$REMOTE_BASE/devflake_scripts/devflake_git-setup.sh"
load_helper devflake_scripts/devflake_direnv-setup.sh "$REMOTE_BASE/devflake_scripts/devflake_direnv-setup.sh"


run_bootstrap
ensure_development_dir

# Create devflake
select_valid_environment
run_flakegen


# Git Setup
pre_commit_setup
create_git_ignore
run_git_setup
create_readme

# Make it all work
create_envrc
run_envrc_setup

echo "Project initialized successfully!"


# Debugging Output:
#echo "Script Directory: $SCRIPT_DIR"
#echo "Project Directory: $PROJECT_DIR"
#echo "Expected Flake Location: $PROJECT_DIR/$DEVELOPMENT_DIR/flake.nix"
