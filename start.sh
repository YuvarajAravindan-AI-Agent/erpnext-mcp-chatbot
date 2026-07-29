#!/usr/bin/env bash
# Single-command startup for erpnext-mcp-chatbot: brings up ERPNext itself
# (Docker), the read-only proxy, and the tunnel watcher (auto-syncs the
# public URL to Vercel). Mirrors tally-chatbot/odoo19-mcp-chatbot's start.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROXY_LOG="/tmp/erpnext-proxy.log"
TUNNEL_LOG="/tmp/erpnext-cloudflared.log"
WATCH_LOG="/tmp/erpnext-tunnel-watch.log"
STATE_FILE="$HOME/.config/erpnext-chatbot/tunnel_url"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== ERPNext Chatbot Startup ===${NC}\n"

echo "Checking prerequisites..."

# 1. Check ERPNext is up; launch its Docker stack if not (site already exists
#    from initial setup, so `up -d` just brings containers back, not a fresh install).
if ! curl -sf -o /dev/null "http://localhost:8080/api/method/ping" 2>/dev/null; then
  echo -e "${YELLOW}⚠ ERPNext not responding on :8080 — starting containers...${NC}"
  (cd "$SCRIPT_DIR/frappe_docker" && docker compose -f pwd.yml -p erpnext up -d)
  echo "  Waiting for ERPNext to come up (can take ~30-60s)..."
  READY=0
  for _ in $(seq 1 120); do
    if curl -sf -o /dev/null "http://localhost:8080/api/method/ping" 2>/dev/null; then
      READY=1
      break
    fi
    sleep 1
  done
  if [ "$READY" = "1" ]; then
    echo -e "${GREEN}✓ ERPNext is up on :8080${NC}"
  else
    echo -e "${RED}✗ ERPNext didn't come up within 120s.${NC}"
    echo "  Check: cd frappe_docker && docker compose -f pwd.yml -p erpnext logs --tail 50"
    exit 1
  fi
else
  echo -e "${GREEN}✓ ERPNext already running on :8080${NC}"
fi

# 2. Check proxy venv exists
if [ ! -d "$SCRIPT_DIR/proxy/.venv" ]; then
  echo -e "${RED}✗ Error: Python venv not found at proxy/.venv${NC}"
  echo "  Run: cd proxy && python3 -m venv .venv && .venv/bin/pip install -r requirements.txt"
  exit 1
fi

# 3. Check cloudflared is installed
if [ ! -f "$HOME/bin/cloudflared" ]; then
  echo -e "${RED}✗ Error: cloudflared not found at ~/bin/cloudflared${NC}"
  exit 1
fi

echo -e "${GREEN}✓ Prerequisites OK${NC}\n"

# Start proxy
echo "Starting proxy server on port 8789..."
if ss -tln 2>/dev/null | grep -q ':8789'; then
  echo -e "${GREEN}✓ Proxy already running on :8789${NC}"
else
  setsid "$SCRIPT_DIR/proxy/.venv/bin/uvicorn" --app-dir "$SCRIPT_DIR/proxy" main:app \
    --host 127.0.0.1 --port 8789 >"$PROXY_LOG" 2>&1 < /dev/null &
  sleep 2

  if ss -tln 2>/dev/null | grep -q ':8789'; then
    echo -e "${GREEN}✓ Proxy started (log: $PROXY_LOG)${NC}"
  else
    echo -e "${RED}✗ Proxy failed to start. Check $PROXY_LOG:${NC}"
    cat "$PROXY_LOG"
    exit 1
  fi
fi

# Start the tunnel watcher (cloudflared quick tunnel + auto-sync to Vercel on URL change)
echo "Starting tunnel watcher..."
if pgrep -f "erpnext-mcp-chatbot/watch-tunnel.sh" >/dev/null 2>&1; then
  echo -e "${GREEN}✓ Tunnel watcher already running${NC}\n"
else
  : >"$WATCH_LOG"
  setsid "$SCRIPT_DIR/watch-tunnel.sh" >/dev/null 2>&1 < /dev/null &
  echo "  waiting for tunnel + Vercel sync (can take ~45s)..."
  for _ in $(seq 1 90); do
    [ -s "$STATE_FILE" ] && grep -q "sync complete" "$WATCH_LOG" 2>/dev/null && break
    sleep 1
  done
  if [ -s "$STATE_FILE" ]; then
    echo -e "${GREEN}✓ Tunnel up + synced to Vercel${NC}\n"
  else
    echo -e "${YELLOW}⚠ Tunnel still starting — check $WATCH_LOG${NC}\n"
  fi
fi

TUNNEL_URL=$(cat "$STATE_FILE" 2>/dev/null || echo "(pending — check $WATCH_LOG)")

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ ERPNext Chatbot is ready!${NC}"
echo -e "${GREEN}========================================${NC}\n"

echo "Local Services:"
echo "  ERPNext:  http://127.0.0.1:8080 (internal — Administrator / admin)"
echo "  Proxy:    http://127.0.0.1:8789 (internal)"
echo "  Tunnel:   $TUNNEL_URL (public, changes on restart — auto-synced to Vercel)"
echo ""
echo "Access Chatbot:"
echo "  https://erpnext-chatbot-alpha.vercel.app"
echo ""
echo "Test it:"
echo "  1. Open the chatbot URL"
echo "  2. Enter passcode: demo1234"
echo "  3. Ask: 'What is my total receivables?'"
echo ""
echo "MCP (for Claude Code/Desktop): wired via .mcp.json in this folder"
echo ""
echo "Logs:"
echo "  tail -f $PROXY_LOG   (proxy debug)"
echo "  tail -f $TUNNEL_LOG  (tunnel debug)"
echo "  tail -f $WATCH_LOG   (watcher / Vercel sync debug)"
echo ""
echo "Stop services:"
echo "  ./stop"
echo ""
