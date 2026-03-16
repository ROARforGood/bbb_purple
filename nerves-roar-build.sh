#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Script configuration
CONTAINER_NAME="nerves-roar-build"
IMAGE="ubuntu:22.04"
CONTAINER_WORKDIR="/home/roar"
BUILD_SCRIPT_NAME="container-build.sh"

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

usage() {
    echo "Usage: $0 [host_directory]"
    echo ""
    echo "Arguments:"
    echo "  host_directory    Path to the ROAR project directory (optional)"
    echo "                    If not provided, uses current directory"
    echo "                    The ${BUILD_SCRIPT_NAME} must be present in this directory"
    echo ""
    echo "Example:"
    echo "  $0 /home/kon/Projects/Yalantis/ROAR/bbb_purple"
    echo "  $0                # uses current directory"
    echo ""
    echo "Setup:"
    echo "  1. Copy ${BUILD_SCRIPT_NAME} to your project directory"
    echo "  2. Run this script (optionally with project directory path)"
    exit 1
}

# Use provided argument or current directory
if [ -z "$1" ]; then
    HOST_DIR="$(pwd)"
    log_info "No directory specified, using current directory: ${HOST_DIR}"
else
    HOST_DIR="$1"
fi

# Validate host directory exists
if [ ! -d "$HOST_DIR" ]; then
    log_error "Host directory does not exist: $HOST_DIR"
    exit 1
fi

# Validate build script exists in host directory
if [ ! -f "${HOST_DIR}/${BUILD_SCRIPT_NAME}" ]; then
    log_error "Build script not found: ${HOST_DIR}/${BUILD_SCRIPT_NAME}"
    log_error "Please copy ${BUILD_SCRIPT_NAME} to your project directory first"
    exit 1
fi

# Check if podman is installed
if ! command -v podman &> /dev/null; then
    log_error "Podman is not installed. Please install podman first."
    exit 1
fi

# Cleanup any existing container with the same name
if podman ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    log_warn "Removing existing container: ${CONTAINER_NAME}"
    podman rm -f "${CONTAINER_NAME}" > /dev/null 2>&1
fi

log_info "============================================"
log_info "Nerves ROAR Podman Build"
log_info "============================================"
log_info "Host directory: ${HOST_DIR}"
log_info "Container name: ${CONTAINER_NAME}"
log_info "Build script: ${BUILD_SCRIPT_NAME}"
log_info "============================================"

# Run podman container, execute build script, and exit
log_info "Starting container and running build..."

podman run -it \
    --name "${CONTAINER_NAME}" \
    -v "${HOST_DIR}:${CONTAINER_WORKDIR}:Z" \
    -w "${CONTAINER_WORKDIR}" \
    "${IMAGE}" \
    bash -c "chmod +x ${BUILD_SCRIPT_NAME} && ./${BUILD_SCRIPT_NAME}"

BUILD_EXIT_CODE=$?

# Report result
if [ $BUILD_EXIT_CODE -eq 0 ]; then
    log_info "============================================"
    log_info "Build completed successfully!"
    log_info "Container has exited."
    log_info "============================================"
else
    log_error "============================================"
    log_error "Build failed with exit code: ${BUILD_EXIT_CODE}"
    log_error "============================================"
fi

# Cleanup container after exit
log_info "Cleaning up container..."
podman rm -f "${CONTAINER_NAME}" > /dev/null 2>&1 || true

exit $BUILD_EXIT_CODE
