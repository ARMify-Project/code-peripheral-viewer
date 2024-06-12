#!/usr/bin/env bash

set -euo pipefail

PLUGIN="marus25.cortex-debug"

# Check if the script is run with an argument
if [ $# -eq 0 ]; then
	echo "usage: ./viewer.sh <svdpath>"
	exit 1
fi

# Get the absolute path of the SVD file
SVD=$(realpath "$1")

# Check if the SVD file exists
if [[ ! -f "$SVD" ]]; then
	echo "Error: $SVD does not exist!"
	exit 1
fi

# Check if VSCode is installed
if ! command -v code &>/dev/null; then
	echo "Error: VSCode is not installed!"
	exit 1
fi

# Check that VSCode is not running
if pgrep -x "code" &>/dev/null; then
	echo "Error: VSCode is already running! Viewer does not work with multiple instances of VSCode."
	exit 1
fi

# Check if the plugin is installed and install it if not
if ! code --list-extensions | grep -q "^${PLUGIN}$"; then
	code --force --install-extension ${PLUGIN}
fi

# Check if the directory ./code/qemu exists and exit if not download QEMU binary
if [ ! -d "./code/qemu" ]; then
	echo "Downloading QEMU..."
	wget -q -c https://github.com/xpack-dev-tools/qemu-arm-xpack/releases/download/v8.2.2-1/xpack-qemu-arm-8.2.2-1-linux-x64.tar.gz -O - | tar -xz -C code
	mv code/xpack-qemu-arm-8.2.2-1 code/qemu
	echo "QEMU downloaded!"
fi

# Replace the SVD file path in the launch.json file
sed -i "s@\"svdFile\": \"[^\"]*\"@\"svdFile\": \"$SVD\"@" code/.vscode/launch.json

# Start VSCode
/usr/share/code/code code/ &>/dev/null &
CODE_PID=$!

# Start QEMU
./code/qemu/bin/qemu-system-gnuarmeclipse \
	-cpu cortex-m4 \
	-machine STM32F4-Discovery \
	-gdb tcp::3333 \
	-nographic \
	-kernel ./code/dummy_app &>/dev/null &
QEMU_PID=$!

# Check if QEMU is running
if [ ! -d "/proc/${QEMU_PID}" ]; then
	echo -ne "\033[31m Failed to start QEMU"
	echo -e "\033[0m"
	exit 1
fi

echo "In code press F5 to start debugging!"

# Wait for the VSCode to close
wait ${CODE_PID}

# Kill QEMU if it is still running
kill ${QEMU_PID} &>/dev/null