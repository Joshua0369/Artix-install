#!/usr/bin/env bash

# Exit immediately if any command exits with a non-zero status
set -euo pipefail

# Resolve absolute paths and filenames
CURRENT_SCRIPT="$(readlink -f "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[INFO] Scanning and executing extra scripts in: $SCRIPT_DIR"

for file in "$SCRIPT_DIR"/*; do
    # Ensure we are evaluating a regular file
    if [[ -f "$file" ]]; then
        abs_file="$(readlink -f "$file")"
        filename="$(basename "$file")"

        # Exclude run_extra.sh itself AND fix.sh
        if [[ "$abs_file" == "$CURRENT_SCRIPT" ]] || [[ "$filename" == "fix.sh" ]]; then
            echo "[DEBUG] Skipping excluded script: $filename"
            continue
        fi

        # Only process shell script files
        case "$file" in
            *.sh)
                echo "[INFO] Executing: $filename"
                
                # Ensure the target script is executable
                chmod +x "$file"
                
                # Execute and catch exit status
                if "$file"; then
                    echo "[SUCCESS] Finished: $filename"
                else
                    echo "[ERROR] Script failed with exit code $?: $filename" >&2
                    exit 1
                fi
                ;;
            *)
                echo "[DEBUG] Skipping non-script file: $filename"
                ;;
        esac
    fi
done

echo "[INFO] All extra scripts executed successfully."
