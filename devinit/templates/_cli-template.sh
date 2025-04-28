#!/usr/bin/env bash
set -eo pipefail

show-help() {
  items=()
  while IFS='' read -r line; do
    items+=("$line")
  done < <(compgen -A function | grep "^run-" | sed "s/^run-//")

  printf -v items "\t%s\n" "${items[@]}"

  usage="USAGE: .run CMD [ARGUMENTS]\n\nCommands:\n${items}"
  echo -e "$usage"
}

# 🏗️ Run Bootstrap: create base files
run-bootstrap() {
  echo "🔧 Bootstrapping project..."

  local dev_root="$PWD"

  # Create .run if missing
  if [[ ! -f "$dev_root/.run" ]]; then
    echo "Creating .run..."
    curl -fsSL "https://raw.githubusercontent.com/iansherr/nix-devflake/main/devinit/templates/run-file.sh" -o "$dev_root/.run"
    chmod +x "$dev_root/.run"
  fi

  # Create scripts/ folder if missing
  if [[ ! -d "$dev_root/scripts" ]]; then
    echo "Creating scripts/..."
    mkdir "$dev_root/scripts"
  fi

  # Create _cli.sh if missing
  if [[ ! -f "$dev_root/scripts/_cli.sh" ]]; then
    echo "Creating _cli.sh..."
    curl -fsSL "https://raw.githubusercontent.com/iansherr/nix-devflake/main/devinit/templates/_cli-template.sh" -o "$dev_root/scripts/_cli.sh"
    chmod +x "$dev_root/scripts/_cli.sh"
  fi

}

# 🩺 Run Doctor: check system
run-doctor() {
  echo "🩺 Running system checks..."

  local errors=0

  if [[ ! -f "$PWD/.run" ]]; then
    echo "❌ Missing .run"
    errors=$((errors + 1))
  fi

  if [[ ! -f "$PWD/scripts/_cli.sh" ]]; then
    echo "❌ Missing scripts/_cli.sh"
    errors=$((errors + 1))
  fi

  if [[ ! -f "$PWD/.envrc" ]]; then
    echo "❌ Missing .envrc"
    errors=$((errors + 1))
  fi

  if [[ "$errors" -eq 0 ]]; then
    echo "✅ All checks passed!"
  else
    echo "⚠️ $errors problems found. Run '.run bootstrap' to fix."
    return 1
  fi
}

# 🚀 Run Upgrade: refresh templates
run-upgrade() {
  echo "🚀 Upgrading .run system..."

  curl -fsSL "https://raw.githubusercontent.com/iansherr/nix-devflake/main/devinit/templates/run-file.sh" -o "$PWD/.run"
  curl -fsSL "https://raw.githubusercontent.com/iansherr/nix-devflake/main/devinit/templates/_cli-template.sh" -o "$PWD/scripts/_cli.sh"

  chmod +x "$PWD/.run"
  chmod +x "$PWD/scripts/_cli.sh"

  echo "✅ Upgrade complete!"
}
