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

	local download_url
	download_url=$(github_release_url "clangd/clangd" "clangd-linux.*\\.zip") || return 1

	local filepath
	filepath=$(download_file "$download_url") || return 1
	local filename
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
