#!/usr/bin/env bash
#
# Macro ForgeFit — self-hosting one-command installer.
#
#   ./install.sh                                   # home-network setup
#   ./install.sh --domain me.duckdns.org \         # + internet access with
#                --duckdns-token <token>           #   automatic HTTPS
#
# It installs Docker (if missing), generates strong secrets, starts the
# stack, and tells you where to point the app. Safe to re-run — it never
# overwrites secrets you already have, and re-running just pulls the latest
# images and restarts. See SELF-HOSTING.md for the full walkthrough.

set -euo pipefail

# ── args ────────────────────────────────────────────────────────────────
DOMAIN=""
DUCKDNS_TOKEN=""
DUCKDNS_SUBDOMAIN=""

usage() {
  sed -n '3,15p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --domain)            DOMAIN="${2:-}"; shift 2 ;;
    --duckdns-token)     DUCKDNS_TOKEN="${2:-}"; shift 2 ;;
    --duckdns-subdomain) DUCKDNS_SUBDOMAIN="${2:-}"; shift 2 ;;
    -h|--help)           usage 0 ;;
    *) echo "Unknown option: $1" >&2; usage 1 ;;
  esac
done

# derive the DuckDNS subdomain from the domain if not given (me.duckdns.org -> me)
if [ -n "$DOMAIN" ] && [ -z "$DUCKDNS_SUBDOMAIN" ]; then
  DUCKDNS_SUBDOMAIN="${DOMAIN%%.*}"
fi
if [ -n "$DOMAIN" ] && [ -z "$DUCKDNS_TOKEN" ]; then
  echo "Error: --domain needs --duckdns-token as well (get it from https://www.duckdns.org/)." >&2
  exit 1
fi

cd "$(dirname "$0")"

say()  { printf '\n\033[1;36m%s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m%s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m%s\033[0m\n' "$*"; }

random_hex() { LC_ALL=C tr -dc 'a-f0-9' < /dev/urandom | head -c "${1:-32}"; }

# ── 1. Docker ───────────────────────────────────────────────────────────
say "1/4  Checking Docker…"
if ! command -v docker >/dev/null 2>&1; then
  warn "Docker is not installed."
  if [ "$(uname -s)" != "Linux" ]; then
    echo "Automatic Docker install is Linux-only." >&2
    echo "  - macOS / Windows: install Docker Desktop" >&2
    echo "    (https://docs.docker.com/get-docker/), then re-run this script" >&2
    echo "    (on Windows, run it from a WSL2 shell), or just follow the manual" >&2
    echo "    'docker compose up -d' steps in SELF-HOSTING.md." >&2
    exit 1
  fi
  printf "Install Docker now using Docker's official script? [Y/n] "
  read -r reply || reply="y"
  case "${reply:-y}" in
    [nN]*) echo "Install Docker yourself, then re-run this script." >&2; exit 1 ;;
  esac
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker "$USER" || true
  warn "Docker installed. If the steps below fail with a permission error,"
  warn "log out and back in (group change) and re-run ./install.sh."
fi

# Use sudo for docker only if the current user can't reach the daemon yet.
DOCKER="docker"
if ! docker info >/dev/null 2>&1; then
  DOCKER="sudo docker"
fi

if ! $DOCKER compose version >/dev/null 2>&1; then
  echo "The Docker Compose plugin is missing. Install it with:" >&2
  echo "    sudo apt-get install -y docker-compose-plugin" >&2
  exit 1
fi
ok "Docker is ready."

# ── 2. Secrets (.env) ───────────────────────────────────────────────────
say "2/4  Preparing secrets…"
touch .env
add_env() {  # add_env KEY VALUE — only if KEY not already present
  local key="$1" val="$2"
  if ! grep -q "^${key}=" .env; then
    printf '%s=%s\n' "$key" "$val" >> .env
    echo "  set $key"
  else
    echo "  kept existing $key"
  fi
}
add_env POSTGRES_PASSWORD "$(random_hex 24)"
add_env APP_SEED "$(random_hex 48)"

COMPOSE_FILES=(-f docker-compose.yml)
if [ -n "$DOMAIN" ]; then
  add_env DOMAIN "$DOMAIN"
  add_env DUCKDNS_SUBDOMAIN "$DUCKDNS_SUBDOMAIN"
  add_env DUCKDNS_TOKEN "$DUCKDNS_TOKEN"
  COMPOSE_FILES+=(-f docker-compose.https.yml)
fi
ok "Secrets saved to .env (keep this file private)."

# ── 3. Start ────────────────────────────────────────────────────────────
say "3/4  Pulling images and starting…"
$DOCKER compose "${COMPOSE_FILES[@]}" pull
$DOCKER compose "${COMPOSE_FILES[@]}" up -d

# ── 4. Wait until it answers ─────────────────────────────────────────────
say "4/4  Waiting for the server to come up…"
up=""
for _ in $(seq 1 30); do
  if curl -fsS -o /dev/null "http://localhost:8069/" 2>/dev/null; then up=1; break; fi
  sleep 2
done

detect_ip() {
  local ip
  ip="$(hostname -I 2>/dev/null | awk '{print $1}')"          # Linux
  [ -n "$ip" ] && { echo "$ip"; return; }
  if command -v ipconfig >/dev/null 2>&1; then                # macOS
    for i in en0 en1 en2; do
      ip="$(ipconfig getifaddr "$i" 2>/dev/null)" || true
      [ -n "$ip" ] && { echo "$ip"; return; }
    done
  fi
  if command -v ifconfig >/dev/null 2>&1; then                # generic fallback
    ip="$(ifconfig 2>/dev/null | awk '/inet /{print $2}' | grep -v '^127\.' | head -n1)"
    [ -n "$ip" ] && { echo "$ip"; return; }
  fi
  echo "<this-server-ip>"
}
IP="$(detect_ip)"

echo
if [ -n "$up" ]; then
  ok "✅ Macro ForgeFit is running."
else
  warn "Containers are starting but the web page didn't answer yet."
  warn "Give it another minute, then check:  $DOCKER compose ps"
fi

if [ -n "$DOMAIN" ]; then
  cat <<EOF

  Local address :  http://$IP:8069
  Public address:  https://$DOMAIN   (once the certificate is issued —
                   needs ports 80 + 443 forwarded to this machine)
EOF
else
  echo
  echo "  Address:  http://$IP:8069"
fi

cat <<EOF

Next steps:
  1. Open Macro ForgeFit on your phone → Settings → Server connection.
  2. Enter the address above and tap "Save & test".
  3. Tap "Create an account" — THE FIRST ACCOUNT BECOMES THE HOUSEHOLD OWNER.
  4. Everyone else in the household registers their own account the same way.

Manage later:
  $DOCKER compose ${COMPOSE_FILES[*]} ps       # status
  $DOCKER compose ${COMPOSE_FILES[*]} logs -f  # logs
  ./install.sh${DOMAIN:+ --domain $DOMAIN --duckdns-token …}   # update to latest
EOF
