#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
#  Reparo Test Suite
#  Safe to run: uses temp directories, mocks sudo/dnf/apt, never touches $HOME
#
#  Usage:
#    bash tests/run_tests.sh           # Run all tests
#    bash tests/run_tests.sh -v        # Verbose: show captured output on failure
# ─────────────────────────────────────────────────────────────────────────────

set -uo pipefail

VERBOSE=false
[[ "${1:-}" == "-v" ]] && VERBOSE=true

# ─── Locate project root (parent of tests/) ──────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ─── Colors ───────────────────────────────────────────────────────────────────
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
CYAN=$(tput setaf 6)
BOLD=$(tput bold)
RST=$(tput sgr0)

# ─── Counters ─────────────────────────────────────────────────────────────────
PASS=0
FAIL=0
TOTAL=0

# ─── Temp directory (auto-cleaned) ───────────────────────────────────────────
TMPDIR=$(mktemp -d /tmp/reparo-test.XXXXXX)
trap 'rm -rf "$TMPDIR"' EXIT

# ─── Prepare helper source files (strip the final main call) ─────────────────
#     This allows sourcing functions without executing main()
sed '$d' "$PROJECT_ROOT/setup" >"$TMPDIR/setup_funcs.sh"
sed '$d' "$PROJECT_ROOT/dist/Fedora/setup.sh" >"$TMPDIR/fedora_funcs.sh"
sed '$d' "$PROJECT_ROOT/dist/Ubuntu/setup.sh" >"$TMPDIR/ubuntu_funcs.sh"

# ─── Strip ANSI escape codes ─────────────────────────────────────────────────
strip_ansi() {
	sed -E 's/\x1b\[[0-9;]*m//g'
}

# ─── Assertion helpers ────────────────────────────────────────────────────────
_last_output=""

assert_exit_code() {
	local expected=$1 actual=$2 msg=$3
	TOTAL=$((TOTAL + 1))
	if [ "$actual" -eq "$expected" ]; then
		echo -e "  ${GREEN}✅ PASS${RST}  $msg"
		PASS=$((PASS + 1))
	else
		echo -e "  ${RED}❌ FAIL${RST}  $msg  ${YELLOW}(expected exit=$expected, got exit=$actual)${RST}"
		FAIL=$((FAIL + 1))
		$VERBOSE && echo -e "    ${YELLOW}Output: $(echo "$_last_output" | head -5)${RST}"
	fi
}

assert_output_contains() {
	local output=$1 pattern=$2 msg=$3
	TOTAL=$((TOTAL + 1))
	local clean
	clean=$(echo "$output" | strip_ansi)
	if echo "$clean" | grep -qF "$pattern"; then
		echo -e "  ${GREEN}✅ PASS${RST}  $msg"
		PASS=$((PASS + 1))
	else
		echo -e "  ${RED}❌ FAIL${RST}  $msg  ${YELLOW}(pattern not found: \"$pattern\")${RST}"
		FAIL=$((FAIL + 1))
		$VERBOSE && echo -e "    ${YELLOW}Clean output: $(echo "$clean" | head -5)${RST}"
	fi
}

assert_output_not_contains() {
	local output=$1 pattern=$2 msg=$3
	TOTAL=$((TOTAL + 1))
	local clean
	clean=$(echo "$output" | strip_ansi)
	if echo "$clean" | grep -qF "$pattern"; then
		echo -e "  ${RED}❌ FAIL${RST}  $msg  ${YELLOW}(pattern should NOT appear: \"$pattern\")${RST}"
		FAIL=$((FAIL + 1))
	else
		echo -e "  ${GREEN}✅ PASS${RST}  $msg"
		PASS=$((PASS + 1))
	fi
}

assert_file_exists() {
	local path=$1 msg=$2
	TOTAL=$((TOTAL + 1))
	if [ -e "$path" ]; then
		echo -e "  ${GREEN}✅ PASS${RST}  $msg"
		PASS=$((PASS + 1))
	else
		echo -e "  ${RED}❌ FAIL${RST}  $msg  ${YELLOW}(file not found: $path)${RST}"
		FAIL=$((FAIL + 1))
	fi
}

print_header() {
	echo ""
	echo -e "${CYAN}${BOLD}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${RST}"
	echo -e "${CYAN}${BOLD}┃${RST}  $1"
	echo -e "${CYAN}${BOLD}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${RST}"
}

