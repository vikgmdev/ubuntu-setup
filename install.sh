#!/bin/bash
# One-liner installer: sh -c "$(curl -fsSL https://raw.githubusercontent.com/vikgmdev/ubuntu-setup/main/install.sh)"
set -e

REPO="https://github.com/vikgmdev/ubuntu-setup.git"
INSTALL_DIR="$HOME/.ubuntu-setup"

echo "=== Ubuntu Setup Installer ==="
echo ""

# Clone or update the repo
if [ -d "$INSTALL_DIR" ]; then
    echo "Updating existing installation..."
    git -C "$INSTALL_DIR" pull --ff-only
else
    echo "Cloning ubuntu-setup..."
    git clone "$REPO" "$INSTALL_DIR"
fi

# Run the setup
echo ""
exec bash "$INSTALL_DIR/optimize.sh"
