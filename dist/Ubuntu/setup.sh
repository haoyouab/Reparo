#!/bin/bash

# ─── Source common functions ──────────────────────────────────────────────────
# shellcheck source-path=SCRIPTDIR source=../common.sh
source "$(dirname "$DIST_ROOT")/common.sh"

# ─── Helper: install package (Ubuntu/apt) ─────────────────────────────────────
install_package() {
	local package=$1
	log_info "Installing ${BOLD}${package}${RST}..."
	if sudo apt install "$package" -y; then
		log_success "$package installed successfully"
	else
		log_error "Failed to install $package — check your network connection or package name."
		return 1
	fi
}

# ─── Setup: Vim ───────────────────────────────────────────────────────────────
setup_vim() {
	log_info "Setting up Vim..."
	install_package vim || return 1
	copy_config "$DIST_ROOT/vim/vim" "$HOME/.vim" || return 1
	copy_config "$DIST_ROOT/vim/vimrc" "$HOME/.vimrc" || return 1
	log_success "Vim setup completed"
}

# ─── Setup: Neovim ────────────────────────────────────────────────────────────
setup_neovim() {
	local nvim_config_path="$HOME/.config"

	log_info "Installing git, curl, jq, unzip, python3-pip, fd-find, ripgrep, and dev tools..."
	sudo apt install git curl jq unzip python3-pip fd-find ripgrep \
		libglib2.0-dev flex bison ninja-build clang gcc g++ make bear -y || {
		log_error "Failed to install required packages."
		return 1
	}

	# Create python → python3 and pip → pip3 symlinks if not already present
	if ! command -v python &>/dev/null; then
		sudo ln -sf "$(command -v python3)" /usr/local/bin/python
		log_info "Created symlink: python → python3"
	fi
	if ! command -v pip &>/dev/null; then
		sudo ln -sf "$(command -v pip3)" /usr/local/bin/pip
		log_info "Created symlink: pip → pip3"
	fi

	mkdir -p "$nvim_config_path" || {
		log_error "Failed to create $nvim_config_path"
		return 1
	}

	if [ -d "$HOME/.config/nvim/.git" ]; then
		log_info "Neovim config already cloned, pulling latest changes..."
		git -C "$HOME/.config/nvim" pull || log_warning "Failed to pull nvim config updates"
	else
		rm -rf "$HOME/.config/nvim/"
		log_info "Cloning Neovim config from GitHub..."
		git clone --depth 1 https://github.com/haoyouab/nvim.git "$HOME/.config/nvim" || {
			log_error "Failed to clone Neovim config repository."
			return 1
		}
	fi

	# Download neovim from GitHub latest release (arch-aware)
	if command -v nvim &>/dev/null; then
		log_info "Neovim already installed ($(nvim --version | head -1)), skipping download"
	else
		local arch
		arch=$(detect_arch) || return 1
		log_info "Detected architecture: ${BOLD}${arch}${RST}"

		local filepath
		if [ -n "$OFFLINE_DIR" ]; then
			filepath=$(find_offline_package "nvim-linux-${arch}*.tar.gz" "nvim-linux-${arch}.tar.gz (from https://github.com/neovim/neovim/releases)") || return 1
		else
			local nvim_pattern="nvim-linux-${arch}.*\\.tar\\.gz"
			local download_url
			download_url=$(github_release_url "neovim/neovim" "$nvim_pattern") || return 1
			filepath=$(download_file "$download_url") || return 1
		fi

		mkdir -p "$HOME/.local"
		log_info "Extracting Neovim to ~/.local..."
		tar -xzf "$filepath" -C "$HOME/.local" --strip-components=1 || {
			log_error "Failed to extract Neovim archive."
			return 1
		}
	fi

	setup_clangd || return 1
	setup_cpptools || return 1
	setup_marksman || return 1
	setup_tree_sitter || return 1
	setup_conform_formatters || return 1

	log_info "Pre-installing Neovim plugins (lazy.nvim headless sync)..."
	nvim --headless "+Lazy! sync" +qa 2>/dev/null || true
	log_success "Neovim plugins pre-installed"
}

