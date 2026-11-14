#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/Joshua0369/Artix-install.git"
REPO_DIR="Artix-install"
EXTRA_DIR="$REPO_DIR/extra"

echo "==> Cloning Artix-install repository..."
if [ -d "$REPO_DIR" ]; then
    echo "Directory '$REPO_DIR' already exists. Pulling latest changes..."
    git -C "$REPO_DIR" pull
else
    git clone "$REPO_URL"
fi

if [ ! -d "$EXTRA_DIR" ]; then
    echo "Error: 'extra' directory not found in the cloned repository."
    exit 1
fi

echo "==> Setting executable permissions (excluding fix.sh)..."
for script in "$EXTRA_DIR"/*.sh; do
    [ -f "$script" ] || continue
    filename=$(basename "$script")
    if [ "$filename" != "fix.sh" ]; then
        chmod +x "$script"
        echo "  [+] chmod +x $filename"
    fi
done

echo "==> Starting execution queue..."
for script in "$EXTRA_DIR"/*.sh; do
    [ -f "$script" ] || continue
    filename=$(basename "$script")

    if [ "$filename" == "fix.sh" ]; then
        echo "==> Skipping '$filename' (excluded)."
        continue
    fi

    echo ""
    read -rp "Run script '$filename'? (y/N): " choice
    case "$choice" in
        y|Y )
            echo "==> Executing $filename..."
            bash "$script"
            echo "==> Finished $filename."
            ;;
        * )
            echo "==> Skipped $filename."
            ;;
    esac
done

echo ""
echo "==> All scripts processed."
