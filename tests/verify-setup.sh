#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
#  verify-setup.sh — Post-setup verification for Docker integration tests
#  Checks that all expected tools and configs are in place after `bash setup`.
#
#  Environment variables:
#    SKIP_NEOVIM=true    Skip neovim-related checks (clangd, tree-sitter, etc.)
# ─────────────────────────────────────────────────────────────────────────────

# Ensure ~/.local/bin and ~/.cargo/bin are in PATH
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

# ─── Colors (safe for non-TTY) ───────────────────────────────────────────────
RED=$(tput setaf 1 2>/dev/null || true)
GREEN=$(tput setaf 2 2>/dev/null || true)
YELLOW=$(tput setaf 3 2>/dev/null || true)
CYAN=$(tput setaf 6 2>/dev/null || true)
BOLD=$(tput bold 2>/dev/null || true)
RST=$(tput sgr0 2>/dev/null || true)

ERRORS=0
CHECKS=0

# ─── Assertion helpers ────────────────────────────────────────────────────────
check_command() {
	local cmd=$1
	CHECKS=$((CHECKS + 1))
	if command -v "$cmd" &>/dev/null; then
		echo -e "  ${GREEN}✅${RST} command: ${BOLD}${cmd}${RST}"
	else
		echo -e "  ${RED}❌${RST} command: ${BOLD}${cmd}${RST} — NOT FOUND"
		ERRORS=$((ERRORS + 1))
	fi
}

check_file() {
	local path=$1
	CHECKS=$((CHECKS + 1))
	if [ -e "$path" ]; then
		echo -e "  ${GREEN}✅${RST} file: $path"
	else
		echo -e "  ${RED}❌${RST} file: $path — MISSING"
		ERRORS=$((ERRORS + 1))
	fi
}

check_symlink() {
	local path=$1
	CHECKS=$((CHECKS + 1))
	if [ -L "$path" ]; then
		local target
		target=$(readlink -f "$path")
		if [ -x "$target" ]; then
			echo -e "  ${GREEN}✅${RST} symlink: $path → $target"
		else
			echo -e "  ${RED}❌${RST} symlink: $path → $target (target not executable)"
			ERRORS=$((ERRORS + 1))
		fi
	else
		echo -e "  ${RED}❌${RST} symlink: $path — NOT A SYMLINK"
		ERRORS=$((ERRORS + 1))
	fi
}

check_dir() {
	local path=$1
	CHECKS=$((CHECKS + 1))
	if [ -d "$path" ]; then
		echo -e "  ${GREEN}✅${RST} dir: $path"
	else
		echo -e "  ${RED}❌${RST} dir: $path — MISSING"
		ERRORS=$((ERRORS + 1))
	fi
}

# ─── Header ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${RST}"
echo -e "${CYAN}${BOLD}┃${RST}  🔍  ${BOLD}Post-Setup Verification${RST}"
echo -e "${CYAN}${BOLD}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${RST}"

# ─── Step 1: Vim ──────────────────────────────────────────────────────────────
echo ""
echo -e "  ${BOLD}[Vim]${RST}"
check_command vim
check_file "$HOME/.vimrc"
check_dir "$HOME/.vim"

# ─── Step 2: Neovim (skippable) ──────────────────────────────────────────────
if [ "${SKIP_NEOVIM:-false}" != "true" ]; then
	echo ""
	echo -e "  ${BOLD}[Neovim]${RST}"
	check_command nvim
	check_dir "$HOME/.config/nvim"
	check_dir "$HOME/.local/share/nvim/mason/bin"
	check_symlink "$HOME/.local/share/nvim/mason/bin/clangd"
	check_symlink "$HOME/.local/share/nvim/mason/bin/tree-sitter"
	check_file "$HOME/.local/share/nvim/mason/packages/cpptools/extension/debugAdapters/bin/OpenDebugAD7"
else
	echo ""
	echo -e "  ${YELLOW}⏭️  Skipping Neovim checks (SKIP_NEOVIM=true)${RST}"
fi

# ─── Step 3: Tmux ────────────────────────────────────────────────────────────
echo ""
echo -e "  ${BOLD}[Tmux]${RST}"
check_command tmux
check_file "$HOME/.tmux.conf"
check_file "$HOME/.tmux.conf.local"

# ─── Step 4: Powerline ───────────────────────────────────────────────────────
echo ""
echo -e "  ${BOLD}[Powerline]${RST}"
check_dir "$HOME/.config/powerline"
check_file "$HOME/.config/powerline/config.json"
check_file "$HOME/.config/powerline/colors.json"
# Check that powerline was added to bashrc
CHECKS=$((CHECKS + 1))
if grep -q "powerline" "$HOME/.bashrc" 2>/dev/null; then
	echo -e "  ${GREEN}✅${RST} ~/.bashrc contains powerline config"
else
	echo -e "  ${RED}❌${RST} ~/.bashrc missing powerline config"
	ERRORS=$((ERRORS + 1))
fi

# ─── Step 5: GDB ─────────────────────────────────────────────────────────────
echo ""
echo -e "  ${BOLD}[GDB]${RST}"
check_command gdb
check_file "$HOME/.gdbinit"
check_dir "$HOME/.gdbinit.d"

# ─── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${RST}"
echo -e "${CYAN}${BOLD}┃${RST}  📊  ${BOLD}Verification Results${RST}:  $((CHECKS - ERRORS))/${CHECKS} passed"
echo -e "${CYAN}${BOLD}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${RST}"
echo ""

if [ "$ERRORS" -eq 0 ]; then
	echo -e "  ${GREEN}${BOLD}✅ All verification checks passed!${RST}"
	echo ""
	exit 0
else
	echo -e "  ${RED}${BOLD}❌ ${ERRORS} check(s) failed.${RST}"
	echo ""
	exit 1
fi
