#!/bin/bash
# run_once_install-zellij-plugin.sh
# Installs vim-zellij-navigator plugin for Zellij
# This script runs once per machine via chezmoi

set -e

PLUGIN_DIR="${HOME}/.config/zellij/plugins"
PLUGIN_URL="https://github.com/hiasr/vim-zellij-navigator/releases/latest/download/vim-zellij-navigator.wasm"
PLUGIN_FILE="${PLUGIN_DIR}/vim-zellij-navigator.wasm"

echo "🔌 Setting up Zellij vim-navigator plugin..."

# Create plugin directory
mkdir -p "${PLUGIN_DIR}"

# Download plugin if not exists or force update
if [ ! -f "${PLUGIN_FILE}" ] || [ "$1" = "--force" ]; then
    echo "📥 Downloading vim-zellij-navigator.wasm..."
    curl -fsSL "${PLUGIN_URL}" -o "${PLUGIN_FILE}"
    echo "✅ Plugin installed to ${PLUGIN_FILE}"
else
    echo "✅ Plugin already exists at ${PLUGIN_FILE}"
fi

# Create SSH sockets directory (for ControlMaster)
SSH_SOCKETS="${HOME}/.ssh/sockets"
if [ ! -d "${SSH_SOCKETS}" ]; then
    echo "📁 Creating SSH sockets directory..."
    mkdir -p "${SSH_SOCKETS}"
    chmod 700 "${SSH_SOCKETS}"
fi

echo "🎉 Setup complete!"
