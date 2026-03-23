# 🛠️ Reparo

One-command Linux development environment setup scripts, supporting **Fedora** and **Ubuntu**.

Automatically installs and configures the following tools:

| Tool | Description |
|------|-------------|
| **Vim** | Editor + custom configuration |
| **Neovim** | Modern editor + clangd / tree-sitter |
| **Tmux** | Terminal multiplexer |
| **Powerline** | Status bar theming + gitstatus |
| **GDB** | Debugger + pygments syntax highlighting |

## 📋 Prerequisites

- Bash 4.0+
- Git
- sudo privileges (for installing packages)
- Supported distributions: Fedora or Ubuntu

## 🚀 Quick Start

```bash
git clone https://github.com/haoyouab/Reparo.git
cd Reparo
bash setup
source ~/.bashrc
```

Skip Neovim (saves time, no Rust/cargo installation):

```bash
bash setup --skip-neovim
```

### 📦 Offline Mode

If your network cannot reliably access GitHub (e.g. slow curl downloads), you can pre-download the required packages and use the `--offline` option to skip network downloads:

```bash
bash setup --offline=/path/to/packages
```

The offline directory should contain the following files (downloaded from GitHub Releases):

| File | Source | Description |
|------|--------|-------------|
| `nvim-linux-x86_64.tar.gz` | [neovim/neovim](https://github.com/neovim/neovim/releases) | Neovim binary (Ubuntu only; use the aarch64 variant for ARM architectures) |
| `clangd-linux-*.zip` | [clangd/clangd](https://github.com/clangd/clangd/releases) | clangd language server |

> Fedora installs Neovim via `dnf`, so only the clangd package is needed.

## 🐳 Docker Dev Environment

Don't want to modify your host machine? Use a pre-configured development environment inside a Docker container:

```bash
# Build Fedora dev environment (default)
bash setup --docker

# Build Ubuntu dev environment
bash setup --docker --ubuntu

# Skip Neovim (faster)
bash setup --docker --skip-neovim

# Build with offline packages (avoid downloading inside the container)
bash setup --docker --offline=/path/to/packages
bash setup --docker --ubuntu --offline=/path/to/packages
```

> The container user's name and UID automatically match the host user, so volume mounts have no permission issues.

### Enter a Container

After building, use the `enter` script to quickly enter a container:

```bash
# Enter Ubuntu container (default)
bash enter

# Enter Fedora container
bash enter --fedora

# Interactive distro selection
bash enter -i
```

The `enter` script automatically detects container state: attaches if running, starts then attaches if stopped, or prompts to build if the image doesn't exist.

### Manual Container Launch

```bash
# Interactive start
docker run -it reparo-dev-ubuntu

# Mount a host project directory
docker run -it -v $(pwd):/home/$(whoami)/project:z reparo-dev-ubuntu

# Run in background, attach later
docker run -dit --name my-dev reparo-dev-ubuntu
docker exec -it my-dev bash
```

## 📁 Project Structure

```
Reparo/
├── setup                    # Entry script, auto-detects distro
├── enter                    # Quick-enter Docker container
├── dist/
│   ├── common.sh            # Shared function library (logging, backup, download, etc.)
│   ├── Fedora/
│   │   ├── setup.sh         # Fedora-specific setup script
│   │   ├── vim/             # Vim config files
│   │   ├── tmux/            # Tmux config files
│   │   ├── powerline/       # Powerline config files
│   │   └── gdb/             # GDB config files
│   └── Ubuntu/
│       ├── setup.sh         # Ubuntu-specific setup script
│       └── ...              # Same as above
├── docker/
│   ├── build.sh             # Docker build orchestration script
│   ├── Dockerfile.fedora    # Fedora dev environment image
│   └── Dockerfile.ubuntu    # Ubuntu dev environment image
├── tests/
│   ├── run_tests.sh         # Unit tests (91 test cases)
│   ├── docker-test.sh       # Docker integration test runner
│   ├── verify-setup.sh      # Post-install verification script
│   ├── Dockerfile.fedora    # Fedora test container
│   └── Dockerfile.ubuntu    # Ubuntu test container
└── .github/workflows/
    ├── ci.yml               # Lint (shellcheck + shfmt) + unit tests
    └── integration.yml      # Docker integration tests
```

## ✨ Features

- 🎨 **Modern UI** — Emoji icons + ANSI color output + box-drawing separators
- 🛡️ **Robust Error Handling** — Aborts immediately on any step failure with clear error messages
- 📦 **Auto Backup** — Automatically backs up existing configs to `~/.config-backup-<timestamp>/` before overwriting
- 🏗️ **Architecture Aware** — Auto-detects x86_64 / aarch64 and downloads the matching binaries
- 📦 **Offline Mode** — `--offline=DIR` supports offline installation without GitHub access
- 🔄 **Shared Function Library** — `dist/common.sh` eliminates code duplication
- 🐳 **Docker Dev Environment** — One-command build for a ready-to-use containerized dev environment
- 🐳 **Docker Testing** — Full containerized integration tests

## 🧪 Testing

### Unit Tests

```bash
bash tests/run_tests.sh
```

### Docker Integration Tests

Requires Docker:

```bash
# Test both distros
bash tests/docker-test.sh

# Test Fedora only
bash tests/docker-test.sh --fedora

# Test Ubuntu only
bash tests/docker-test.sh --ubuntu

# Skip Neovim (faster)
SKIP_NEOVIM=true bash tests/docker-test.sh
```

### GitHub Actions CI

- **Lint** — Runs shellcheck, shfmt, and unit tests on every push / PR
- **Integration** — Runs Docker integration tests on manual trigger or push to main

## 📄 License

MIT
