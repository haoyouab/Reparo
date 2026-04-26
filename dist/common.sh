#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
#  common.sh — Shared functions for all distribution setup scripts
#  Sourced by dist/Fedora/setup.sh, dist/Ubuntu/setup.sh, etc.
# ─────────────────────────────────────────────────────────────────────────────

# ─── Color & Style Definitions (safe for non-TTY) ────────────────────────────
RED=$(tput setaf 1 2>/dev/null || true)
GREEN=$(tput setaf 2 2>/dev/null || true)
YELLOW=$(tput setaf 3 2>/dev/null || true)
BLUE=$(tput setaf 4 2>/dev/null || true)
BOLD=$(tput bold 2>/dev/null || true)
RST=$(tput sgr0 2>/dev/null || true)

# ─── Trap Ctrl-C ──────────────────────────────────────────────────────────────
trap 'echo -e "\n${RED}❌ Setup interrupted by user. Exiting...${RST}"; rm -rf "$DOWNLOAD_DIR" 2>/dev/null; exit 1' INT

# ─── Download temp directory (auto-cleaned on exit) ──────────────────────────
DOWNLOAD_DIR=$(mktemp -d /tmp/reparo-setup.XXXXXX)
trap 'rm -rf "$DOWNLOAD_DIR" 2>/dev/null' EXIT

# ─── Offline package directory (set via --offline=DIR) ────────────────────────
# When set, curl downloads from GitHub are skipped; packages are read from here.
OFFLINE_DIR="${OFFLINE_DIR:-}"

# ─── Backup directory for overwritten configs ─────────────────────────────────
BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
BACKUP_CREATED=false

# ─── Logging Functions ────────────────────────────────────────────────────────
log_info() { echo -e "  ${BLUE}ℹ️  ${RST}$1"; }
log_success() { echo -e "  ${GREEN}✅ ${RST}$1"; }
log_warning() { echo -e "  ${YELLOW}⚠️  ${RST}$1"; }
log_error() { echo -e "  ${RED}❌ ${RST}$1"; }

# ─── Section header with step counter ────────────────────────────────────────
print_section() {
	local step=$1 total=$2 emoji=$3 title=$4
	echo ""
	echo -e "${GREEN}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${RST}"
	echo -e "${GREEN}┃${RST}  ${emoji}  ${BOLD}${title}${RST}  ${BLUE}[Step ${step}/${total}]${RST}"
	echo -e "${GREEN}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${RST}"
}

# ─── Fatal: print error banner and abort ──────────────────────────────────────
die() {
	echo ""
	echo -e "${RED}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${RST}"
	echo -e "${RED}┃${RST}  ❌  ${BOLD}SETUP FAILED${RST}"
	echo -e "${RED}┃${RST}     $1"
	echo -e "${RED}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${RST}"
	exit 1
}

# ─── Backup existing file/dir before overwriting ──────────────────────────────
backup_if_exists() {
	local dest=$1
	if [ -e "$dest" ]; then
		if [ "$BACKUP_CREATED" = false ]; then
			mkdir -p "$BACKUP_DIR"
			BACKUP_CREATED=true
			log_info "Backing up existing configs to ${BOLD}${BACKUP_DIR}${RST}"
		fi
		cp -r "$dest" "$BACKUP_DIR/" 2>/dev/null || true
	fi
}

# ─── Helper: copy config files (with backup) ─────────────────────────────────
copy_config() {
	local src=$1
	local dest=$2
	if [ ! -e "$src" ]; then
		log_error "Source not found: $src"
		return 1
	fi
	backup_if_exists "$dest"
	log_info "Copying $src → $dest"
	if cp -r "$src" "$dest" >/dev/null 2>&1; then
		log_success "Copied to $dest"
	else
		log_error "Failed to copy $src → $dest — check permissions."
		return 1
	fi
}

# ─── Helper: pip install with Tsinghua mirror + PEP 668 handling ─────────────
pip_install() {
	local pkg=$1
	local break_flag=""
	if python3 -m pip install --help 2>&1 | grep -q -- '--break-system-packages'; then
		break_flag="--break-system-packages"
	fi
	python3 -m pip install "$pkg" \
		--user $break_flag \
		-i https://pypi.tuna.tsinghua.edu.cn/simple \
		--trusted-host pypi.tuna.tsinghua.edu.cn
}

