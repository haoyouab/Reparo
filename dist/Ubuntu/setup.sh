#!/bin/bash

# Color definitions
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
RST=$(tput sgr0)

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
	if sudo apt install $package -y; then
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
	copy_config "$DIST_ROOT/vim/vim" ~/.vim || return 1
	copy_config "$DIST_ROOT/vim/vimrc" ~/.vimrc || return 1
	log_success "Vim setup completed"
}

# Setup Neovim
setup_neovim() {
	local nvim_config_path="$HOME/.config"
	local nvim_package_path="$HOME/.local/share"
	local clangd_path="$HOME/.local/share/nvim/mason/packages/clangd"

	sudo apt install git curl -y
	mkdir -p $nvim_config_path
	mkdir -p $clangd_path
	# copy_config "$DIST_ROOT/nvim" $HOME/.config || return 1
	rm -rf $HOME/.config/nvim/
	git clone https://github.com/haoyouab/nvim.git $HOME/.config/nvim || return 1

	# Download neovim from GitHub latest release
	log_info "Downloading neovim from GitHub latest release..."
	local api_url="https://api.github.com/repos/neovim/neovim/releases/latest"
	local download_url=$(curl -s $api_url | grep "browser_download_url.*nvim-linux-x86_64.*\.tar\.gz" | head -1 | cut -d '"' -f 4)
	if [ -z "$download_url" ]; then
		log_error "Failed to find neovim download URL"
		return 1
	fi
	local filename=$(basename "$download_url")
	curl -L $download_url -o "$filename"
	log_success "neovim downloaded as $filename"

	# Extract neovim to ~/.local
	mkdir -p ~/.local
	tar -xzf "$filename" -C ~/.local --strip-components=1
	rm "$filename"

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
	copy_config "$DIST_ROOT/tmux/tmux.conf" ~/.tmux.conf || return 1
	copy_config "$DIST_ROOT/tmux/tmux.conf.local" ~/.tmux.conf.local || return 1
	copy_config "$DIST_ROOT/tmux/tmux.conf.debug" ~/.tmux.conf.debug || return 1
	log_success "Tmux setup completed"
}

# Setup Powerline
setup_powerline() {
	log_info "Setting up Powerline..."
	install_package powerline || return 1
	install_package fonts-powerline || return 1
	install_package python3-pip || return 1

	# Add powerline to bashrc if not present
	if ! grep -q "powerline-daemon" ~/.bashrc; then
		log_info "Adding powerline to ~/.bashrc..."
		# Determine the correct powerline script path
		local powerline_script_path=""
		if [ -f "/usr/share/powerline/bash/powerline.sh" ]; then
			powerline_script_path="/usr/share/powerline/bash/powerline.sh"
		elif [ -f "/usr/share/powerline/bindings/bash/powerline.sh" ]; then
			powerline_script_path="/usr/share/powerline/bindings/bash/powerline.sh"
		else
			log_error "Powerline script not found in expected locations"
			return 1
		fi
		# Copy and modify the bashrc template
		sed "s|POWERLINE_SCRIPT=/usr/share/powerline/bash/powerline.sh|POWERLINE_SCRIPT=$powerline_script_path|" "$DIST_ROOT/powerline/bashrc" >>~/.bashrc
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
	local POWERLINE_LOCAL_CONFIG=~/.config/powerline/
	local POWERLINE_GLOBAL_CONFIG=/usr/share/powerline/config_files/
	mkdir -p "$POWERLINE_LOCAL_CONFIG"
	sudo cp -r "$POWERLINE_GLOBAL_CONFIG"/* "$POWERLINE_LOCAL_CONFIG"
	sudo chown "$USER:$USER" "$POWERLINE_LOCAL_CONFIG" -R
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

	copy_config "$DIST_ROOT/gdb/gdbinit" ~/.gdbinit || return 1
	mkdir -p ~/.gdbinit.d
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
	log_info "Updating package list..."
	if sudo apt update; then
		log_success "Package list updated"
	else
		log_error "Failed to update package list"
		return 1
	fi

	echo -e "${GREEN}\nSetting up Ubuntu...\n${RST}"

	echo -e "\033[1mVIM\033[0m"
	echo -e "${GREEN}==================================================================================${RST}"
	setup_vim || exit 1

	echo -e "\033[1mGDB\033[0m"
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
