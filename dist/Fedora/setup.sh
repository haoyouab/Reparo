#!/bin/bash -x

# Color definitions
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
RST=$(tput sgr0)

# Get the directory of the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Trap Ctrl-C to exit the entire script
trap 'echo -e "\n${RED}Setup interrupted by user. Exiting...${RST}"; exit 1' INT

# Logging functions
log_info() {
	echo -e "${BLUE}[INFO]${RST} $1"
}

log_success() {
	echo -e "${GREEN}[SUCCESS]${RST} $1"
}

log_warning() {
	echo -e "${YELLOW}[WARNING]${RST} $1"
}

log_error() {
	echo -e "${RED}[ERROR]${RST} $1"
}

# Function to install package
install_package() {
	local package=$1
	log_info "Installing $package..."
	if sudo dnf install $package -y; then
		log_success "$package installed successfully"
	else
		log_error "Failed to install $package"
		return 1
	fi
}

# Function to copy config files
copy_config() {
	local src=$1
	local dest=$2
	log_info "Copying $src to $dest..."
	if cp -r "$src" "$dest" >/dev/null 2>&1; then
		log_success "Configuration copied to $dest"
	else
		log_error "Failed to copy configuration to $dest"
		return 1
	fi
}

# Setup Vim
setup_vim() {
	log_info "Setting up Vim..."
	install_package vim || return 1
	copy_config "$DIST_ROOT/vim/vim" $HOME/.vim || return 1
	copy_config "$DIST_ROOT/vim/vimrc" $HOME/.vimrc || return 1
	log_success "Vim setup completed"
}

# Setup Neovim
setup_neovim() {
	local nvim_config_path="$HOME/.config"
	local nvim_package_path="$HOME/.local/share"
	local clangd_path="$HOME/.local/share/nvim/mason/packages/clangd"

	sudo dnf install -y neovim git
	mkdir -p $nvim_config_path
	mkdir -p $clangd_path
	# copy_config "$DIST_ROOT/nvim" $HOME/.config || return 1
	rm -rf $HOME/.config/nvim/
	git clone https://github.com/haoyouab/nvim.git $HOME/.config/nvim || return 1

	# Download clangd from GitHub latest release
	log_info "Downloading clangd from GitHub latest release..."
	local api_url="https://api.github.com/repos/clangd/clangd/releases/latest"
	local download_url=$(curl -s $api_url | grep "browser_download_url.*clangd-linux.*\.zip" | head -1 | cut -d '"' -f 4)
	if [ -z "$download_url" ]; then
		log_error "Failed to find clangd download URL"
		return 1
	fi
	local filename=$(basename "$download_url")
	curl -L $download_url -o "$filename"
	log_success "clangd downloaded as $filename"

	copy_config "$filename" "$clangd_path"
	mkdir -p "$HOME/.local/share/nvim/mason/bin"
	pushd "$clangd_path"
	unzip -o "$filename"
	local extracted_dir=$(ls -d */ | head -1 | tr -d '/')
	ln -sf "$clangd_path/$extracted_dir/bin/clangd" "$HOME/.local/share/nvim/mason/bin/clangd"
	popd
	rm "$filename"
}

# Setup Tmux
setup_tmux() {
	log_info "Setting up Tmux..."
	install_package tmux || return 1
	copy_config "$DIST_ROOT/tmux/tmux.conf" $HOME/.tmux.conf || return 1
	copy_config "$DIST_ROOT/tmux/tmux.conf.local" $HOME/.tmux.conf.local || return 1
	copy_config "$DIST_ROOT/tmux/tmux.conf.debug" $HOME/.tmux.conf.debug || return 1
	log_success "Tmux setup completed"
}

