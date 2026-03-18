# Use Ubuntu 22.04 base image
FROM ubuntu:22.04

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install packages
RUN apt-get update && \
    apt-get install -y \
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
        locales \
        mc \
        sudo \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Configure locale
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Create user matching host user
ARG HOST_USER
RUN useradd -ms /bin/bash ${HOST_USER} && \
    echo "${HOST_USER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Switch to host user
USER ${HOST_USER}
WORKDIR /home/roar

# Default command
CMD ["/bin/bash"]