# ─── Setup: Tmux ──────────────────────────────────────────────────────────────
setup_tmux() {
	log_info "Setting up Tmux..."
	install_package tmux || return 1
	copy_config "$DIST_ROOT/tmux/tmux.conf" "$HOME/.tmux.conf" || return 1
	copy_config "$DIST_ROOT/tmux/tmux.conf.local" "$HOME/.tmux.conf.local" || return 1
	copy_config "$DIST_ROOT/tmux/tmux.conf.debug" "$HOME/.tmux.conf.debug" || return 1

	# Install TPM (Tmux Plugin Manager) and plugins
	local tpm_dir="$HOME/.tmux/plugins/tpm"
	if [ ! -d "$tpm_dir" ]; then
		log_info "Installing TPM (Tmux Plugin Manager)..."
		git clone --depth 1 https://github.com/tmux-plugins/tpm "$tpm_dir" || {
			log_error "Failed to clone TPM repository."
			return 1
		}
		log_success "TPM installed"
	else
		log_info "TPM already installed, skipping"
	fi

	log_info "Installing tmux plugins..."
	"$tpm_dir/bin/install_plugins" || true
	log_success "Tmux plugins installed"

	log_success "Tmux setup completed"
}

# ─── Setup: Powerline ─────────────────────────────────────────────────────────
setup_powerline() {
	log_info "Setting up Powerline..."
	install_package powerline || return 1
	install_package fonts-powerline || return 1
	install_package python3-pip || return 1

	# Add powerline to bashrc (idempotent: strip old block then re-append)
	local marker_begin="# >>> reparo-powerline >>>"
	local marker_end="# <<< reparo-powerline <<<"
	local powerline_script_path=""
	if [ -f "/usr/share/powerline/bash/powerline.sh" ]; then
		powerline_script_path="/usr/share/powerline/bash/powerline.sh"
	elif [ -f "/usr/share/powerline/bindings/bash/powerline.sh" ]; then
		powerline_script_path="/usr/share/powerline/bindings/bash/powerline.sh"
	else
		log_error "Powerline script not found in expected locations (/usr/share/powerline/bash/ or bindings/bash/)."
		return 1
	fi
	if grep -q "$marker_begin" "$HOME/.bashrc"; then
		log_info "Updating powerline block in ~/.bashrc..."
		sed -i "/$marker_begin/,/$marker_end/d" "$HOME/.bashrc"
	else
		log_info "Adding powerline to ~/.bashrc..."
	fi
	{
		echo "$marker_begin"
		sed "s|POWERLINE_SCRIPT=/usr/share/powerline/bash/powerline.sh|POWERLINE_SCRIPT=$powerline_script_path|" "$DIST_ROOT/powerline/bashrc"
		echo "$marker_end"
	} >>"$HOME/.bashrc"
	log_success "Powerline configured in ~/.bashrc"

	# Install powerline-gitstatus
	log_info "Installing powerline-gitstatus..."
	if pip_install powerline-gitstatus; then
		log_success "powerline-gitstatus installed"
	else
		log_error "Failed to install powerline-gitstatus — check pip configuration."
		return 1
	fi

	# Configure powerline
	local POWERLINE_LOCAL_CONFIG="$HOME/.config/powerline/"
	local POWERLINE_GLOBAL_CONFIG="/usr/share/powerline/config_files/"
	mkdir -p "$POWERLINE_LOCAL_CONFIG"
	sudo cp -r "$POWERLINE_GLOBAL_CONFIG"/* "$POWERLINE_LOCAL_CONFIG"
	sudo chown "$(whoami):$(whoami)" "$POWERLINE_LOCAL_CONFIG" -R
	copy_config "$DIST_ROOT/powerline/colorschemes" "$POWERLINE_LOCAL_CONFIG" || return 1
	copy_config "$DIST_ROOT/powerline/colors.json" "$POWERLINE_LOCAL_CONFIG" || return 1
	copy_config "$DIST_ROOT/powerline/config.json" "$POWERLINE_LOCAL_CONFIG" || return 1
	copy_config "$DIST_ROOT/powerline/themes" "$POWERLINE_LOCAL_CONFIG" || return 1

	log_info "Restarting powerline daemon..."
	if PYTHONWARNINGS=ignore::SyntaxWarning powerline-daemon --replace; then
		log_success "Powerline daemon restarted"
	else
		log_error "Failed to restart powerline daemon."
		return 1
	fi

	log_success "Powerline setup completed"
}

# ─── Setup: GDB ───────────────────────────────────────────────────────────────
setup_gdb() {
	log_info "Setting up GDB..."
	install_package gdb || return 1

	log_info "Installing pygments..."
	if pip_install pygments; then
		log_success "pygments installed"
	else
		log_error "Failed to install pygments — check pip configuration."
		return 1
	fi

	copy_config "$DIST_ROOT/gdb/gdbinit" "$HOME/.gdbinit" || return 1
	mkdir -p "$HOME/.gdbinit.d"
	for f in "$DIST_ROOT"/gdb/gdbinit.d/*.{py,gdb}; do
		copy_config "$f" "$HOME/.gdbinit.d/$(basename "$f")" || return 1
	done
	log_success "GDB setup completed"
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
	local TOTAL_STEPS=5
	local SKIP_NEOVIM=false

	# Parse flags
	for _arg in "$@"; do
		case "$_arg" in
			--neovim)
				print_section 1 1 "📝" "NEOVIM"
				setup_neovim || die "Neovim setup failed — check the output above."
				echo ""
				log_success "${BOLD}Neovim setup completed.${RST}"
				return 0
				;;
			--skip-neovim) SKIP_NEOVIM=true ;;
			--offline=*)
				export OFFLINE_DIR="${_arg#--offline=}"
				if [ ! -d "$OFFLINE_DIR" ]; then
					die "Offline directory does not exist: $OFFLINE_DIR"
				fi
				log_info "Offline mode: using packages from ${BOLD}${OFFLINE_DIR}${RST}"
				;;
		esac
	done

	if [ "$SKIP_NEOVIM" = true ]; then
		TOTAL_STEPS=4
		log_warning "Skipping Neovim step (--skip-neovim)"
	fi

	# ─── Offline pre-flight check ──────────────────────────────────────────
	if [ -n "${OFFLINE_DIR:-}" ] && [ "$SKIP_NEOVIM" = false ]; then
		local arch
		arch=$(detect_arch) || die "Cannot detect architecture."
		local vsix_arch
		case "$arch" in
			x86_64) vsix_arch="x64" ;;
			aarch64) vsix_arch="arm64" ;;
		esac
		local missing=false
		if ! find "$OFFLINE_DIR" -maxdepth 1 -name "nvim-linux-${arch}*.tar.gz" -print -quit 2>/dev/null | grep -q .; then
			log_error "Missing offline package: nvim-linux-${arch}*.tar.gz"
			log_error "  Download from: https://github.com/neovim/neovim/releases"
			missing=true
		fi
		if ! find "$OFFLINE_DIR" -maxdepth 1 -name "clangd-linux-*.zip" -print -quit 2>/dev/null | grep -q .; then
			log_error "Missing offline package: clangd-linux-*.zip"
			log_error "  Download from: https://github.com/clangd/clangd/releases"
			missing=true
		fi
		if ! find "$OFFLINE_DIR" -maxdepth 1 -name "cpptools-linux-${vsix_arch}.vsix" -print -quit 2>/dev/null | grep -q .; then
			log_error "Missing offline package: cpptools-linux-${vsix_arch}.vsix"
			log_error "  Download from: https://github.com/microsoft/vscode-cpptools/releases"
			missing=true
		fi
		if ! find "$OFFLINE_DIR" -maxdepth 1 -name "marksman-linux-${vsix_arch}" -print -quit 2>/dev/null | grep -q .; then
			log_error "Missing offline package: marksman-linux-${vsix_arch}"
			log_error "  Download from: https://github.com/artempyanykh/marksman/releases"
			missing=true
		fi
		[ "$missing" = true ] && die "Offline packages missing — add them to ${OFFLINE_DIR} and retry."
	fi

	log_info "Updating package list..."
	if sudo apt update; then
		log_success "Package list updated"
	else
		die "Failed to update package list — check your network connection and apt sources."
	fi

	echo ""
	echo -e "${GREEN}${BOLD}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${RST}"
	echo -e "${GREEN}${BOLD}┃${RST}  🐧  ${BOLD}Setting up Ubuntu environment${RST}"
	echo -e "${GREEN}${BOLD}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${RST}"

	print_section 1 $TOTAL_STEPS "✏️" "VIM"
	setup_vim || die "Vim setup failed — check the output above."

	local step=2
	if [ "$SKIP_NEOVIM" = false ]; then
		print_section $step $TOTAL_STEPS "📝" "NEOVIM"
		setup_neovim || die "Neovim setup failed — check the output above."
		step=$((step + 1))
	fi

	print_section $step $TOTAL_STEPS "🖥️" "TMUX"
	setup_tmux || die "Tmux setup failed — check the output above."
	step=$((step + 1))

	print_section $step $TOTAL_STEPS "⚡" "POWERLINE"
	setup_powerline || die "Powerline setup failed — check the output above."
	step=$((step + 1))

	print_section $step $TOTAL_STEPS "🔍" "GDB"
	setup_gdb || die "GDB setup failed — check the output above."

	setup_docker_config

	echo ""
	echo -e "${GREEN}${BOLD}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${RST}"
	echo -e "${GREEN}${BOLD}┃${RST}  🎉  ${BOLD}All setups completed successfully!${RST}"
	echo -e "${GREEN}${BOLD}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${RST}"
}

main "$@"
