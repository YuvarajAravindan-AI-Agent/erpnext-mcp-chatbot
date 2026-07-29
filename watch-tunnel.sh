#!/usr/bin/env bash
# Keeps a cloudflared quick tunnel alive in front of the ERPNext proxy, and
# whenever the tunnel (re)starts and gets a new trycloudflare.com URL,
# automatically pushes it to Vercel (ERPNEXT_PROXY_URL) and redeploys.
set -uo pipefail
cd "$(dirname "$0")"

STATE_FILE="$HOME/.config/erpnext-chatbot/tunnel_url"
LOG=/tmp/erpnext-cloudflared.log
WATCH_LOG=/tmp/erpnext-tunnel-watch.log
WEB_DIR="$(pwd)/web"
mkdir -p "$(dirname "$STATE_FILE")"

log() { echo "$(date -Iseconds) $*" >>"$WATCH_LOG"; }

sync_vercel() {
  local url="$1"
  log "syncing new tunnel URL to Vercel: $url"
  (
    cd "$WEB_DIR" || exit 1
    vercel env rm ERPNEXT_PROXY_URL production --yes >>"$WATCH_LOG" 2>&1
    printf '%s' "$url" | vercel env add ERPNEXT_PROXY_URL production >>"$WATCH_LOG" 2>&1
    vercel --prod --yes >>"$WATCH_LOG" 2>&1
  )
  echo "$url" >"$STATE_FILE"
  log "sync complete"
}

log "watcher starting"

while true; do
  : >"$LOG"
  /home/yuvaraj/bin/cloudflared tunnel --url http://localhost:8789 --logfile "$LOG" &
  CF_PID=$!

  URL=""
  for _ in $(seq 1 30); do
    URL=$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$LOG" | tail -1)
    [ -n "$URL" ] && break
    sleep 1
  done

  if [ -n "$URL" ]; then
    OLD=$(cat "$STATE_FILE" 2>/dev/null || echo "")
    if [ "$URL" != "$OLD" ]; then
      sync_vercel "$URL"
    else
      log "tunnel URL unchanged: $URL"
    fi
  else
    log "failed to obtain tunnel URL from $LOG"
  fi

  wait "$CF_PID"
  log "cloudflared exited, restarting in 5s"
  sleep 5
done
