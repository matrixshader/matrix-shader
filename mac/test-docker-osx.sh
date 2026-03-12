#!/usr/bin/env bash
# test-docker-osx.sh — Launch macOS Sonoma in Docker-OSX for Matrix Shader testing
#
# Prerequisites (already installed by setup):
#   - Docker (moby-engine) with service running
#   - KVM enabled (/dev/kvm accessible)
#   - User in 'docker' group (may need logout/login or use sudo)
#   - X11 display available (XWayland works)
#
# Usage:
#   ./test-docker-osx.sh              # Sonoma (default)
#   ./test-docker-osx.sh sequoia      # Sequoia
#   ./test-docker-osx.sh ventura      # Ventura
#   HEADLESS=1 ./test-docker-osx.sh   # No display (VNC only)
#
# First boot downloads the macOS recovery image (~700MB) and installs to a
# virtual disk inside the container. This takes 30-60 minutes. Subsequent
# boots from a committed image are much faster.
#
# After macOS is installed and booted:
#   1. SSH into the VM:
#        ssh user@localhost -p 50922
#        (default password: alpine)
#   2. Copy test files into the VM:
#        scp -P 50922 -r /home/neo/matrix-shader/mac/ user@localhost:~/matrix-shader/
#   3. Or access the shared mount (if using virtio-9p — see SHARED_DIR below)
#
# To save your installed macOS state (avoid reinstalling each time):
#   docker commit <container-id> docker-osx-sonoma-installed
#   Then change IMAGE below to docker-osx-sonoma-installed
#
# Memory: The VM defaults to 4GB RAM. Your system has 16GB total with ~11GB
# available. 4GB should work but macOS will be sluggish. Bump to 8GB if you
# can spare it.

set -euo pipefail

SHORTNAME="${1:-sonoma}"
IMAGE="${DOCKER_OSX_IMAGE:-sickcodes/docker-osx:latest}"
RAM="${RAM:-4}"
CONTAINER_NAME="docker-osx-${SHORTNAME}"
HOST_MAC_DIR="/home/neo/matrix-shader/mac"

# ---------- Pre-flight checks ----------

# Docker daemon
if ! docker info &>/dev/null; then
    if ! sudo docker info &>/dev/null; then
        echo "ERROR: Docker daemon is not running. Start it with:"
        echo "  sudo systemctl start docker"
        exit 1
    fi
    echo "NOTE: Docker requires sudo. Running with sudo."
    echo "      To avoid this, log out and back in (you were added to the docker group)."
    DOCKER="sudo docker"
else
    DOCKER="docker"
fi

# KVM
if [ ! -e /dev/kvm ]; then
    echo "ERROR: /dev/kvm not found. KVM is required for Docker-OSX."
    echo "  Ensure virtualization is enabled in BIOS and kvm modules are loaded."
    exit 1
fi

# Display
if [ -z "${DISPLAY:-}" ] && [ -z "${HEADLESS:-}" ]; then
    echo "ERROR: No \$DISPLAY set and HEADLESS is not enabled."
    echo "  If on Wayland, XWayland should provide DISPLAY=:0"
    echo "  Or run with: HEADLESS=1 $0"
    exit 1
fi

# Wayland + X11 forwarding: allow local connections
if [ -n "${WAYLAND_DISPLAY:-}" ] && [ -n "${DISPLAY:-}" ]; then
    echo "Wayland detected with XWayland (DISPLAY=${DISPLAY})"
    echo "Running 'xhost +local:' to allow Docker X11 access..."
    xhost +local: 2>/dev/null || echo "WARNING: xhost failed — X11 forwarding may not work"
fi

# ---------- Build docker run command ----------

echo ""
echo "=== Docker-OSX Launch ==="
echo "  macOS version : ${SHORTNAME}"
echo "  RAM           : ${RAM}GB"
echo "  SSH port      : localhost:50922 (user/alpine)"
echo "  Image         : ${IMAGE}"
echo "  Container     : ${CONTAINER_NAME}"
echo ""

# Remove any existing container with the same name
$DOCKER rm -f "${CONTAINER_NAME}" 2>/dev/null || true

# Common args for all versions
DOCKER_ARGS=(
    run -it
    --name "${CONTAINER_NAME}"
    --device /dev/kvm
    -p 50922:10022
    -v /tmp/.X11-unix:/tmp/.X11-unix
    -e "DISPLAY=${DISPLAY:-:0.0}"
    -e GENERATE_UNIQUE=true
    -e "RAM=${RAM}"
    -e "SHORTNAME=${SHORTNAME}"
)

# Sonoma/Sequoia/Tahoe need special CPU flags for newer macOS
case "${SHORTNAME}" in
    sonoma|sequoia|tahoe)
        DOCKER_ARGS+=(
            -e "CPU=Haswell-noTSX"
            -e "CPUID_FLAGS=kvm=on,vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on"
            -e "MASTER_PLIST_URL=https://raw.githubusercontent.com/sickcodes/osx-serial-generator/master/config-custom-sonoma.plist"
        )
        ;;
    monterey|ventura)
        DOCKER_ARGS+=(
            -e "MASTER_PLIST_URL=https://raw.githubusercontent.com/sickcodes/osx-serial-generator/master/config-custom.plist"
        )
        ;;
    catalina|big-sur)
        # No extra flags needed
        ;;
    *)
        echo "WARNING: Unknown macOS version '${SHORTNAME}'. Proceeding anyway."
        ;;
esac

# Headless mode: use VNC instead of X11
if [ -n "${HEADLESS:-}" ]; then
    echo "HEADLESS mode: VNC will be available inside the container."
    echo "  Connect with a VNC client to the container's VNC port."
    DOCKER_ARGS+=( -e "HEADLESS=true" )
fi

# Mount the mac directory for easy file transfer via shared folder
# Note: QEMU 9p/virtio sharing is complex; SSH/SCP is more reliable.
# The mount is available inside the Docker container at /mnt/matrix-shader
# but NOT directly inside the macOS VM. Use SCP to transfer files.
DOCKER_ARGS+=(
    -v "${HOST_MAC_DIR}:/mnt/matrix-shader:ro"
)

echo "Starting Docker-OSX..."
echo "  First boot will download macOS recovery (~700MB) and run the installer."
echo "  This takes 30-60 minutes. Be patient."
echo ""
echo "  After install completes and macOS boots:"
echo "    ssh user@localhost -p 50922        # password: alpine"
echo "    scp -P 50922 file user@localhost:~ # copy files in"
echo ""
echo "  To save state after install:"
echo "    docker commit ${CONTAINER_NAME} docker-osx-${SHORTNAME}-installed"
echo ""

$DOCKER "${DOCKER_ARGS[@]}" "${IMAGE}"
