#!/usr/bin/env bash
#
# plex-token.sh — generate a Plex authentication token via the device-link flow.
#
# Prompts for a product name, requests a PIN from plex.tv, waits for you to
# authorize it at https://plex.tv/link, then prints your auth token to stdout.
#
# Status/prompts go to stderr and the bare token goes to stdout, so:
#   ./plex-token.sh            # interactive, token shown at the end
#   ./plex-token.sh > token    # interactive, token captured to a file
#
# Dependencies: curl, jq

set -euo pipefail

PLEX_API="https://plex.tv/api/v2/pins"
DEFAULT_PRODUCT="Plex Token Generator"
POLL_INTERVAL=5

err() { printf '%s\n' "$*" >&2; }

# --- dependency check ---
for dep in curl jq; do
  if ! command -v "$dep" >/dev/null 2>&1; then
    err "Error: '$dep' is required but not installed."
    exit 1
  fi
done

# --- gather inputs ---
read -rp "Product name [$DEFAULT_PRODUCT]: " product || true
product="${product:-$DEFAULT_PRODUCT}"

client_id="$(cat /proc/sys/kernel/random/uuid)"

# --- request a PIN ---
pin_json="$(curl -fsS -X POST "$PLEX_API" \
  -H "Accept: application/json" \
  --data-urlencode "strong=false" \
  --data-urlencode "X-Plex-Product=$product" \
  --data-urlencode "X-Plex-Client-Identifier=$client_id")" || {
    err "Error: failed to request a PIN from plex.tv."
    exit 1
  }

pin_id="$(jq -r '.id // empty' <<<"$pin_json")"
pin_code="$(jq -r '.code // empty' <<<"$pin_json")"
expires_in="$(jq -r '.expiresIn // 1800' <<<"$pin_json")"

if [[ -z "$pin_id" || -z "$pin_code" ]]; then
  err "Error: unexpected response from plex.tv:"
  err "$pin_json"
  exit 1
fi

deadline=$(( $(date +%s) + expires_in ))

err ""
err "Go to https://plex.tv/link and enter: $pin_code"
err "Waiting for you to authorize (expires in $(( expires_in / 60 )) min)..."

# --- poll for the token ---
while true; do
  if (( $(date +%s) >= deadline )); then
    err ""
    err "Link expired — re-run to try again."
    exit 1
  fi

  sleep "$POLL_INTERVAL"

  poll_json="$(curl -fsS \
    -H "Accept: application/json" \
    "$PLEX_API/$pin_id?code=$pin_code&X-Plex-Client-Identifier=$client_id")" || {
      err "Warning: poll request failed, retrying..."
      continue
    }

  token="$(jq -r '.authToken // empty' <<<"$poll_json")"
  if [[ -n "$token" ]]; then
    err ""
    err "Success! Your Plex token:"
    printf '%s\n' "$token"
    exit 0
  fi

  printf '.' >&2
done
