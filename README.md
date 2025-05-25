# Nix DevFlake

A single, centrally managed Nix flake that provides reusable development shells for your projects—no per-project flake clutter, fully offline capable, and optional AI tooling.

## Features

- **One global devflake** cloned to `~/.local/share/nix-devflake` (or in-repo) on any branch (`main`, `dev`, etc.).
- **Per-project bootstrap script** (`devflake-init.sh`) that:
  - Clones or updates your central devflake
  - (Optionally) creates a project-local copy
  - Registers a `path://` reference for easy usage
  - Prompts for your primary environment (Python, Web, Rust, Go, Java, S-script)
  - Offers optional AI tooling shell
  - Generates a minimal `.envrc` for direnv
- **Reusable devShells** defined in `flake.nix`:
  - `bootstrap`, `default`, `sscript`, `python`, `web`, `rust`, `go`, `java`
  - AI-augmented variants: `sscript-ai`, `python-ai`, etc.
- **Offline-first**: once cloned, all shells work without network.
- **Branchable**: test features on a `dev` branch before merging to `main`.

---

## Getting Started

### 1. Bootstrapping a project

Inside your project folder, run:

```bash
curl -fsSL https://raw.githubusercontent.com/iansherr/nix-devflake/main/devflake-init.sh | bash
```

Or, if you’ve checked out the repo locally:

```bash
bash /path/to/nix-devflake/devflake-init.sh [options]
```

#### CLI options

- `-b, --branch <branch>`
  : Git branch to clone/use (default: `main`)
- `-s, --scope <local|project|both>`
  : Where to install the flake:
  - `local` (default): only in `~/.local/share/nix-devflake`
  - `project`: only in `./.nix-devflake`
  - `both`: install/update in both locations

The script will then:

1. Clone or update the devflake repo.
2. Prompt for your desired environment.
3. Optionally include AI tooling.
4. Generate a `.envrc` with the appropriate `use flake "path://...#<env>"` lines.

### 2. Enter the devShell

After `.envrc` is created, run:

```bash
direnv allow
```

You’ll see something like:

```
direnv: using flake path:///home/user/.local/share/nix-devflake#python
Loaded x86_64-linux:python devShell
```

To switch to the AI-augmented shell instead, edit or rerun the init script and uncomment:

```bash
use flake "path:///home/user/.local/share/nix-devflake#python-ai"
```

### 3. Updating your devflake

When upstream improvements land (new shells, tool upgrades), update your local clone:

```bash
cd ~/.local/share/nix-devflake
git pull origin main   # or your branch of choice
nix flake update       # updates `flake.lock`
```

Then in your project:

```bash
direnv reload
```

---

## File Structure

```text
nix-devflake/
├── devflake-init.sh    # bootstrap/install script
├── flake.nix           # defines all devShells
├── README.md           # this doc
└── ...
```

---

## License

This project is licensed under the MIT License.
