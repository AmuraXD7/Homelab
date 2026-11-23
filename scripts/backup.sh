#!/usr/bin/env bash
# Encrypted backup of the whole stack directory (compose files + data).
# Usage: sudo ./scripts/backup.sh
#
# Briefly stops the SQLite-backed services so their databases are consistent,
# archives the stack directory, encrypts it with GPG (AES-256), and restarts
# whatever it stopped. Needs sudo because containers write some data as root.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Run with sudo (some data folders are owned by root)." >&2
  exit 1
fi

STACK_DIR="${STACK_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
OWNER="${SUDO_USER:-root}"
OWNER_HOME="$(getent passwd "$OWNER" | cut -d: -f6)"
BACKUP_DIR="${BACKUP_DIR:-$OWNER_HOME/backups}"
STOP_CONTAINERS="${STOP_CONTAINERS:-vaultwarden navidrome kavita uptime-kuma}"
OUT="$BACKUP_DIR/homelab-$(date +%F).tar.gz.gpg"

mkdir -p "$BACKUP_DIR"
chown "$OWNER": "$BACKUP_DIR"

stopped=()

restart_stopped() {
  if ((${#stopped[@]})); then
    for c in "${stopped[@]}"; do
      docker start "$c" >/dev/null || true
    done
  fi
}
trap restart_stopped EXIT

for c in $STOP_CONTAINERS; do
  if [[ "$(docker inspect -f '{{.State.Running}}' "$c" 2>/dev/null || true)" == "true" ]]; then
    docker stop "$c" >/dev/null
    stopped+=("$c")
    echo "stopped $c"
  fi
done

echo "Creating $OUT (you will be asked for a passphrase)..."
tar -C "$(dirname "$STACK_DIR")" -czf - --exclude='.git' "$(basename "$STACK_DIR")" \
  | gpg --symmetric --cipher-algo AES256 -o "$OUT"

chown "$OWNER": "$OUT"
echo "Done: $OUT ($(du -h "$OUT" | cut -f1))"
echo "Next: copy it off this machine, then test a restore with:"
echo "  gpg -d \"$OUT\" | tar tz | head"