# ─── Configure Docker detach key to avoid hijacking Ctrl-P ─────────────────────
setup_docker_config() {
	if ! command -v docker &>/dev/null; then
		log_info "Docker not installed, skipping Docker config"
		return 0
	fi
	local config_dir="$HOME/.docker"
	local config_file="$config_dir/config.json"
	mkdir -p "$config_dir"
	if [ ! -f "$config_file" ]; then
		echo '{"detachKeys": "ctrl-q,ctrl-q"}' >"$config_file"
		log_success "Created $config_file with detachKeys=ctrl-q,ctrl-q"
	elif command -v jq &>/dev/null; then
		local tmp
		tmp=$(jq '. + {"detachKeys": "ctrl-q,ctrl-q"}' "$config_file") \
			&& echo "$tmp" >"$config_file" \
			&& log_success "Updated Docker detachKeys in $config_file"
	else
		log_warning "jq not found; manually add \"detachKeys\": \"ctrl-q,ctrl-q\" to $config_file"
	fi
}

# ─── Helper: find offline package in OFFLINE_DIR ──────────────────────────────
find_offline_package() {
	local pattern=$1
	local description=$2
	if [ -z "$OFFLINE_DIR" ]; then
		return 1
	fi
	local found
	found=$(find "$OFFLINE_DIR" -maxdepth 1 -name "$pattern" -print -quit 2>/dev/null)
	if [ -n "$found" ]; then
		log_info "Found offline package: ${BOLD}$(basename "$found")${RST}" >&2
		echo "$found"
		return 0
	else
		log_error "Offline package not found in $OFFLINE_DIR (pattern: $pattern)" >&2
		log_error "Expected: $description" >&2
		return 1
	fi
}

# ─── Detect system architecture ───────────────────────────────────────────────
detect_arch() {
	local arch
	arch=$(uname -m)
	case "$arch" in
		x86_64) echo "x86_64" ;;
		aarch64) echo "aarch64" ;;
		arm64) echo "aarch64" ;;
		*)
			log_error "Unsupported architecture: $arch"
			return 1
			;;
	esac
}

# ─── Helper: download file to DOWNLOAD_DIR ───────────────────────────────────
download_file() {
	local url=$1
	local filename
	filename=$(basename "$url")
	log_info "Downloading: $filename" >&2
	if curl -fL "$url" -o "$DOWNLOAD_DIR/$filename"; then
		log_success "Downloaded: $filename" >&2
		echo "$DOWNLOAD_DIR/$filename"
	else
		log_error "Failed to download from $url" >&2
		return 1
	fi
}

# ─── Helper: query GitHub release API with jq ────────────────────────────────
github_release_url() {
	local repo=$1
	local pattern=$2
	local api_url="https://api.github.com/repos/${repo}/releases/latest"

	log_info "Fetching latest release info from ${repo}..." >&2

	# Build curl args — use GITHUB_TOKEN for authenticated requests if available
	# (unauthenticated: 60 req/hr, authenticated: 5000 req/hr)
	local curl_args=(-s)
	if [ -n "${GITHUB_TOKEN:-}" ]; then
		curl_args+=(-H "Authorization: token ${GITHUB_TOKEN}")
		log_info "Using authenticated GitHub API request" >&2
	fi

	local json
	json=$(curl "${curl_args[@]}" "$api_url")

	# Check for API errors (rate limit, not found, etc.)
	local api_msg
	api_msg=$(echo "$json" | jq -r '.message // empty' 2>/dev/null)
	if [ -n "$api_msg" ]; then
		log_error "GitHub API error: ${api_msg}" >&2
		if [ -z "${GITHUB_TOKEN:-}" ]; then
			log_error "Tip: set GITHUB_TOKEN to avoid rate limits (export GITHUB_TOKEN=ghp_xxx)" >&2
		fi
		return 1
	fi

	local url
	if command -v jq &>/dev/null; then
		url=$(echo "$json" | jq -r --arg pat "$pattern" '.assets[]? | select(.name | test($pat)) | .browser_download_url' | head -1)
	else
		# Fallback: grep-based parsing if jq is not available
		url=$(echo "$json" | grep "browser_download_url.*${pattern}" | head -1 | cut -d '"' -f 4)
	fi

	if [ -z "$url" ] || [ "$url" = "null" ]; then
		log_error "Failed to find download URL for ${repo} (pattern: ${pattern})" >&2
		return 1
	fi
	echo "$url"
}

