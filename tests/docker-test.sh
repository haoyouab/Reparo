#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
#  docker-test.sh — Local Docker integration test runner for Reparo
#
#  Usage:
#    bash tests/docker-test.sh                 # Test both distros
#    bash tests/docker-test.sh --fedora        # Test Fedora only
#    bash tests/docker-test.sh --ubuntu        # Test Ubuntu only (all versions)
#    bash tests/docker-test.sh --ubuntu=22.04  # Test a single Ubuntu version
#    SKIP_NEOVIM=true bash tests/docker-test.sh  # Skip slow neovim step
#
#  Requirements: Docker
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ─── Locate project root ─────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ─── Colors ───────────────────────────────────────────────────────────────────
RED=$(tput setaf 1 2>/dev/null || true)
GREEN=$(tput setaf 2 2>/dev/null || true)
YELLOW=$(tput setaf 3 2>/dev/null || true)
CYAN=$(tput setaf 6 2>/dev/null || true)
BOLD=$(tput bold 2>/dev/null || true)
RST=$(tput sgr0 2>/dev/null || true)

# ─── Parse arguments ─────────────────────────────────────────────────────────
RUN_FEDORA=false
RUN_UBUNTU=false
UBUNTU_VERSIONS="${UBUNTU_VERSIONS:-22.04 24.04 26.04}"

for arg in "$@"; do
	case "$arg" in
		--fedora) RUN_FEDORA=true ;;
		--ubuntu) RUN_UBUNTU=true ;;
		--ubuntu=*)
			RUN_UBUNTU=true
			UBUNTU_VERSIONS="${arg#--ubuntu=}"
			;;
		--help | -h)
			echo "Usage: bash tests/docker-test.sh [--fedora] [--ubuntu[=VERSION]]"
			echo ""
			echo "Options:"
			echo "  --fedora          Test Fedora only"
			echo "  --ubuntu          Test Ubuntu only (all versions in UBUNTU_VERSIONS)"
			echo "  --ubuntu=VERSION  Test a single Ubuntu version (e.g. 22.04)"
			echo "  (no flags)        Test both distros"
			echo ""
			echo "Environment variables:"
			echo "  SKIP_NEOVIM=true  Skip neovim setup (faster, skips cargo/rust)"
			echo "  UBUNTU_VERSIONS   Space-separated Ubuntu versions (default: 22.04 24.04 26.04)"
			echo "  GITHUB_TOKEN      Passed into containers to avoid GitHub API rate limits"
			exit 0
			;;
		*)
			echo "Unknown option: $arg (use --help for usage)"
			exit 1
			;;
	esac
done

# Default: run both
if [ "$RUN_FEDORA" = false ] && [ "$RUN_UBUNTU" = false ]; then
	RUN_FEDORA=true
	RUN_UBUNTU=true
fi

# ─── Check Docker availability ───────────────────────────────────────────────
if ! command -v docker &>/dev/null; then
	echo -e "${RED}❌ Docker is not installed or not in PATH.${RST}"
	exit 1
fi

# ─── State ────────────────────────────────────────────────────────────────────
PASS=0
FAIL=0
TOTAL=0
RESULTS=()

# ─── Build environment for SKIP_NEOVIM ───────────────────────────────────────
DOCKER_ENV_ARGS=()
if [ "${SKIP_NEOVIM:-false}" = "true" ]; then
	DOCKER_ENV_ARGS+=(-e "SKIP_NEOVIM=true")
fi
if [ -n "${GITHUB_TOKEN:-}" ]; then
	DOCKER_ENV_ARGS+=(-e "GITHUB_TOKEN")
fi

# ─── Forward host proxy settings (host network so 127.0.0.1 proxies work) ────
BUILD_EXTRA_ARGS=()
for _pv in http_proxy https_proxy no_proxy HTTP_PROXY HTTPS_PROXY NO_PROXY; do
	if [ -n "${!_pv:-}" ]; then
		BUILD_EXTRA_ARGS+=(--build-arg "$_pv")
		DOCKER_ENV_ARGS+=(-e "$_pv")
	fi
