#!/usr/bin/env bash
# Baseline host hardening for a Debian/Ubuntu machine running this stack.
# Safe to run more than once. Dry run by default; nothing changes without --apply.
#
# Usage:
#   sudo ./scripts/harden-host.sh            # show what would happen
#   sudo ./scripts/harden-host.sh --apply    # make the changes
#
# Optional: ALLOW_LAN_SSH=1 also opens SSH (rate limited) to the local network.
# By default SSH is reachable only over the tailnet.
set -euo pipefail

APPLY=0
if [[ "${1:-}" == "--apply" ]]; then
  APPLY=1
fi

if [[ $EUID -ne 0 ]]; then
  echo "Run with sudo." >&2
  exit 1
fi

run() {
  if ((APPLY)); then
    echo "+ $*"
    "$@"
  else
    echo "[dry-run] $*"
  fi
}

write_sshd_conf() {
  local conf=/etc/ssh/sshd_config.d/99-hardening.conf
  cat >"$conf" <<'CONF'
PasswordAuthentication no
PermitRootLogin no
CONF
  if sshd -t; then
    systemctl reload ssh 2>/dev/null || systemctl reload sshd
    echo "sshd hardened"
  else
    rm -f "$conf"
    echo "sshd config test failed; change reverted" >&2
    return 1
  fi
}

echo "== Firewall (ufw) =="
run apt-get install -y ufw
run ufw default deny incoming
run ufw default allow outgoing
run ufw allow in on tailscale0
if [[ "${ALLOW_LAN_SSH:-0}" == "1" ]]; then
  run ufw limit 22/tcp
fi
run ufw --force enable

echo "== SSH =="
if command -v sshd >/dev/null 2>&1 && [[ -d /etc/ssh/sshd_config.d ]]; then
  user="${SUDO_USER:-}"
  keys="$(getent passwd "$user" | cut -d: -f6)/.ssh/authorized_keys"
  if [[ -n "$user" && -s "$keys" ]]; then
    if ((APPLY)); then
      write_sshd_conf
    else
      echo "[dry-run] disable SSH password login and root login (key found for $user)"
    fi
  else
    echo "Skipping: no authorized_keys for the invoking user, so disabling passwords could lock you out."
  fi
else
  echo "Skipping: sshd is not installed."
fi

echo "== Automatic security updates =="
run apt-get install -y unattended-upgrades
run dpkg-reconfigure -f noninteractive unattended-upgrades

if ((APPLY)); then
  echo "Done."
else
  echo "Dry run only. Re-run with --apply to make these changes."
fi