# ─── Common Neovim tooling setup (clangd + tree-sitter) ──────────────────────
setup_clangd() {
	local clangd_path="$HOME/.local/share/nvim/mason/packages/clangd"
	mkdir -p "$clangd_path" || {
		log_error "Failed to create $clangd_path"
		return 1
	}

	local filepath filename
	if [ -n "$OFFLINE_DIR" ]; then
		filepath=$(find_offline_package "clangd-linux-*.zip" "clangd-linux-<arch>.zip (from https://github.com/clangd/clangd/releases)") || return 1
	else
		local download_url
		download_url=$(github_release_url "clangd/clangd" "clangd-linux.*\\.zip") || return 1
		filepath=$(download_file "$download_url") || return 1
	fi
	filename=$(basename "$filepath")

	copy_config "$filepath" "$clangd_path" || return 1
	mkdir -p "$HOME/.local/share/nvim/mason/bin" || {
		log_error "Failed to create mason bin directory."
		return 1
	}

	pushd "$clangd_path" >/dev/null || {
		log_error "Failed to enter $clangd_path"
		return 1
	}

	log_info "Extracting clangd..."
	unzip -o "$filename" || {
		popd >/dev/null || return 1
		log_error "Failed to extract $filename"
		return 1
	}

	local extracted_dir
	extracted_dir=$(find . -maxdepth 1 -mindepth 1 -type d -print -quit | sed 's|^\./||')
	if [ -z "$extracted_dir" ]; then
		popd >/dev/null || return 1
		log_error "Failed to find extracted clangd directory."
		return 1
	fi

	ln -sf "$clangd_path/$extracted_dir/bin/clangd" "$HOME/.local/share/nvim/mason/bin/clangd"
	popd >/dev/null || return 1
	log_success "clangd installed and linked"
}

setup_tree_sitter() {
	log_info "Installing tree-sitter via cargo..."

	# Try Tsinghua mirror first, fall back to official if unavailable
	if curl -sSf --connect-timeout 5 https://mirrors.tuna.tsinghua.edu.cn/rustup/rustup/ >/dev/null 2>&1; then
		export RUSTUP_UPDATE_ROOT=https://mirrors.tuna.tsinghua.edu.cn/rustup/rustup
		export RUSTUP_DIST_SERVER=https://mirrors.tuna.tsinghua.edu.cn/rustup
		log_info "Using Tsinghua Rust mirror"
	else
		log_warning "Tsinghua mirror unavailable, using official Rust source"
		unset RUSTUP_UPDATE_ROOT RUSTUP_DIST_SERVER
	fi

	# Ensure C compiler is available (required for building Rust crates)
	if ! command -v cc &>/dev/null; then
		log_info "C compiler not found — installing gcc..."
		if command -v dnf &>/dev/null; then
			sudo dnf install -y gcc || {
				log_error "Failed to install gcc."
				return 1
			}
		elif command -v apt &>/dev/null; then
			sudo apt install -y gcc || {
				log_error "Failed to install gcc."
				return 1
			}
		fi
	fi

	if ! command -v cargo &>/dev/null; then
		log_info "Rust toolchain not found — installing..."
		curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y || {
			log_error "Failed to install Rust toolchain."
			return 1
		}
		# shellcheck disable=SC1091
		source "$HOME/.cargo/env"
	fi

	log_info "Updating Rust to latest version..."
	rustup update || {
		log_error "Failed to update Rust."
		return 1
	}

	cargo install --locked tree-sitter-cli --version 0.25.10 || {
		log_error "Failed to install tree-sitter-cli."
		return 1
	}
	log_success "tree-sitter installed"

	mkdir -p "$HOME/.local/share/nvim/mason/bin"
	ln -sf "$HOME/.cargo/bin/tree-sitter" "$HOME/.local/share/nvim/mason/bin/tree-sitter"
	log_success "tree-sitter symlink created"
}