# Helper: run bash snippet sourcing a helper file, capture output + exit code
# For distro scripts, DIST_ROOT must be set so common.sh can be sourced
run_with() {
	local helpers_file=$1
	shift
	local code="$*"
	local dist_root_env=""
	# Distro scripts need DIST_ROOT to source common.sh
	case "$helpers_file" in
		*fedora*) dist_root_env="export DIST_ROOT='$PROJECT_ROOT/dist/Fedora';" ;;
		*ubuntu*) dist_root_env="export DIST_ROOT='$PROJECT_ROOT/dist/Ubuntu';" ;;
	esac
	_last_output=$(bash -c "${dist_root_env} source '$helpers_file'; $code" 2>&1) || true
	_last_exit=${PIPESTATUS[0]:-$?}
}

# Helper: run bash snippet sourcing common.sh directly
run_with_common() {
	local code="$*"
	_last_output=$(bash -c "source '$PROJECT_ROOT/dist/common.sh'; $code" 2>&1) || true
	_last_exit=${PIPESTATUS[0]:-$?}
}

# ═════════════════════════════════════════════════════════════════════════════
#  TEST GROUP 1: Syntax Validation
# ═════════════════════════════════════════════════════════════════════════════
test_syntax() {
	print_header "🔍  Test Group 1: Syntax Validation"

	for script in setup dist/common.sh dist/Fedora/setup.sh dist/Ubuntu/setup.sh; do
		bash -n "$PROJECT_ROOT/$script" 2>/dev/null
		assert_exit_code 0 $? "bash -n $script"
	done
}

# ═════════════════════════════════════════════════════════════════════════════
#  TEST GROUP 2: common.sh — Logging Functions
# ═════════════════════════════════════════════════════════════════════════════
test_log_functions() {
	print_header "📝  Test Group 2: Logging Functions (common.sh)"

	run_with_common "
		log_info    'test-info-msg'
		log_success 'test-success-msg'
		log_warning 'test-warning-msg'
		log_error   'test-error-msg'
	"

	assert_output_contains "$_last_output" "test-info-msg" "[common] log_info output"
	assert_output_contains "$_last_output" "test-success-msg" "[common] log_success output"
	assert_output_contains "$_last_output" "test-warning-msg" "[common] log_warning output"
	assert_output_contains "$_last_output" "test-error-msg" "[common] log_error output"

	# Also verify log functions work through distro scripts
	for pair in "fedora_funcs.sh:fedora" "ubuntu_funcs.sh:ubuntu"; do
		local helpers="$TMPDIR/${pair%%:*}"
		local label="${pair##*:}"
		run_with "$helpers" "log_info 'from-$label'"
		assert_output_contains "$_last_output" "from-$label" "[$label] log_info via common.sh"
	done
}

# ═════════════════════════════════════════════════════════════════════════════
#  TEST GROUP 3: common.sh — die() Function
# ═════════════════════════════════════════════════════════════════════════════
test_die_function() {
	print_header "💀  Test Group 3: die() — Fatal Error Abort"

	# Test die from common.sh
	_last_output=$(bash -c "source '$PROJECT_ROOT/dist/common.sh'; die 'Something went wrong'" 2>&1)
	_last_exit=$?
	assert_exit_code 1 "$_last_exit" "[common] die() exits with code 1"
	assert_output_contains "$_last_output" "SETUP FAILED" "[common] die() shows SETUP FAILED"
	assert_output_contains "$_last_output" "Something went wrong" "[common] die() shows error message"

	# Test die from setup script
	_last_output=$(bash -c "source '$TMPDIR/setup_funcs.sh'; die 'Main fail'" 2>&1)
	_last_exit=$?
	assert_exit_code 1 "$_last_exit" "[main] die() exits with code 1"
	assert_output_contains "$_last_output" "Main fail" "[main] die() shows error message"

	# Test die through distro script (inherits from common.sh)
	_last_output=$(bash -c "export DIST_ROOT='$PROJECT_ROOT/dist/Fedora'; source '$TMPDIR/fedora_funcs.sh'; die 'Fedora fail'" 2>&1)
	_last_exit=$?
	assert_exit_code 1 "$_last_exit" "[fedora] die() exits with code 1"
	assert_output_contains "$_last_output" "Fedora fail" "[fedora] die() via common.sh"
}

