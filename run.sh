#!/bin/bash

# Configuration
TARGETS_FILE="targets.txt"
RULES_FILE="final_rules.yaml"
RESULTS_DIR="semgrep_results"

# Ensure dependencies are installed
if ! command -v git &> /dev/null; then
    echo "Error: 'git' is not installed."
    exit 1
fi

if ! command -v semgrep &> /dev/null; then
    echo "Error: 'semgrep' is not installed."
    exit 1
fi

# Ensure required files exist
if [ ! -f "$TARGETS_FILE" ]; then
    echo "Error: $TARGETS_FILE not found."
    exit 1
fi

if [ ! -f "$RULES_FILE" ]; then
    echo "Error: $RULES_FILE not found."
    exit 1
fi

# Create results directory
mkdir -p "$RESULTS_DIR"
echo "Results will be saved to the '$RESULTS_DIR' directory."
echo "---------------------------------------------------"

# Read targets.txt line by line
while IFS= read -r REPO_URL; do
    # Skip empty lines and comments
    [[ -z "$REPO_URL" || "$REPO_URL" == \#* ]] && continue

    # Extract repository name for folder/file naming
    REPO_NAME=$(basename -s .git "$REPO_URL")
    WORKSPACE=$(mktemp -d)
    CLONE_DIR="$WORKSPACE/$REPO_NAME"
    RESULT_FILE="$RESULTS_DIR/${REPO_NAME}_scan.txt"

    echo ">>> Target: $REPO_NAME"
    
    # Shallow clone to save time and bandwidth
    if ! git clone --depth 1 "$REPO_URL" "$CLONE_DIR" &> /dev/null; then
        echo "    [!] Failed to clone $REPO_URL. Skipping."
        rm -rf "$WORKSPACE"
        continue
    fi

    echo "    [+] Scanning with Semgrep..."
    
    # Run Semgrep. We use || true because Semgrep returns exit code 1 if it finds vulnerabilities,
    # which would otherwise crash the script if 'set -e' was enabled.
    semgrep scan --config "$RULES_FILE" "$CLONE_DIR" > "$RESULT_FILE" 2>&1 || true

    # Check if the result file is basically empty or contains findings
    if grep -q "No findings" "$RESULT_FILE" || ! grep -q "find" "$RESULT_FILE"; then
        echo "    [-] No vulnerabilities found."
    else
        echo "    [!] Findings detected. See $RESULT_FILE"
    fi

    # Clean up the workspace
    echo "    [+] Cleaning up workspace..."
    rm -rf "$WORKSPACE"
    echo "---------------------------------------------------"

done < "$TARGETS_FILE"

echo "All scans complete. Check the '$RESULTS_DIR' directory for reports."