# ─── Setup: Conform.nvim formatters ──────────────────────────────────────────
# Installs: prettier, black, shfmt, clang-format, taplo, rustfmt (nightly)
setup_conform_formatters() {
	log_info "Installing conform.nvim formatters..."

	# ── prettier (html/css/js/ts/json) ──────────────────────────────────────
	log_info "Installing ${BOLD}Node.js 22 + prettier${RST}..."
	if command -v dnf &>/dev/null; then
		sudo dnf install -y nodejs npm || {
			log_error "Failed to install nodejs/npm."
			return 1
		}
	elif command -v apt &>/dev/null; then
		# apt ships Node.js 18 which is too old for Copilot (requires ≥22)
		# Download Node.js 22 binary from npmmirror (accessible in mainland China)
		log_info "Fetching Node.js 22 latest version from npmmirror..."
		local node_version
		node_version=$(curl -fsSL https://npmmirror.com/mirrors/node/latest-v22.x/SHASUMS256.txt 2>/dev/null \
			| grep "node-v.*-linux-x64.tar.xz" | head -1 \
			| grep -oP 'node-v[0-9]+\.[0-9]+\.[0-9]+') || {
			log_error "Failed to fetch Node.js version info."
			return 1
		}
		local node_url="https://npmmirror.com/mirrors/node/latest-v22.x/${node_version}-linux-x64.tar.xz"
		log_info "Downloading ${BOLD}${node_version}${RST} from npmmirror..."
		local node_archive
		node_archive=$(download_file "$node_url") || {
			log_error "Failed to download Node.js."
			return 1
		}
		sudo tar -xJf "$node_archive" -C /usr/local --strip-components=1 || {
			log_error "Failed to extract Node.js."
			return 1
		}
	fi
	sudo npm install -g prettier || {
		log_error "Failed to install prettier."
		return 1
	}
	log_success "prettier installed (Node.js $(node --version))"

	# ── black (python) ──────────────────────────────────────────────────────
	log_info "Installing ${BOLD}black${RST} via pip..."
	pip_install black || {
		log_error "Failed to install black."
		return 1
	}
	log_success "black installed"

	# ── shfmt (sh/bash) ─────────────────────────────────────────────────────
	log_info "Installing ${BOLD}shfmt${RST}..."
	if command -v dnf &>/dev/null; then
		sudo dnf install -y shfmt || {
			log_error "Failed to install shfmt."
			return 1
		}
	elif command -v apt &>/dev/null; then
		# apt Go version is too old to build shfmt from source; use prebuilt binary
		local shfmt_ver
		shfmt_ver=$(curl -fsSL https://api.github.com/repos/mvdan/sh/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/') || {
			log_error "Failed to fetch shfmt latest version."
			return 1
		}
		local arch
		arch=$(uname -m)
		case "$arch" in
			x86_64) arch="amd64" ;;
			aarch64) arch="arm64" ;;
		esac
		mkdir -p "$HOME/.local/bin"
		curl -fsSL "https://github.com/mvdan/sh/releases/download/${shfmt_ver}/shfmt_${shfmt_ver}_linux_${arch}" \
			-o "$HOME/.local/bin/shfmt" || {
			log_error "Failed to download shfmt binary."
			return 1
		}
		chmod +x "$HOME/.local/bin/shfmt"
	fi
	log_success "shfmt installed"

	# ── clang-format (c/cpp) ────────────────────────────────────────────────
	log_info "Installing ${BOLD}clang-format${RST}..."
	if command -v dnf &>/dev/null; then
		sudo dnf install -y clang-tools-extra || {
			log_error "Failed to install clang-tools-extra."
			return 1
		}
	elif command -v apt &>/dev/null; then
		sudo apt install -y clang-format || {
			log_error "Failed to install clang-format."
			return 1
		}
	fi
	log_success "clang-format installed"

	# ── taplo (toml) ────────────────────────────────────────────────────────
	log_info "Installing ${BOLD}taplo${RST} via cargo..."
	# shellcheck disable=SC1091
	[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"
	cargo install taplo-cli || {
		log_error "Failed to install taplo-cli."
		return 1
	}
	log_success "taplo installed"

	# ── rustfmt nightly (rust) ──────────────────────────────────────────────
	log_info "Installing ${BOLD}rustfmt${RST} nightly..."
	rustup toolchain install nightly || {
		log_error "Failed to install nightly toolchain."
		return 1
	}
	rustup component add --toolchain nightly rustfmt || {
		log_error "Failed to add rustfmt to nightly toolchain."
		return 1
	}
	log_success "rustfmt nightly installed"

	log_success "All conform.nvim formatters installed"
}
