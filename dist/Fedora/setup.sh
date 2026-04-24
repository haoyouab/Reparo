#!/bin/bash

# ─── Source common functions ──────────────────────────────────────────────────
# shellcheck source-path=SCRIPTDIR source=../common.sh
source "$(dirname "$DIST_ROOT")/common.sh"

# ─── Helper: install package (Fedora/dnf) ────────────────────────────────────
install_package() {
	local package=$1
	log_info "Installing ${BOLD}${package}${RST}..."
	if sudo dnf install "$package" -y; then
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

	log_info "Installing neovim, git, jq, unzip, python3, python3-pip, fd-find, ripgrep, and dev tools..."
	sudo dnf install -y neovim git jq unzip python3 python3-pip fd-find ripgrep \
		glib2-devel flex bison ninja-build clang gcc gcc-c++ make bear || {
		log_error "Failed to install required packages."
		return 1
	}

	mkdir -p "$nvim_config_path" || {
		log_error "Failed to create $nvim_config_path"
		return 1
	}

	rm -rf "$HOME/.config/nvim/"
	log_info "Cloning Neovim config from GitHub..."
	git clone --depth 1 https://github.com/haoyouab/nvim.git "$HOME/.config/nvim" || {
		log_error "Failed to clone Neovim config repository."
		return 1
	}

	setup_clangd || return 1
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
	log_success "Tmux setup completed"
}

# ─── Setup: Powerline ─────────────────────────────────────────────────────────
setup_powerline() {
	log_info "Setting up Powerline..."
	install_package powerline || return 1
	install_package powerline-fonts || return 1
	install_package python3-pip || return 1

	# Add powerline to bashrc if not present
	if ! grep -q "powerline-daemon" "$HOME/.bashrc"; then
		log_info "Adding powerline to ~/.bashrc..."
		cat "$DIST_ROOT/powerline/bashrc" >>"$HOME/.bashrc"
		log_success "Powerline added to ~/.bashrc"
	else
		log_info "Powerline already configured in ~/.bashrc"
	fi

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
	local POWERLINE_GLOBAL_CONFIG1="/etc/xdg/powerline/config_files/"
	local POWERLINE_GLOBAL_CONFIG2="/etc/xdg/powerline/"

	mkdir -p "$POWERLINE_LOCAL_CONFIG"

	if [ -d "$POWERLINE_GLOBAL_CONFIG1" ]; then
		log_info "Copying global powerline config from $POWERLINE_GLOBAL_CONFIG1..."
		sudo cp -r "$POWERLINE_GLOBAL_CONFIG1"/* "$POWERLINE_LOCAL_CONFIG"
	elif [ -d "$POWERLINE_GLOBAL_CONFIG2" ]; then
		log_info "Copying global powerline config from $POWERLINE_GLOBAL_CONFIG2..."
		sudo cp -r "$POWERLINE_GLOBAL_CONFIG2"/* "$POWERLINE_LOCAL_CONFIG"
	else
		log_warning "No global powerline config directory found, skipping global config copy"
	fi

	sudo chown "$(whoami):$(whoami)" "$POWERLINE_LOCAL_CONFIG" -R

	log_info "Copying custom powerline configuration..."
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
		local missing=false
		if ! find "$OFFLINE_DIR" -maxdepth 1 -name "clangd-linux-*.zip" -print -quit 2>/dev/null | grep -q .; then
			log_error "Missing offline package: clangd-linux-*.zip"
			log_error "  Download from: https://github.com/clangd/clangd/releases"
			missing=true
		fi
		[ "$missing" = true ] && die "Offline packages missing — add them to ${OFFLINE_DIR} and retry."
	fi

	echo ""
	echo -e "${GREEN}${BOLD}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${RST}"
	echo -e "${GREEN}${BOLD}┃${RST}  🐧  ${BOLD}Setting up Fedora environment${RST}"
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
