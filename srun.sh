#!/bin/bash
set -euo pipefail

TARGETS_FILE="ingest.txt"
RULE_FILE="$1" # Pass the validated rule file as an argument
RESULTS_DIR="scan_results"

if [ -z "$RULE_FILE" ] || [ ! -f "$RULE_FILE" ]; then
  echo "[-] Usage: ./scan.sh semgrep-experimental.yaml"
  exit 1
fi

mkdir -p "$RESULTS_DIR"
TIMESTAMP=$(date +%s)
MASTER_LOG="$RESULTS_DIR/hits_${TIMESTAMP}.txt"

echo "[*] Initializing Fleet Scanner with rule: $RULE_FILE"

while read -r REPO_URL; do
  # Extract repo name for local folder
  REPO_NAME=$(basename -s .git "$REPO_URL")
  
  echo "=========================================="
  echo "[*] Working on : $REPO_NAME"
  
  # 1. Shallow clone (Depth 1 saves massive disk I/O and bandwidth)
  if ! git clone --depth 1 --quiet "$REPO_URL" "/tmp/$REPO_NAME"; then
    echo "[-] Failed to clone $REPO_URL. Skipping."
    continue
  fi

  # 2. Run the scanner
  echo "    -> Scanning..."
  
  # Use JSON output for accurate hit counting
  SCAN_OUT="/tmp/${REPO_NAME}_out.json"
  semgrep --config "$RULE_FILE" "/tmp/$REPO_NAME" --json -o "$SCAN_OUT" --quiet || true

  # 3. Check for hits
  if [ -f "$SCAN_OUT" ]; then
    HITS=$(jq '.results | length' "$SCAN_OUT")
    if [ "$HITS" -gt 0 ]; then
      echo "Patterns Matched : $HITS hits in $REPO_NAME!"
      # Append the critical data to your master log
      echo "$REPO_URL" >> "$MASTER_LOG"
      jq '.results[] | {path: .path, line: .start.line, snippet: .extra.lines}' "$SCAN_OUT" >> "$MASTER_LOG"
    else
      echo "    -> Clean."
    fi
  fi

  # 4. Immediate Cleanup (Crucial for scaling)
  rm -rf "/tmp/$REPO_NAME" "/tmp/${REPO_NAME}_out.json"
  
  # Brief pause to avoid GitHub cloning rate limits
  sleep 1

done < "$TARGETS_FILE"

echo "[+] Fleet scan complete. Results logged to $MASTER_LOG"
