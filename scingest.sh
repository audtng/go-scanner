#!/bin/bash
set -euo pipefail

OUTPUT_FILE="ingest.txt"
LANGUAGE="go"

# 1. Clear the output file so we don't append to old runs
> "$OUTPUT_FILE"

echo "[*] Initializing target ingestion..."

for cmd in curl jq; do
  if ! command -v $cmd &> /dev/null; then
    echo "[-] Error: '$cmd' is not installed."
    exit 1
  fi
done

if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "[-] Error: GITHUB_TOKEN environment variable is not set."
  exit 1
fi

QUERY="stars:>1+language:${LANGUAGE}"
echo "[*] Querying GitHub API for top 500 highest-starred projects..."

# 2. Loop through pages 1 to 5
for PAGE in {1}; do
  echo "    -> Fetching page $PAGE of 5..."
  
  # Append the &page parameter to the URL
  API_URL="https://api.github.com/search/repositories?q=${QUERY}&sort=stars&order=desc&per_page=10&page=${PAGE}"

  RESPONSE=$(curl -s -w "\n%{http_code}" \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github.v3+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "$API_URL")

  HTTP_STATUS=$(echo "$RESPONSE" | tail -n1)
  BODY=$(echo "$RESPONSE" | sed '$d')

  if [ "$HTTP_STATUS" -ne 200 ]; then
    echo "[-] Error: GitHub API returned HTTP $HTTP_STATUS on page $PAGE"
    echo "$BODY" | jq .
    exit 1
  fi

  # 3. Append (>>) the output instead of overwriting (>)
  echo "$BODY" | jq -r '.items[].clone_url' >> "$OUTPUT_FILE"

  # 4. Pause briefly to respect GitHub's secondary rate limits
  sleep 2
done

TOTAL_FOUND=$(wc -l < "$OUTPUT_FILE" | tr -d ' ')

echo "[+] Success! Extracted $TOTAL_FOUND repositories."
echo "[+] Target URLs saved to: $OUTPUT_FILE"
