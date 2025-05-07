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
# Usage: ./project-init.sh [project-name] [environment]
# Example: ./project-init.sh my-project python
#
# DIRECTORY LOCATIONS
# - script_dir: Directory where the script is located
# - pre_project_dir: Parent directory of the script (eg OTHERFILES/pre_project_dir)
# - project_dir: Directory where the project will be created (eg OTHERFILES/pre_project_dir/project-dir)
# - development_dir: Directory where the flake should be located (eg OTHERFILES/pre_project_dir/.devenv/devinit)
# - project_name: Name of the project (eg my-project)
#
# This script is part of the Nix Devflake project:
# github.com/iansherr/nix-devflake
#

# Enable strict mode
set -euo pipefail
shopt -s globstar extglob

PRE_PROJECT_DIR=$PWD
GITHUB_URL=https://github.com/iansherr/nix-devflake.git
REMOTE_BASE=https://raw.githubusercontent.com/iansherr/nix-devflake/main/dev/devinit


check_helpers_update() {
  # only if we copied a git checkout locally
  if [[ "${FETCH:-}" == "local-copy" ]] && [[ -d "$HELPER_ROOT/.git" ]]; then
    echo "Checking for devinit updates…"
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
    local-copy|remote-copy)
      mkdir -p "${dest%/*}"
      if [[ "$FETCH" == "remote-copy" && ! -f "$dest" ]]; then
        curl -fsSL "$url" -o "$dest" && chmod +x "$dest"
      fi
      ;;
    local-stream)  sed -n '1,$p' "$LOCAL_ROOT/$rel" ;;
    remote-stream) curl -fsSL "$url" ;;
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

install_template() {
  local rel
  local url
  local dest
  relpath=$1
  url=$2
  dest="$PRE_PROJECT_DIR/$relpath"
  if [[ ! -e "$dest" ]]; then
    mkdir -p "${dest%/*}"
    case "$FETCH" in
      local-copy|remote-copy)
        fetch_helper "templates/$relpath" "$url"
        mv "$HELPER_ROOT/templates/$relpath" "$dest"
        ;;
      local-stream|remote-stream)
        fetch_helper "templates/$relpath" "$url" >"$dest"
        # only make executable if it's a script
        [[ "$relpath" =~ \.sh$ ]] && chmod +x "$dest"
        ;;
    esac
    echo "Installed template: $relpath"
  fi
}


find_local_devinit() {
  local d start cand
  start="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for d in "$start" $(while [[ $start != / ]]; do start=$(dirname $start); echo $start; done); do
    for cand in devinit .devinit .devenv/devinit; do
      [[ -d "$d/$cand/scripts" ]] && { echo "$d/$cand"; return; }
    done
  done
}
LOCAL_ROOT=$(find_local_devinit||true)


#  If already in “bootstrap” shell, skip the menu.
#  (and assume we just cloned into .devenv/devinit)
if [[ -z "${FETCH:-}" ]]; then
  if [[ -n $LOCAL_ROOT ]]; then
    echo "Found local devinit at: $LOCAL_ROOT"
    PS3="Load helpers via: "
    select _ in \
      "Copy local → ./.devenv/devinit" \
      "Stream local" \
      "Clone GitHub → ./.devenv/devinit" \
      "Stream GitHub" \
      "Abort"; do
      case $REPLY in
        1) mkdir -p .devenv/devinit && cp -r "$LOCAL_ROOT/"{scripts,templates,project-init.sh,flake.nix} .devenv/devinit/ \
           && FETCH=local-copy && HELPER_ROOT=.devenv/devinit ;;
        2) FETCH=local-stream; HELPER_ROOT="$LOCAL_ROOT" ;;
        3) mkdir -p .devenv/devinit \
           && git clone --depth=1 --filter=blob:none "$GITHUB_URL" .devenv/devinit \
           && (cd .devenv/devinit && git sparse-checkout init --cone \
               && git sparse-checkout set dev/devinit/{scripts,templates,project-init.sh,flake.nix} \
               && mv dev/devinit/* . && rm -rf dev) \
           && FETCH=remote-copy && HELPER_ROOT=.devenv/devinit ;;
        4) FETCH=remote-stream; HELPER_ROOT="." ;;
        *) echo "Aborting."; exit 1 ;;
      esac
      break
    done
  else
    echo "No local devinit – choose GitHub:"
    PS3="Fetch helpers via: "
    select _ in "Clone GitHub → ./.devenv/devinit" "Stream GitHub" "Abort"; do
      case $REPLY in
        1) mkdir -p .devenv/devinit \
           && git clone --depth=1 --filter=blob:none "$GITHUB_URL" .devenv/devinit \
           && (cd .devenv/devinit && git sparse-checkout init --cone \
               && git sparse-checkout set dev/devinit/{scripts,templates,project-init.sh,flake.nix} \
               && mv dev/devinit/* . && rm -rf dev) \
           && FETCH=remote-copy && HELPER_ROOT=.devenv/devinit ;;
        2) FETCH=remote-stream; HELPER_ROOT="." ;;
        *) echo "Aborting."; exit 1 ;;
      esac
      break
    done
  fi

  export FETCH HELPER_ROOT
  check_helpers_update
fi





load_helper scripts/bootstrap.sh    "$REMOTE_BASE/scripts/bootstrap.sh"
load_helper scripts/flakegen.sh     "$REMOTE_BASE/scripts/flakegen.sh"
load_helper scripts/git-setup.sh    "$REMOTE_BASE/scripts/git-setup.sh"
load_helper scripts/direnv-setup.sh "$REMOTE_BASE/scripts/direnv-setup.sh"


run_bootstrap
ensure_development_dir
move_files

install_template ".run"   "$REMOTE_BASE/templates/run-file.sh"
install_template "scripts/_cli.sh" \
                       "$REMOTE_BASE/templates/_cli-template.sh"
install_template ".envrc" "$REMOTE_BASE/templates/envrc_template.sh"

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
#echo "Project Directory: $PRE_PROJECT_DIR"
#echo "Expected Flake Location: $PRE_PROJECT_DIR/$DEVELOPMENT_DIR/flake.nix"
