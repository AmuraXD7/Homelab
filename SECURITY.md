# Security

This is a personal, single-user homelab. This document records what I am protecting, who I am protecting it from, and the controls and trade-offs in the setup. It is written so a reviewer can judge the decisions, not as a promise that the stack is hardened for production.

## What is being protected

| Asset | Why it matters |
|---|---|
| Vaultwarden vault and master password | Holds every other credential |
| Vaultwarden admin token | Controls server-wide settings |
| Docker socket | Access to it is effectively root on the host |
| Tailscale identity and certificates | Gate access to every service |
| Personal data (music, books, logs, monitor history) | Private, and logs can contain secrets |

## Threat model

**In scope**
- Other devices on the same Wi-Fi or LAN reaching a service directly.
- A mistake in the firewall or in a compose file exposing a service.
- Secrets leaking through the git repository or its history.
- A compromised or buggy container reaching the Docker socket.
- Outdated or unexpectedly changed container images.

**Out of scope**
- A compromised tailnet device. Anyone on the tailnet can reach every service port, and nothing here limits that beyond each app's own login.
- A compromised host or physical access to the laptop.
- Targeted attacks. This is not hardened against a determined attacker.

## Controls

**Network exposure**
- Every container publishes its port on `127.0.0.1` only, so it is not reachable from the LAN even if the host firewall is wrong.
- `tailscale serve` publishes services to the tailnet only. Tailscale Funnel (public internet exposure) is not used.
- TLS is terminated by Tailscale with certificates it issues and renews. Vaultwarden runs plain HTTP on localhost behind it.
- The host firewall (`ufw`) denies incoming traffic by default and allows the `tailscale0` interface. `scripts/harden-host.sh` applies this and is a dry run unless given `--apply`.
- Public signups are disabled in Vaultwarden (`SIGNUPS_ALLOWED=false`).

**Secrets**
- Real values live in `.env` files and application data folders, none of which are committed. The repo uses a whitelist `.gitignore`: everything is ignored unless explicitly allowed.
- Each stack ships a `.env.example` with placeholders only.
- The Vaultwarden admin token is stored as an Argon2id hash, not plaintext.
- CI runs gitleaks on every push to catch committed secrets.
- Backups are encrypted with GPG (AES-256) and should be stored off the machine.

**Supply chain**
- Images are pinned to specific versions (Dockge and Uptime Kuma use major-version tags). Updates are deliberate: pull the new tag, test, then change the version.
- GitHub Actions are pinned to major versions. Pinning by commit SHA is a planned improvement.

**Monitoring**
- Uptime Kuma reports whether each container is running. It does not check application health.
- Dozzle provides read-only log access behind its own login.

## Docker socket access

Three services mount `/var/run/docker.sock`. Whoever controls a container with a writable socket can start a privileged container and take over the host, so each mount is a deliberate trade-off.

| Service | Access | Reason |
|---|---|---|
| Dockge | Read/write | Starts, stops and edits stacks. Largest trust assumption in the stack |
| Dozzle | Read-only | Reads container logs. The Actions and Shell features are turned off |
| Uptime Kuma | Read-only | Checks container state |

A read-only socket still exposes container metadata and logs, and logs can contain secrets. These services therefore stay on localhost behind Tailscale, and Dozzle and Dockge require a login.

## Known limitations

- **ntfy** has no users or access rules yet, so anyone on the tailnet can publish and subscribe.
- **Tailnet trust.** Any tailnet device can reach every port. Tailscale ACLs restricting devices to specific services are a planned improvement.
- **Dockge** is effectively root on the host through the socket.
- **No image scanning** in CI yet.
- **A service outside this repository** (a separate local dev server) also runs on the same host. It was bound to localhost with a systemd override and is protected by the firewall, but it is not covered by this repo.

## Reporting a problem

This is a personal learning project, but if you spot a security issue in the configuration, please open a GitHub issue or contact me through my GitHub profile. Do not include real secrets, tokens or hostnames in a report.
