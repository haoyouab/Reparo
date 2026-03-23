#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
#  build.sh — Build a ready-to-use Docker dev environment with Reparo
#
#  Usage:
#    bash docker/build.sh                     # Build Fedora (default)
#    bash docker/build.sh --ubuntu            # Build Ubuntu
#    bash docker/build.sh --skip-neovim       # Skip Neovim (faster)
#    bash docker/build.sh --ubuntu --skip-neovim
#
#  Requirements: Docker
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ─── Locate project root ─────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ─── Colors (safe for non-TTY) ──────────────────────────────────────────────
RED=$(tput setaf 1 2>/dev/null || true)
GREEN=$(tput setaf 2 2>/dev/null || true)
BLUE=$(tput setaf 4 2>/dev/null || true)
CYAN=$(tput setaf 6 2>/dev/null || true)
BOLD=$(tput bold 2>/dev/null || true)
RST=$(tput sgr0 2>/dev/null || true)

# ─── Logging (reuse project style) ──────────────────────────────────────────
log_info() { echo -e "  ${BLUE}ℹ️  ${RST}$1"; }
log_success() { echo -e "  ${GREEN}✅ ${RST}$1"; }
log_error() { echo -e "  ${RED}❌ ${RST}$1"; }

# ─── Parse arguments ────────────────────────────────────────────────────────
DISTRO="fedora"
SKIP_NEOVIM=false
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
OFFLINE_SRC_DIR=""

for arg in "$@"; do
	case "$arg" in
		--fedora) DISTRO="fedora" ;;
		--ubuntu) DISTRO="ubuntu" ;;
		--skip-neovim) SKIP_NEOVIM=true ;;
		--github-token=*)
			GITHUB_TOKEN="${arg#--github-token=}"
			;;
		--offline=*)
			OFFLINE_SRC_DIR="${arg#--offline=}"
			;;
		--help | -h)
			echo ""
			echo "Usage: bash setup --docker [OPTIONS]"
			echo ""
			echo "Options:"
			echo "  --fedora              Use Fedora base image (default)"
			echo "  --ubuntu              Use Ubuntu base image"
			echo "  --skip-neovim         Skip Neovim setup (faster, no Rust/cargo)"
			echo "  --offline=DIR         Use offline packages from DIR (skip GitHub downloads)"
			echo "  --help, -h            Show this help message"
			echo ""
			echo "Examples:"
			echo "  bash setup --docker                  # Fedora, full setup"
			echo "  bash setup --docker --ubuntu         # Ubuntu, full setup"
			echo "  bash setup --docker --skip-neovim    # Fedora, skip Neovim"
			echo "  bash setup --docker --offline=/path/to/packages"
			echo ""
			echo "If you hit GitHub API rate limits, pass a token:"
			echo "  bash setup --docker --github-token=ghp_xxx"
			echo "  GITHUB_TOKEN=ghp_xxx bash setup --docker"
			exit 0
			;;
		*)
			echo "Unknown option: $arg (use --help for usage)"
			exit 1
			;;
	esac
done

# ─── Check Docker availability ──────────────────────────────────────────────
if ! command -v docker &>/dev/null; then
	log_error "Docker is not installed or not in PATH."
	echo ""
	echo "  Install Docker: https://docs.docker.com/get-docker/"
	exit 1
fi

# ─── Variables ──────────────────────────────────────────────────────────────
DOCKERFILE="docker/Dockerfile.${DISTRO}"
IMAGE_NAME="reparo-dev-${DISTRO}"
OFFLINE_IMAGE="docker/images/${DISTRO}-latest.tar.gz"
HOST_USERNAME="$(whoami)"
HOST_UID="$(id -u)"

# ─── Build args ─────────────────────────────────────────────────────────────
BUILD_ARGS=(
	--build-arg "USERNAME=${HOST_USERNAME}"
	--build-arg "USER_UID=${HOST_UID}"
)
if [ "$SKIP_NEOVIM" = true ]; then
	BUILD_ARGS+=(--build-arg "SKIP_NEOVIM=true")
fi
if [ -n "$GITHUB_TOKEN" ]; then
	BUILD_ARGS+=(--build-arg "GITHUB_TOKEN=${GITHUB_TOKEN}")