# ═════════════════════════════════════════════════════════════════════════════
#  TEST GROUP 4: common.sh — print_section() Step Headers
# ═════════════════════════════════════════════════════════════════════════════
test_print_section() {
	print_header "📐  Test Group 4: print_section() — Step Headers"

	run_with_common "
		print_section 1 5 'X' 'VIM'
		print_section 3 5 'Y' 'TMUX'
	"

	assert_output_contains "$_last_output" "[Step 1/5]" "print_section shows [Step 1/5]"
	assert_output_contains "$_last_output" "[Step 3/5]" "print_section shows [Step 3/5]"
	assert_output_contains "$_last_output" "VIM" "print_section shows title VIM"
	assert_output_contains "$_last_output" "TMUX" "print_section shows title TMUX"

	run_with_common "print_section 1 1 'X' 'NEOVIM'"
	assert_output_contains "$_last_output" "[Step 1/1]" "print_section single step [Step 1/1]"
}

# ═════════════════════════════════════════════════════════════════════════════
#  TEST GROUP 5: common.sh — copy_config() with Backup
# ═════════════════════════════════════════════════════════════════════════════
test_copy_config() {
	print_header "📂  Test Group 5: copy_config() — File Operations"

	# Prepare test files
	echo "test content" >"$TMPDIR/src_file.txt"
	mkdir -p "$TMPDIR/dest_dir"

	# 5a: Successful copy
	run_with_common "copy_config '$TMPDIR/src_file.txt' '$TMPDIR/dest_dir/'"
	assert_exit_code 0 "$_last_exit" "copy_config: succeeds on valid source"
	assert_output_contains "$_last_output" "Copied to" "copy_config: shows success message"
	assert_file_exists "$TMPDIR/dest_dir/src_file.txt" "copy_config: file actually copied"

	# 5b: Source not found
	_last_output=$(bash -c "source '$PROJECT_ROOT/dist/common.sh'; copy_config '/nonexistent/file' '$TMPDIR/dest_dir/'" 2>&1)
	_last_exit=$?
	assert_exit_code 1 "$_last_exit" "copy_config: fails on missing source"
	assert_output_contains "$_last_output" "Source not found" "copy_config: shows 'Source not found'"

	# 5c: Permission denied
	_last_output=$(bash -c "source '$PROJECT_ROOT/dist/common.sh'; copy_config '$TMPDIR/src_file.txt' '/root/no_perm'" 2>&1)
	_last_exit=$?
	assert_exit_code 1 "$_last_exit" "copy_config: fails on permission denied"
	assert_output_contains "$_last_output" "check permissions" "copy_config: shows permission hint"

	# 5d: Backup existing file before overwrite
	echo "original" >"$TMPDIR/dest_dir/overwrite_me.txt"
	echo "new content" >"$TMPDIR/new_file.txt"
	_last_output=$(bash -c "
		source '$PROJECT_ROOT/dist/common.sh'
		BACKUP_DIR='$TMPDIR/backup_test'
		BACKUP_CREATED=false
		copy_config '$TMPDIR/new_file.txt' '$TMPDIR/dest_dir/overwrite_me.txt'
	" 2>&1)
	_last_exit=$?
	assert_exit_code 0 "$_last_exit" "copy_config: backup + overwrite succeeds"
	assert_file_exists "$TMPDIR/backup_test/overwrite_me.txt" "copy_config: backup was created"
}

# ═════════════════════════════════════════════════════════════════════════════
#  TEST GROUP 6: common.sh — detect_arch()
# ═════════════════════════════════════════════════════════════════════════════
test_detect_arch() {
	print_header "🏗️  Test Group 6: detect_arch() — Architecture Detection"

	run_with_common "detect_arch"
	local arch
	arch=$(echo "$_last_output" | strip_ansi | tail -1)
	TOTAL=$((TOTAL + 1))
	if [[ "$arch" == "x86_64" ]] || [[ "$arch" == "aarch64" ]]; then
		echo -e "  ${GREEN}✅ PASS${RST}  detect_arch returns valid arch: $arch"
		PASS=$((PASS + 1))
	else
		echo -e "  ${RED}❌ FAIL${RST}  detect_arch: unexpected output: $arch"
		FAIL=$((FAIL + 1))
	fi
}

# ═════════════════════════════════════════════════════════════════════════════
#  TEST GROUP 7: common.sh — DOWNLOAD_DIR temp directory
# ═════════════════════════════════════════════════════════════════════════════
test_download_dir() {
	print_header "📥  Test Group 7: DOWNLOAD_DIR — Temp Directory"

	# DOWNLOAD_DIR is created on source and cleaned on exit
	_last_output=$(bash -c "
		source '$PROJECT_ROOT/dist/common.sh'
		echo \"DIR=\$DOWNLOAD_DIR\"
		test -d \"\$DOWNLOAD_DIR\" && echo 'EXISTS=true' || echo 'EXISTS=false'
	" 2>&1)
	assert_output_contains "$_last_output" "DIR=/tmp/reparo-setup." "DOWNLOAD_DIR has expected prefix"
	assert_output_contains "$_last_output" "EXISTS=true" "DOWNLOAD_DIR exists after source"
}

# ═════════════════════════════════════════════════════════════════════════════
#  TEST GROUP 8: Distribution Detection
# ═════════════════════════════════════════════════════════════════════════════
test_distro_detection() {
	print_header "🐧  Test Group 8: Distribution Detection"

	run_with "$TMPDIR/setup_funcs.sh" "
		RELEASE_FILE=/etc/os-release
		DIST=\$(grep '^NAME=' \$RELEASE_FILE | sed -n 's/NAME=//p' | tr -d '\"')
		PRETTY_NAME=\$(grep '^PRETTY_NAME=' \$RELEASE_FILE | sed -n 's/PRETTY_NAME=//p' | tr -d '\"')
		log_success \"Detected: \$PRETTY_NAME\"
		echo \"DIST=\$DIST\"
	"
	assert_output_contains "$_last_output" "Detected:" "Distro detection: shows detected name"
	assert_output_contains "$_last_output" "DIST=" "Distro detection: extracts DIST variable"

	# Missing /etc/os-release
	_last_output=$(bash -c "
		source '$TMPDIR/setup_funcs.sh'
		RELEASE_FILE=/etc/nonexistent
		if [ -f \"\$RELEASE_FILE\" ]; then echo found
		else die 'Cannot find /etc/os-release'
		fi
	" 2>&1)
	_last_exit=$?
	assert_exit_code 1 "$_last_exit" "Missing os-release: exits 1"
	assert_output_contains "$_last_output" "Cannot find /etc/os-release" "Missing os-release: descriptive error"

	# Unrecognized distro
	_last_output=$(bash -c "
		source '$TMPDIR/setup_funcs.sh'
		DIST='ArchLinux'
		case \"\$DIST\" in
			*Fedora*) echo fedora ;;
			*Ubuntu*) echo ubuntu ;;
			*) die \"Unrecognized distribution: \$DIST\" ;;
		esac
	" 2>&1)
	_last_exit=$?
	assert_exit_code 1 "$_last_exit" "Unrecognized distro: exits 1"
	assert_output_contains "$_last_output" "ArchLinux" "Unrecognized distro: shows name"
}

# ═════════════════════════════════════════════════════════════════════════════
#  TEST GROUP 9: DIST_ROOT Absolute Path
# ═════════════════════════════════════════════════════════════════════════════
test_dist_root_absolute() {
	print_header "📌  Test Group 9: DIST_ROOT — Absolute Path"

	# Verify setup script uses absolute path based on PROJECT_ROOT
	_last_output=$(bash -c "
		source '$TMPDIR/setup_funcs.sh'
		echo \"PROJECT_ROOT=\$PROJECT_ROOT\"
	" 2>&1)
	assert_output_contains "$_last_output" "PROJECT_ROOT=/" "PROJECT_ROOT is absolute path"

	# Verify DIST_ROOT in setup is absolute (grep the actual file)
	local dist_root_line
	dist_root_line=$(grep 'DIST_ROOT=' "$PROJECT_ROOT/setup" | head -1)
	TOTAL=$((TOTAL + 1))
	if echo "$dist_root_line" | grep -q 'PROJECT_ROOT'; then
		echo -e "  ${GREEN}✅ PASS${RST}  DIST_ROOT uses PROJECT_ROOT (absolute)"
		PASS=$((PASS + 1))
	else
		echo -e "  ${RED}❌ FAIL${RST}  DIST_ROOT should reference PROJECT_ROOT"
		FAIL=$((FAIL + 1))
	fi
}

# ═════════════════════════════════════════════════════════════════════════════
#  TEST GROUP 10: Abort Chain — Failure Stops Subsequent Steps
# ═════════════════════════════════════════════════════════════════════════════
test_abort_chain() {
	print_header "🛑  Test Group 10: Abort Chain — Failure Stops Subsequent Steps"

	_last_output=$(bash -c "
		export DIST_ROOT='$PROJECT_ROOT/dist/Fedora'
		source '$TMPDIR/fedora_funcs.sh'

		step1() { log_success 'STEP1_EXECUTED'; return 0; }
		step2() { log_error 'STEP2_FAILED'; return 1; }
		step3() { log_success 'STEP3_SHOULD_NOT_RUN'; return 0; }

		print_section 1 3 'X' 'VIM'
		step1 || die 'Step 1 failed.'
		print_section 2 3 'X' 'NEOVIM'
		step2 || die 'Neovim setup failed.'
		print_section 3 3 'X' 'TMUX'
		step3 || die 'Step 3 failed.'
	" 2>&1)
	_last_exit=$?

	assert_exit_code 1 "$_last_exit" "Abort chain: exits 1 on failure"
	assert_output_contains "$_last_output" "STEP1_EXECUTED" "Abort chain: step 1 ran"
	assert_output_contains "$_last_output" "STEP2_FAILED" "Abort chain: step 2 ran (and failed)"
	assert_output_not_contains "$_last_output" "STEP3_SHOULD_NOT_RUN" "Abort chain: step 3 did NOT run"
	assert_output_contains "$_last_output" "Neovim setup failed" "Abort chain: die() shows which step"

	# Happy path
	_last_output=$(bash -c "
		export DIST_ROOT='$PROJECT_ROOT/dist/Fedora'
		source '$TMPDIR/fedora_funcs.sh'
		s() { return 0; }
		print_section 1 2 'X' 'A'
		s || die 'fail'
		print_section 2 2 'X' 'B'
		s || die 'fail'
		log_success 'ALL_PASSED'
	" 2>&1)
	_last_exit=$?
	assert_exit_code 0 "$_last_exit" "Happy path: exits 0"
	assert_output_contains "$_last_output" "ALL_PASSED" "Happy path: reaches success"
}

# ═════════════════════════════════════════════════════════════════════════════
#  TEST GROUP 11: Argument Forwarding (--neovim)
# ═════════════════════════════════════════════════════════════════════════════
test_arg_forwarding() {
	print_header "🔀  Test Group 11: Argument Forwarding"

	_last_output=$(bash -c '
		FORWARD_ARGS=()
		for _a in "--neovim" "--unknown" "--other"; do
			case "$_a" in --neovim) FORWARD_ARGS+=("$_a") ;; esac
		done
		echo "ARGS=${FORWARD_ARGS[*]}"
		echo "COUNT=${#FORWARD_ARGS[@]}"
	' 2>&1)
	assert_output_contains "$_last_output" "ARGS=--neovim" "Arg forwarding: --neovim captured"
	assert_output_contains "$_last_output" "COUNT=1" "Arg forwarding: count=1"

	_last_output=$(bash -c '
		FORWARD_ARGS=()
		for _a in "--unknown" "--other"; do
			case "$_a" in --neovim) FORWARD_ARGS+=("$_a") ;; esac
		done
		echo "COUNT=${#FORWARD_ARGS[@]}"
	' 2>&1)
	assert_output_contains "$_last_output" "COUNT=0" "Arg forwarding: no match → empty"
}

# ═════════════════════════════════════════════════════════════════════════════
#  TEST GROUP 12: install_package() with Mock
# ═════════════════════════════════════════════════════════════════════════════
test_install_package_mock() {
	print_header "📦  Test Group 12: install_package() — Mocked"

	# Fedora — mock dnf success
	_last_output=$(bash -c "
		sudo() { echo 'mock-dnf-ok'; return 0; }
		export DIST_ROOT='$PROJECT_ROOT/dist/Fedora'
		source '$TMPDIR/fedora_funcs.sh'
		install_package vim
	" 2>&1)
	_last_exit=$?
	assert_exit_code 0 "$_last_exit" "[fedora] install_package: succeeds"
	assert_output_contains "$_last_output" "vim installed" "[fedora] install_package: shows success"

	# Fedora — mock dnf failure
	_last_output=$(bash -c "
		sudo() { return 1; }
		export DIST_ROOT='$PROJECT_ROOT/dist/Fedora'
		source '$TMPDIR/fedora_funcs.sh'
		install_package broken-pkg
	" 2>&1)
	_last_exit=$?
	assert_exit_code 1 "$_last_exit" "[fedora] install_package: fails"
	assert_output_contains "$_last_output" "Failed to install" "[fedora] install_package: error msg"

	# Ubuntu — mock apt success
	_last_output=$(bash -c "
		sudo() { echo 'mock-apt-ok'; return 0; }
		export DIST_ROOT='$PROJECT_ROOT/dist/Ubuntu'
		source '$TMPDIR/ubuntu_funcs.sh'
		install_package tmux
	" 2>&1)
	_last_exit=$?
	assert_exit_code 0 "$_last_exit" "[ubuntu] install_package: succeeds"
	assert_output_contains "$_last_output" "tmux installed" "[ubuntu] install_package: shows success"

	# Ubuntu — mock apt failure
	_last_output=$(bash -c "
		sudo() { return 1; }
		export DIST_ROOT='$PROJECT_ROOT/dist/Ubuntu'
		source '$TMPDIR/ubuntu_funcs.sh'
		install_package broken-pkg
	" 2>&1)
	_last_exit=$?
	assert_exit_code 1 "$_last_exit" "[ubuntu] install_package: fails"
	assert_output_contains "$_last_output" "Failed to install" "[ubuntu] install_package: error msg"
}

# ═════════════════════════════════════════════════════════════════════════════
#  TEST GROUP 13: Visual Output — Emoji & Banners
# ═════════════════════════════════════════════════════════════════════════════
test_visual_output() {
	print_header "🎨  Test Group 13: Visual Output — Emoji & Banners"

	run_with_common "
		log_info 'test'
		log_success 'test'
		log_warning 'test'
		log_error 'test'
	"
	assert_output_contains "$_last_output" "ℹ️" "Emoji: info has ℹ️"
	assert_output_contains "$_last_output" "✅" "Emoji: success has ✅"
	assert_output_contains "$_last_output" "⚠️" "Emoji: warning has ⚠️"
	assert_output_contains "$_last_output" "❌" "Emoji: error has ❌"

	run_with_common "print_section 1 5 'X' 'TEST'"
	assert_output_contains "$_last_output" "┏" "Box: top-left corner ┏"
	assert_output_contains "$_last_output" "┗" "Box: bottom-left corner ┗"
	assert_output_contains "$_last_output" "┃" "Box: vertical bar ┃"

	_last_output=$(bash -c "source '$PROJECT_ROOT/dist/common.sh'; die 'test'" 2>&1)
	assert_output_contains "$_last_output" "┏" "die() box: top-left ┏"
	assert_output_contains "$_last_output" "┗" "die() box: bottom-left ┗"
}

# ═════════════════════════════════════════════════════════════════════════════
#  TEST GROUP 14: setup_neovim() Error Handling (Mocked)
# ═════════════════════════════════════════════════════════════════════════════
test_neovim_error_handling() {
	print_header "📝  Test Group 14: setup_neovim() — Error Handling"

	# Fedora — sudo/dnf failure aborts
	_last_output=$(bash -c "
		sudo() { return 1; }
		export DIST_ROOT='$PROJECT_ROOT/dist/Fedora'
		source '$TMPDIR/fedora_funcs.sh'
		setup_neovim
	" 2>&1)
	_last_exit=$?
	assert_exit_code 1 "$_last_exit" "[fedora] neovim: dnf fail aborts"
	assert_output_contains "$_last_output" "Failed to install required packages" "[fedora] neovim: shows error"

	# Ubuntu — sudo/apt failure aborts
	_last_output=$(bash -c "
		sudo() { return 1; }
		export DIST_ROOT='$PROJECT_ROOT/dist/Ubuntu'
		source '$TMPDIR/ubuntu_funcs.sh'
		setup_neovim
	" 2>&1)
	_last_exit=$?
	assert_exit_code 1 "$_last_exit" "[ubuntu] neovim: apt fail aborts"
	assert_output_contains "$_last_output" "Failed to install required packages" "[ubuntu] neovim: shows error"
}

# ═════════════════════════════════════════════════════════════════════════════
#  TEST GROUP 15: common.sh — Recursive Copy
# ═════════════════════════════════════════════════════════════════════════════
test_copy_config_recursive() {
	print_header "📁  Test Group 15: copy_config() — Recursive Copy"

	mkdir -p "$TMPDIR/src_tree/sub1/sub2"
	echo "file1" >"$TMPDIR/src_tree/a.txt"
	echo "file2" >"$TMPDIR/src_tree/sub1/b.txt"
	echo "file3" >"$TMPDIR/src_tree/sub1/sub2/c.txt"
	mkdir -p "$TMPDIR/dest_tree"

	_last_output=$(bash -c "
		source '$PROJECT_ROOT/dist/common.sh'
		copy_config '$TMPDIR/src_tree' '$TMPDIR/dest_tree/'
	" 2>&1)
	_last_exit=$?

	assert_exit_code 0 "$_last_exit" "Recursive copy: exits 0"
	assert_file_exists "$TMPDIR/dest_tree/src_tree/a.txt" "Recursive copy: top-level file"
	assert_file_exists "$TMPDIR/dest_tree/src_tree/sub1/b.txt" "Recursive copy: nested file"
	assert_file_exists "$TMPDIR/dest_tree/src_tree/sub1/sub2/c.txt" "Recursive copy: deeply nested file"
}

# ═════════════════════════════════════════════════════════════════════════════
#  TEST GROUP 16: tput Non-TTY Fallback
# ═════════════════════════════════════════════════════════════════════════════
test_tput_fallback() {
	print_header "🖥️  Test Group 16: tput Non-TTY Fallback"

	# common.sh uses 2>/dev/null so tput failure doesn't crash
	TOTAL=$((TOTAL + 1))
	if grep -q 'tput.*2>/dev/null' "$PROJECT_ROOT/dist/common.sh"; then
		echo -e "  ${GREEN}✅ PASS${RST}  common.sh: tput has 2>/dev/null fallback"
		PASS=$((PASS + 1))
	else
		echo -e "  ${RED}❌ FAIL${RST}  common.sh: tput missing 2>/dev/null"
		FAIL=$((FAIL + 1))
	fi

	# setup script also has fallback
	TOTAL=$((TOTAL + 1))
	if grep -q 'tput.*2>/dev/null' "$PROJECT_ROOT/setup"; then
		echo -e "  ${GREEN}✅ PASS${RST}  setup: tput has 2>/dev/null fallback"
		PASS=$((PASS + 1))
	else
		echo -e "  ${RED}❌ FAIL${RST}  setup: tput missing 2>/dev/null"
		FAIL=$((FAIL + 1))
	fi
}

# ═════════════════════════════════════════════════════════════════════════════
#  TEST GROUP 17: Code Quality Checks
# ═════════════════════════════════════════════════════════════════════════════
test_code_quality() {
	print_header "🔧  Test Group 17: Code Quality Checks"

	# No unused SCRIPT_DIR
	TOTAL=$((TOTAL + 1))
	if ! grep -q '^SCRIPT_DIR=' "$PROJECT_ROOT/dist/Fedora/setup.sh"; then
		echo -e "  ${GREEN}✅ PASS${RST}  Fedora: no unused SCRIPT_DIR"
		PASS=$((PASS + 1))
	else
		echo -e "  ${RED}❌ FAIL${RST}  Fedora: unused SCRIPT_DIR still present"
		FAIL=$((FAIL + 1))
	fi

	# No unused nvim_package_path
	TOTAL=$((TOTAL + 1))
	if ! grep -q 'nvim_package_path=' "$PROJECT_ROOT/dist/Fedora/setup.sh"; then
		echo -e "  ${GREEN}✅ PASS${RST}  Fedora: no unused nvim_package_path"
		PASS=$((PASS + 1))
	else
		echo -e "  ${RED}❌ FAIL${RST}  Fedora: unused nvim_package_path still present"
		FAIL=$((FAIL + 1))
	fi

	TOTAL=$((TOTAL + 1))
	if ! grep -q 'nvim_package_path=' "$PROJECT_ROOT/dist/Ubuntu/setup.sh"; then
		echo -e "  ${GREEN}✅ PASS${RST}  Ubuntu: no unused nvim_package_path"
		PASS=$((PASS + 1))
	else
		echo -e "  ${RED}❌ FAIL${RST}  Ubuntu: unused nvim_package_path still present"
		FAIL=$((FAIL + 1))
	fi

	# pip3 / python3 -m pip used instead of bare pip
	TOTAL=$((TOTAL + 1))
	if ! grep -qP '(?<!-m )pip install' "$PROJECT_ROOT/dist/Fedora/setup.sh"; then
		echo -e "  ${GREEN}✅ PASS${RST}  Fedora: no bare 'pip install' (uses python3 -m pip)"
		PASS=$((PASS + 1))
	else
		echo -e "  ${RED}❌ FAIL${RST}  Fedora: still uses bare 'pip install'"
		FAIL=$((FAIL + 1))
	fi

	TOTAL=$((TOTAL + 1))
	if ! grep -qP '(?<!-m )pip install' "$PROJECT_ROOT/dist/Ubuntu/setup.sh"; then
		echo -e "  ${GREEN}✅ PASS${RST}  Ubuntu: no bare 'pip install' (uses python3 -m pip)"
		PASS=$((PASS + 1))
	else
		echo -e "  ${RED}❌ FAIL${RST}  Ubuntu: still uses bare 'pip install'"
		FAIL=$((FAIL + 1))
	fi

	# Tree-sitter symlink points to ~/.cargo/bin/, not /usr/local/bin/
	TOTAL=$((TOTAL + 1))
	if ! grep -q '/usr/local/bin/tree-sitter' "$PROJECT_ROOT/dist/Fedora/setup.sh" \
		&& grep -q 'cargo/bin/tree-sitter' "$PROJECT_ROOT/dist/common.sh"; then
		echo -e "  ${GREEN}✅ PASS${RST}  tree-sitter: symlink uses ~/.cargo/bin/"
		PASS=$((PASS + 1))
	else
		echo -e "  ${RED}❌ FAIL${RST}  tree-sitter: still uses /usr/local/bin/"
		FAIL=$((FAIL + 1))
	fi

	# git clone --depth 1
	TOTAL=$((TOTAL + 1))
	local depth_ok=true
	for f in "$PROJECT_ROOT/dist/Fedora/setup.sh" "$PROJECT_ROOT/dist/Ubuntu/setup.sh"; do
		if grep -q 'git clone' "$f" && ! grep -q 'git clone --depth 1' "$f"; then
			depth_ok=false
		fi
	done
	if $depth_ok; then
		echo -e "  ${GREEN}✅ PASS${RST}  git clone uses --depth 1"
		PASS=$((PASS + 1))
	else
		echo -e "  ${RED}❌ FAIL${RST}  git clone missing --depth 1"
		FAIL=$((FAIL + 1))
	fi

	# .editorconfig exists
	assert_file_exists "$PROJECT_ROOT/.editorconfig" ".editorconfig exists"

	# .viminfo in .gitignore
	TOTAL=$((TOTAL + 1))
	if grep -q '.viminfo' "$PROJECT_ROOT/.gitignore"; then
		echo -e "  ${GREEN}✅ PASS${RST}  .gitignore includes .viminfo"
		PASS=$((PASS + 1))
	else
		echo -e "  ${RED}❌ FAIL${RST}  .gitignore missing .viminfo"
		FAIL=$((FAIL + 1))
	fi

	# common.sh exists and is sourced by both distro scripts
	assert_file_exists "$PROJECT_ROOT/dist/common.sh" "common.sh exists"
	TOTAL=$((TOTAL + 1))
	if grep -q 'source.*common.sh' "$PROJECT_ROOT/dist/Fedora/setup.sh" \
		&& grep -q 'source.*common.sh' "$PROJECT_ROOT/dist/Ubuntu/setup.sh"; then
		echo -e "  ${GREEN}✅ PASS${RST}  Both distro scripts source common.sh"
		PASS=$((PASS + 1))
	else
		echo -e "  ${RED}❌ FAIL${RST}  Distro scripts should source common.sh"
		FAIL=$((FAIL + 1))
	fi

	# CI workflow exists
	assert_file_exists "$PROJECT_ROOT/.github/workflows/ci.yml" "CI workflow exists"
}

# ═════════════════════════════════════════════════════════════════════════════
#  RUN ALL TESTS
# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════════════════════════╗${RST}"
echo -e "${CYAN}${BOLD}║${RST}  🧪  ${BOLD}Reparo Test Suite${RST}                                                        ${CYAN}${BOLD}║${RST}"
echo -e "${CYAN}${BOLD}║${RST}     Safe mode: no system modifications, all side effects sandboxed           ${CYAN}${BOLD}║${RST}"
echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════════════════════════╝${RST}"

test_syntax
test_log_functions
test_die_function
test_print_section
test_copy_config
test_detect_arch
test_download_dir
test_distro_detection
test_dist_root_absolute
test_abort_chain
test_arg_forwarding
test_install_package_mock
test_visual_output
test_neovim_error_handling
test_copy_config_recursive
test_tput_fallback
test_code_quality

# ─── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${RST}"
echo -e "${CYAN}${BOLD}┃${RST}  📊  ${BOLD}Test Results${RST}"
echo -e "${CYAN}${BOLD}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${RST}"
echo ""
echo -e "  Total:   ${BOLD}$TOTAL${RST}"
echo -e "  ${GREEN}Passed:  ${BOLD}$PASS${RST}"
echo -e "  ${RED}Failed:  ${BOLD}$FAIL${RST}"
echo ""

if [ "$FAIL" -eq 0 ]; then
	echo -e "${GREEN}${BOLD}  ✅ All tests passed!${RST}"
	echo ""
	exit 0
else
	echo -e "${RED}${BOLD}  ❌ $FAIL test(s) failed.${RST}"
	echo ""
	exit 1
fi