# Setup Powerline
setup_powerline() {
	log_info "Setting up Powerline..."
	install_package powerline || return 1
	install_package powerline-fonts || return 1
	install_package python-pip || return 1

	# Add powerline to bashrc if not present
	if ! grep -q "powerline-daemon" $HOME/.bashrc; then
		log_info "Adding powerline to ~/.bashrc..."
		cat "$DIST_ROOT/powerline/bashrc" >>$HOME/.bashrc
		log_success "Powerline added to ~/.bashrc"
	else
		log_info "Powerline already configured in ~/.bashrc"
	fi

	# Install powerline-gitstatus
	log_info "Installing powerline-gitstatus..."
	if pip install powerline-gitstatus --user; then
		log_success "powerline-gitstatus installed"
	else
		log_error "Failed to install powerline-gitstatus"
		return 1
	fi

	# Configure powerline
	local POWERLINE_LOCAL_CONFIG=$HOME/.config/powerline/
	local POWERLINE_GLOBAL_CONFIG1=/etc/xdg/powerline/config_files/
	local POWERLINE_GLOBAL_CONFIG2=/etc/xdg/powerline/

	mkdir -p "$POWERLINE_LOCAL_CONFIG"

	# Try to copy from the first possible global config location
	if [ -d "$POWERLINE_GLOBAL_CONFIG1" ]; then
		log_info "Copying global powerline config from $POWERLINE_GLOBAL_CONFIG1..."
		sudo cp -r "$POWERLINE_GLOBAL_CONFIG1"/* "$POWERLINE_LOCAL_CONFIG"
	elif [ -d "$POWERLINE_GLOBAL_CONFIG2" ]; then
		log_info "Copying global powerline config from $POWERLINE_GLOBAL_CONFIG2..."
		sudo cp -r "$POWERLINE_GLOBAL_CONFIG2"/* "$POWERLINE_LOCAL_CONFIG"
	else
		log_warning "No global powerline config directory found, skipping global config copy"
	fi

	sudo chown "$USER:$USER" "$POWERLINE_LOCAL_CONFIG" -R

	# Copy custom powerline configuration
	log_info "Copying custom powerline configuration..."
	copy_config "$DIST_ROOT/powerline/colorschemes" "$POWERLINE_LOCAL_CONFIG" || return 1
	copy_config "$DIST_ROOT/powerline/colors.json" "$POWERLINE_LOCAL_CONFIG" || return 1
	copy_config "$DIST_ROOT/powerline/config.json" "$POWERLINE_LOCAL_CONFIG" || return 1
	copy_config "$DIST_ROOT/powerline/themes" "$POWERLINE_LOCAL_CONFIG" || return 1

	# Restart powerline daemon
	log_info "Restarting powerline daemon..."
	if powerline-daemon --replace; then
		log_success "Powerline daemon restarted"
	else
		log_error "Failed to restart powerline daemon"
		return 1
	fi

	log_success "Powerline setup completed"
}

# Setup GDB
setup_gdb() {
	log_info "Setting up GDB..."
	install_package gdb || return 1

	# Install pygments
	log_info "Installing pygments..."
	if pip install pygments --user; then
		log_success "pygments installed"
	else
		log_error "Failed to install pygments"
		return 1
	fi

	copy_config "$DIST_ROOT/gdb/gdbinit" $HOME/.gdbinit || return 1
	mkdir -p $HOME/.gdbinit.d
	log_success "GDB setup completed"
}

# Main setup function
main() {
	# If called with --neovim, only run the Neovim setup
	if [ "$1" = "--neovim" ]; then
		echo -e "${GREEN}\nRunning Neovim setup only...${RST}"
		setup_neovim || exit 1
		echo -e "${GREEN}\nNeovim setup completed.${RST}"
		return 0
	fi
	echo -e "${GREEN}\nSetting up Fedora...\n${RST}"

	echo -e "\033[1mVIM\033[0m"
	echo -e "${GREEN}==================================================================================${RST}"
	setup_vim || exit 1

	echo -e "\033[1mNeovim\033[0m"
	echo -e "${GREEN}==================================================================================${RST}"
	setup_neovim || exit 1

	echo -e "\033[1mTMUX\033[0m"
	echo -e "${GREEN}==================================================================================${RST}"
	setup_tmux || exit 1

	echo -e "\033[1mPOWERLINE\033[0m"
	echo -e "${GREEN}==================================================================================${RST}"
	setup_powerline || exit 1

	echo -e "\033[1mGDB\033[0m"
	echo -e "${GREEN}==================================================================================${RST}"
	setup_gdb || exit 1

	echo -e "${GREEN}\nAll setups completed successfully!${RST}"
}

main "$@"