fi

# ─── Handle offline packages ──────────────────────────────────────────────────────
OFFLINE_STAGE_DIR="$PROJECT_ROOT/.offline-packages"
OFFLINE_STAGED=false

if [ -n "$OFFLINE_SRC_DIR" ]; then
	if [ ! -d "$OFFLINE_SRC_DIR" ]; then
		log_error "Offline directory does not exist: $OFFLINE_SRC_DIR"
		exit 1
	fi
	log_info "Staging offline packages from ${BOLD}${OFFLINE_SRC_DIR}${RST} into build context..."
	mkdir -p "$OFFLINE_STAGE_DIR"
	cp -r "$OFFLINE_SRC_DIR"/* "$OFFLINE_STAGE_DIR/" 2>/dev/null || {
		log_error "Failed to copy offline packages to build context."
		exit 1
	}
	OFFLINE_STAGED=true
	BUILD_ARGS+=(--build-arg "OFFLINE_ARGS=--offline=/tmp/Reparo/.offline-packages")
	log_success "Offline packages staged"
fi

# Clean up staged offline packages on exit
cleanup_offline() {
	if [ "$OFFLINE_STAGED" = true ] && [ -d "$OFFLINE_STAGE_DIR" ]; then
		rm -rf "$OFFLINE_STAGE_DIR"
	fi
}
trap cleanup_offline EXIT

# ─── Header ─────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${RST}"
echo -e "${CYAN}${BOLD}┃${RST}  🐳  ${BOLD}Building Reparo Dev Environment${RST}"
echo -e "${CYAN}${BOLD}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${RST}"
echo ""
log_info "Distro:       ${BOLD}${DISTRO}${RST}"
log_info "Image name:   ${BOLD}${IMAGE_NAME}${RST}"
log_info "Username:     ${BOLD}${HOST_USERNAME}${RST} (uid=${HOST_UID})"
log_info "Skip Neovim:  ${BOLD}${SKIP_NEOVIM}${RST}"

# ─── Load offline base image ────────────────────────────────────────────────
# Bundled images avoid docker.io access (blocked in mainland China)
echo ""
if [ -f "$PROJECT_ROOT/$OFFLINE_IMAGE" ]; then
	if docker image inspect "${DISTRO}:latest" &>/dev/null; then
		log_info "Base image ${BOLD}${DISTRO}:latest${RST} already loaded, skipping import"
	else
		log_info "Loading offline base image: ${BOLD}${OFFLINE_IMAGE}${RST}..."
		if docker load -i "$PROJECT_ROOT/$OFFLINE_IMAGE"; then
			log_success "Base image loaded: ${BOLD}${DISTRO}:latest${RST}"
		else
			log_error "Failed to load offline image: $OFFLINE_IMAGE"
			exit 1
		fi
	fi
else
	log_info "Offline image not found, Docker will pull ${BOLD}${DISTRO}:latest${RST} from registry"
fi

# ─── Build ──────────────────────────────────────────────────────────────────
echo ""
log_info "Building Docker image (this may take a few minutes)..."
echo ""

if docker build \
	-f "$PROJECT_ROOT/$DOCKERFILE" \
	-t "$IMAGE_NAME" \
	"${BUILD_ARGS[@]+"${BUILD_ARGS[@]}"}" \
	"$PROJECT_ROOT"; then
	echo ""
	log_success "Docker image built successfully: ${BOLD}${IMAGE_NAME}${RST}"
else
	echo ""
	log_error "Failed to build Docker image."
	exit 1
fi

# ─── Usage hints ────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${RST}"
echo -e "${GREEN}${BOLD}┃${RST}  🎉  ${BOLD}Dev environment ready!${RST}"
echo -e "${GREEN}${BOLD}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${RST}"
echo ""
echo -e "  ${BOLD}🚀 Enter container:${RST}"
echo -e "     ${CYAN}bash enter${RST}"
echo ""
echo -e "  ${BOLD}🔀 Choose distro interactively:${RST}"
echo -e "     ${CYAN}bash enter -i${RST}"
echo ""
