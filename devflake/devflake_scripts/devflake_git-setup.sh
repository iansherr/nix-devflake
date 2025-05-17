#!/usr/bin/env bash
# git-setup.sh
set -euo pipefail

# --- Git setup: Initialize repo, set origin ---

pre_commit_setup() {
 # Add a pre-commit configuration
  if [[ ! -f "$PROJECT_DIR/.pre-commit-config.yaml" ]]; then
    cd $PROJECT_DIR || exit 1
    cat <<EOF >".pre-commit-config.yaml"
  repos:
    - repo: https://github.com/pre-commit/pre-commit-hooks
      rev: v4.3.0
      hooks:
        - id: trailing-whitespace
        - id: end-of-file-fixer
        - id: check-added-large-files
EOF

    # Add language-specific pre-commit hooks
    if [ "$ENVIRONMENT" = "python" ]; then
      cat <<EOF >>"$PROJECT_DIR/.pre-commit-config.yaml"
    - repo: https://github.com/psf/black
      rev: 23.1.0
      hooks:
        - id: black
    - repo: https://github.com/PyCQA/flake8
      rev: 6.0.0
      hooks:
        - id: flake8
EOF
    fi
    echo "Created .pre-commit-config.yaml"
  else
    echo ".pre-commit-config.yaml already exists. Keeping the existing file."
  fi
}

run_git_setup() {
  # Ensure Git is initialized
  if [[ ! -d "$PROJECT_DIR/.git" ]]; then
    echo "Initializing Git repository..."
    cd $PROJECT_DIR || exit 1
  else
    echo "Git repository already initialized."
  fi

  git init
  git symbolic-ref HEAD refs/heads/main # Ensure main branch exists
  git add .

  # Handle Git Origin Prompt
  CURRENT_ORIGIN=$(git remote get-url origin 2>/dev/null || echo "")

  if [[ -z "$CURRENT_ORIGIN" ]]; then
    while true; do
      read -rp "Do you want to add a git origin repo? (y/N): " ADD_ORIGIN </dev/tty
      ADD_ORIGIN="$(echo "$ADD_ORIGIN" | tr -d '\r' | xargs)" # Sanitize input

      case "$ADD_ORIGIN" in
      [Yy]*)
        MAX_RETRIES=3
        for ((i = 1; i <= MAX_RETRIES; i++)); do
          read -rp "Enter git origin repo URL (or press Enter to skip): " GIT_ORIGIN
          GIT_ORIGIN="$(echo "$GIT_ORIGIN" | tr -d '\r' | xargs)"

          if [[ -z "$GIT_ORIGIN" ]]; then
            echo "Skipping Git remote setup."
            break
          fi

          if [[ "$GIT_ORIGIN" =~ ^(https|git):// ]]; then
            git remote add origin "$GIT_ORIGIN"
            echo "Git remote added: $GIT_ORIGIN"
            break
          else
            echo "Invalid URL format. Please enter a valid Git repository URL."
            if [[ $i -eq MAX_RETRIES ]]; then
              echo "Max retries reached. Skipping Git remote setup."
            fi
          fi
        done
        break
        ;;
      [Nn]* | "")
        echo "Skipping Git remote setup."
        break
        ;;
      *)
        echo "Invalid input. Please enter 'y' or 'n'."
        ;;
      esac
    done
  else
    echo "Git remote already exists: $CURRENT_ORIGIN"
    read -rp "Do you want to change it? (y/N): " CHANGE_ORIGIN
    if [[ "$CHANGE_ORIGIN" =~ ^[Yy]$ ]]; then
      read -rp "Enter new git origin URL: " NEW_GIT_ORIGIN
      git remote set-url origin "$NEW_GIT_ORIGIN"
      echo "Git remote updated: $NEW_GIT_ORIGIN"
    fi
  fi

  pre-commit install --install-hooks
  echo "Pre-commit hooks installed."


}

create_git_ignore() {
  if [[ ! -f "$PROJECT_DIR/.gitignore" ]]; then
  cd $PROJECT_DIR || exit 1
  cat <<EOF >.gitignore
# Editor and OS-specific files
.vscode/
.devflake/
*.DS_Store
Thumbs.db
*.vimrc
*.vim/
*.tmp
*.swp


# Python
__pycache__/
*.pyc
*.pyo
*.pyd
*.pytest_cache/
.mypy_cache/

# Node.js
node_modules/
npm-debug.log*
yarn-error.log*

# Rust
target/
Cargo.lock

# Go
bin/
pkg/
*.test

# Java
*.class
*.jar
*.war
*.ear
*.iml
.gradle/
target/

# Nix
.result
*.drv
result
result-*


# Pre-commit hooks & package manager cache
.pre-commit-config.yaml
.pre-commit-hooks.yaml
.pre-commit-hooks/
.pip-cache/

# Virtual Environments
.env
.venv/
env/
venv/

# Direnv & Shell Environment
.devenv/
.direnv/
.envrc

# Logs & Temporary Files
*.log
*.swp
*.swo
*.swn
*.tmp
*.bak

# Archives, Compressed and Executable Files
*.tgz
*.zip
*.rar
*.tar
*.gz
*.7z
*.exe
EOF
  echo ".gitignore has been created."
else
  echo ".gitignore already exists. Keeping the existing file."
fi




}



create_readme() {
  if [[ ! -f "$PROJECT_DIR/README.md" ]]; then
    cd $PROJECT_DIR || exit 1
    cat <<EOF >README.md
# ${PROJECT_NAME}
This is the README file for ${PROJECT_NAME}.
## Project Overview
This project is a ${ENVIRONMENT} development environment.
## Getting Started
To get started with this project, follow these steps:
1. Install the required dependencies.
2. Set up your environment.
3. Run the project.
4. Contribute to the project.
EOF
    echo "README.md has been created."
  else
    echo "README.md already exists. Keeping the existing file."
  fi
}
