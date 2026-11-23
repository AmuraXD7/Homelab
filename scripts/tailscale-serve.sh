#!/usr/bin/env bash
# Publish each local service over Tailscale HTTPS (tailnet only, not Funnel).
# Services listen on 127.0.0.1; Tailscale terminates TLS.
# Usage: sudo ./scripts/tailscale-serve.sh
set -euo pipefail

serve() {
  # serve <tailnet-https-port> <local-port> <label>
  tailscale serve --bg --https="$1" "http://127.0.0.1:$2" # "$3"
  echo "published $3: tailnet :$1 -> 127.0.0.1:$2"
}

serve 443   8081 "Vaultwarden"
serve 8443  4533 "Navidrome"
serve 10000 8080 "SearXNG"
serve 5000  5002 "Kavita"
serve 3010  3010 "Homepage"
serve 5001  5001 "Dockge"
serve 3001  3002 "Uptime Kuma"
serve 8091  8091 "ntfy"
serve 8888  8888 "Dozzle"
serve 8100  8100 "CyberChef"

tailscale serve status