done
if [ ${#BUILD_EXTRA_ARGS[@]} -gt 0 ]; then
	BUILD_EXTRA_ARGS+=(--network host)
	DOCKER_ENV_ARGS+=(--network host)
fi

# ─── Test a single distro ────────────────────────────────────────────────────
# Usage: run_distro_test <distro> [version]
run_distro_test() {
	local distro=$1
	local version=${2:-}
	local dockerfile="tests/Dockerfile.${distro}"
	local image_name="reparo-test-${distro}"
	local label=$distro
	local build_args=("${BUILD_EXTRA_ARGS[@]+"${BUILD_EXTRA_ARGS[@]}"}")
	if [ -n "$version" ]; then
		image_name="${image_name}-${version}"
		label="${distro} ${version}"
		build_args+=(--build-arg "UBUNTU_VERSION=${version}")
	fi

	TOTAL=$((TOTAL + 1))

	echo ""
	echo -e "${CYAN}${BOLD}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${RST}"
	echo -e "${CYAN}${BOLD}┃${RST}  🐳  Testing: ${BOLD}${label}${RST}"
	echo -e "${CYAN}${BOLD}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${RST}"

	# Build
	echo ""
	echo -e "  ${BOLD}🔨 Building image...${RST}"
	if docker build -f "$PROJECT_ROOT/$dockerfile" -t "$image_name" \
		"${build_args[@]+"${build_args[@]}"}" "$PROJECT_ROOT" 2>&1 \
		| sed 's/^/     /'; then
		echo -e "  ${GREEN}✅ Image built: ${image_name}${RST}"
	else
		echo -e "  ${RED}❌ Failed to build image: ${image_name}${RST}"
		FAIL=$((FAIL + 1))
		RESULTS+=("${RED}❌${RST} ${label}")
		return
	fi

	# Run
	echo ""
	echo -e "  ${BOLD}🚀 Running setup...${RST}"
	echo ""
	if docker run --rm "${DOCKER_ENV_ARGS[@]+"${DOCKER_ENV_ARGS[@]}"}" "$image_name" 2>&1 \
		| sed 's/^/     /'; then
		echo ""
		echo -e "  ${GREEN}${BOLD}✅ ${label} — PASSED${RST}"
		PASS=$((PASS + 1))
		RESULTS+=("${GREEN}✅${RST} ${label}")
	else
		echo ""
		echo -e "  ${RED}${BOLD}❌ ${label} — FAILED${RST}"
		FAIL=$((FAIL + 1))
		RESULTS+=("${RED}❌${RST} ${label}")
	fi
}

# ─── Header ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════════════════════════╗${RST}"
echo -e "${CYAN}${BOLD}║${RST}  🐳  ${BOLD}Reparo Docker Integration Tests${RST}                                         ${CYAN}${BOLD}║${RST}"
if [ "${SKIP_NEOVIM:-false}" = "true" ]; then
	echo -e "${CYAN}${BOLD}║${RST}     ${YELLOW}Mode: Quick (SKIP_NEOVIM=true)${RST}                                         ${CYAN}${BOLD}║${RST}"
else
	echo -e "${CYAN}${BOLD}║${RST}     Mode: Full (all steps including Neovim/Rust)                             ${CYAN}${BOLD}║${RST}"
fi
echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════════════════════════╝${RST}"

# ─── Run tests ────────────────────────────────────────────────────────────────
[ "$RUN_FEDORA" = true ] && run_distro_test "fedora"
if [ "$RUN_UBUNTU" = true ]; then
	for v in $UBUNTU_VERSIONS; do
		run_distro_test "ubuntu" "$v"
	done
fi

# ─── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${RST}"
echo -e "${CYAN}${BOLD}┃${RST}  📊  ${BOLD}Integration Test Results${RST}:  ${PASS}/${TOTAL} passed"
echo -e "${CYAN}${BOLD}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${RST}"
echo ""
for r in "${RESULTS[@]}"; do
	echo -e "  $r"
done
echo ""

if [ "$FAIL" -eq 0 ]; then
	echo -e "${GREEN}${BOLD}  ✅ All integration tests passed!${RST}"
	echo ""
	exit 0
else
	echo -e "${RED}${BOLD}  ❌ ${FAIL} test(s) failed.${RST}"
	echo ""
	exit 1
fi
