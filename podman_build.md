# Building Nerves ROAR with Podman

This document explains how to build the `bbb_purple` Nerves system using the containerized Podman build pipeline.

## Overview

The project is a **Nerves System** (`bbb_purple`) targeting BeagleBone Black / Green / PocketBeagle boards (ARM Cortex-A8). It uses [Buildroot](https://buildroot.org/) under the hood (via `nerves_system_br`) to cross-compile a complete Linux firmware image.

Because the build requires a specific Ubuntu 22.04 environment with many native dependencies, the project provides a Podman-based workflow with three files:

| File | Role |
|---|---|
| `Dockerfile` | Defines the Ubuntu 22.04 build image with all system-level dependencies |
| `nerves-roar-build.sh` | **Host-side** script — builds the container image and runs the build inside it |
| `container-build.sh` | **Container-side** script — installs Erlang/Elixir toolchain and runs the Nerves build |

## Prerequisites

- **Podman** installed on the host (`sudo dnf install podman` on Fedora, `sudo apt install podman` on Debian/Ubuntu)
- Sufficient disk space (~15-20 GB for the full Buildroot cross-compilation)
- Internet access (the build downloads toolchains, kernel sources, and dependencies)

## Project Structure

```
bbb_purple/
├── Dockerfile               # Container image definition (Ubuntu 22.04)
├── nerves-roar-build.sh     # Host script: builds image, runs container
├── container-build.sh       # In-container build script
├── mix.exs                  # Elixir project definition (Nerves system package)
├── mix.lock                 # Locked dependency versions
├── VERSION                  # Current version (2.17.0)
├── nerves_defconfig          # Buildroot defconfig (kernel, u-boot, packages)
├── fwup.conf                # Firmware update configuration
├── fwup-revert.conf         # Firmware revert configuration
├── fwup_include/            # Shared fwup config fragments
├── linux/                   # Custom kernel config & patches
├── uboot/                   # U-Boot config, patches & env
├── rootfs_overlay/          # Files overlaid onto the root filesystem
├── busybox.fragment         # BusyBox config additions
├── post-build.sh            # Buildroot post-build hook
├── post-createfs.sh         # Buildroot post-image hook
├── assets/                  # Documentation assets
├── docs/                    # Additional documentation
├── test/                    # Tests
└── package/                 # Hex package metadata
```

## Build Dependencies

### System packages (installed via Dockerfile)

These are installed inside the container automatically:

- `build-essential`, `automake`, `autoconf`, `libtool` — C/C++ toolchain
- `git`, `curl`, `wget`, `unzip`, `rsync` — fetching sources
- `squashfs-tools` — building squashfs root filesystems
- `pkg-config` — library discovery
- `libssl-dev` — OpenSSL (needed by Erlang)
- `libncurses5-dev` — ncurses (needed by Erlang)
- `libconfuse-dev`, `libarchive-dev`, `libsodium-dev` — needed by `fwup`
- `help2man`, `file`, `python3`, `bc`, `cpio` — Buildroot build requirements
- `locales` — UTF-8 locale support

### Language toolchain (installed by container-build.sh)

| Tool | Version | Purpose |
|---|---|---|
| asdf | v0.15.0 | Version manager for Erlang & Elixir |
| Erlang/OTP | 25.3.2 | BEAM runtime |
| Elixir | 1.14.5-otp-25 | Nerves build tooling |
| fwup | latest (built from source) | Firmware packaging & update tool |

### Elixir/Nerves dependencies (from mix.exs)

| Dependency | Version | Purpose |
|---|---|---|
| `nerves` | ~> 1.6 / 1.7.15+ / 1.8+ | Core Nerves framework |
| `nerves_system_br` | 1.22.1 | Buildroot integration |
| `nerves_toolchain_armv7_nerves_linux_gnueabihf` | ~> 1.8.0 | ARM cross-compiler toolchain |
| `nerves_bootstrap` | 1.12.2 | Mix archive for Nerves builds |

## How to Build

### 1. Run the build

From the `bbb_purple` project directory:

```bash
./nerves-roar-build.sh
```

Or specify the project directory explicitly:

```bash
./nerves-roar-build.sh ~/Projects/bbb_purple
```

### 2. What happens

The build runs in two phases:

**Phase 1 — Host (nerves-roar-build.sh):**

1. Validates that `container-build.sh` exists in the project directory
2. Checks that Podman is installed
3. Removes any leftover container named `nerves-roar-build`
4. Builds the Docker image from `Dockerfile` with `--build-arg HOST_USER=$(whoami)` — this creates a non-root user inside the container matching your host user
5. Runs the container with:
   - `-v "${HOST_DIR}:/home/roar:Z"` — bind-mounts the project directory into the container
   - `--userns=keep-id` — maps host UID/GID into the container (avoids permission issues with Podman rootless)
   - Executes `container-build.sh` inside the container
6. Cleans up the container after completion

**Phase 2 — Container (container-build.sh):**

1. Installs **asdf** version manager
2. Installs **Erlang 25.3.2** and **Elixir 1.14.5-otp-25** via asdf
3. Builds and installs **fwup** from source
4. Cleans any previous build artifacts (`_build`, `deps`, `.nerves`)
5. Installs Hex, Rebar, and `nerves_bootstrap` archive
6. Runs `mix deps.get` — fetches all Elixir dependencies
7. Runs `mix compile` — compiles the project
8. Runs `mix nerves.artifact` — produces the final Nerves system artifact (a portable tarball)

### 3. Build output

On success, the build produces a Nerves system artifact tarball:

```
bbb_purple-portable-<version>-<checksum>.tar.gz
```

This artifact can be used by downstream Nerves application projects as the system dependency.

## Troubleshooting

### Permission errors on mounted files

The `--userns=keep-id` flag and `:Z` SELinux label on the bind mount should handle this. If you still get permission errors, check that your host user owns the project directory.

### Build fails at Erlang compilation

Erlang compilation requires significant memory. Ensure you have at least 4 GB of RAM available.

### Container already exists

The script auto-removes any existing container named `nerves-roar-build`. If you see issues, manually clean up:

```bash
podman rm -f nerves-roar-build
```

### Rebuilding from scratch

Delete the build artifacts before re-running:

```bash
rm -rf _build deps .nerves
./nerves-roar-build.sh
```

## Target Hardware

The system targets **AM335x**-based boards with the following device trees:

- BeagleBone Black (`am335x-boneblack`)
- BeagleBone Green (`am335x-bonegreen`)
- BeagleBone Green Wireless (`am335x-bonegreen-wireless`)
- BeagleBone Black Wireless (`am335x-boneblack-wireless`)
- PocketBeagle (`am335x-pocketbeagle`)
- BeagleBone Blue (`am335x-boneblue`)
- BeagleBone Green Gateway (`am335x-bonegreen-gateway`)
- AM335x EVM Starter Kit (`am335x-evmsk`)

Key system specs from `nerves_defconfig`:
- **Kernel**: Linux 5.10.120
- **U-Boot**: 2021.10
- **Toolchain**: GCC armv7 gnueabihf (Nerves v1.8.0)
- **Wireless**: WPA supplicant with WPA3, mesh, AP, and hotspot support
- **Networking**: libqmi (cellular modem support), libmnl
