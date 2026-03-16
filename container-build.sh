#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_result() {
    local status=$?
    if [ $status -eq 0 ]; then
        log_info "$1 - SUCCESS"
        return 0
    else
        log_error "$1 - FAILED (exit code: $status)"
        exit 1
    fi
}

log_info "============================================"
log_info "Starting Nerves ROAR build inside container"
log_info "============================================"

# Update and install dependencies
log_info "Installing system dependencies..."
apt update
check_result "apt update"

apt install -y \
    build-essential \
    automake \
    autoconf \
    git \
    squashfs-tools \
    pkg-config \
    curl \
    wget \
    unzip \
    rsync \
    file \
    python3 \
    bc \
    cpio \
    libssl-dev \
    libncurses5-dev \
    libconfuse-dev \
    libarchive-dev \
    libsodium-dev \
    help2man \
    libtool \
    locales
check_result "Install system dependencies"

# Configure locale
log_info "Configuring locale..."
locale-gen en_US.UTF-8
check_result "Generate locale"

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
echo 'export LANG=en_US.UTF-8' >> ~/.bashrc
echo 'export LC_ALL=en_US.UTF-8' >> ~/.bashrc

# Install asdf
log_info "Installing asdf version manager..."
if [ ! -d "$HOME/.asdf" ]; then
    git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.15.0
    check_result "Clone asdf"
else
    log_warn "asdf already installed, skipping..."
fi

echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc
. "$HOME/.asdf/asdf.sh"
check_result "Source asdf"

# Install Erlang
log_info "Installing Erlang 25.3.2..."
asdf plugin add erlang 2>/dev/null || log_warn "Erlang plugin already exists"
check_result "Add erlang plugin"

if ! asdf list erlang | grep -q "25.3.2"; then
    asdf install erlang 25.3.2
    check_result "Install Erlang 25.3.2"
else
    log_warn "Erlang 25.3.2 already installed, skipping..."
fi

asdf global erlang 25.3.2
check_result "Set global Erlang version"

# Install Elixir
log_info "Installing Elixir 1.14.5-otp-25..."
asdf plugin add elixir 2>/dev/null || log_warn "Elixir plugin already exists"
check_result "Add elixir plugin"

if ! asdf list elixir | grep -q "1.14.5-otp-25"; then
    asdf install elixir 1.14.5-otp-25
    check_result "Install Elixir 1.14.5-otp-25"
else
    log_warn "Elixir 1.14.5-otp-25 already installed, skipping..."
fi

asdf global elixir 1.14.5-otp-25
check_result "Set global Elixir version"

# Verify Erlang and Elixir installation
log_info "Verifying Erlang installation..."
OTP_VERSION=$(erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().' -noshell 2>&1)
log_info "Erlang OTP version: $OTP_VERSION"
check_result "Erlang verification"

log_info "Verifying Elixir installation..."
elixir --version
check_result "Elixir verification"

# Build and install fwup
log_info "Building fwup from source..."
if ! command -v fwup &> /dev/null; then
    cd /tmp
    if [ ! -d "fwup" ]; then
        git clone https://github.com/fwup-home/fwup.git
        check_result "Clone fwup"
    fi

    cd fwup
    autoreconf -i
    check_result "fwup autoreconf"

    ./configure
    check_result "fwup configure"

    make
    check_result "fwup make"

    make install
    check_result "fwup install"
else
    log_warn "fwup already installed, skipping..."
fi

# Verify fwup installation
fwup --version
check_result "fwup verification"

# Build the Nerves project
log_info "Building Nerves ROAR project..."
cd /home/roar

mix local.hex --force
check_result "Install hex"

mix local.rebar --force
check_result "Install rebar"

mix archive.install hex nerves_bootstrap 1.12.2 --force
check_result "Install nerves_bootstrap"

log_info "Fetching dependencies..."
mix deps.get
check_result "mix deps.get"

log_info "Compiling project..."
mix compile
check_result "mix compile"

log_info "Creating Nerves artifact..."
mix nerves.artifact
check_result "mix nerves.artifact"

log_info "============================================"
log_info "Build completed successfully!"
log_info "============================================"

exit 0
