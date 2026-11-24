# Installing on Windows

This stack was built and tested on Linux. The steps below run the same containers on Windows 10 or 11 using **WSL2** (a real Linux environment inside Windows), **Docker Desktop** and **Tailscale for Windows**.

> **Status:** written from the documented behavior of WSL2, Docker Desktop and Tailscale. It has not yet been tested end to end on a Windows machine. If a step fails, please open an issue with the error message.

## How it fits together

- The repository lives **inside WSL (Ubuntu)**, so every command in the main README works unchanged.
- **Docker Desktop** runs the containers, and its WSL integration makes the `docker` command available in Ubuntu.
- **Tailscale for Windows** gives the machine its tailnet address and HTTPS certificates. `tailscale serve` runs on Windows and forwards to the containers' `127.0.0.1` ports, which Docker Desktop publishes on Windows localhost.
- Every container still listens on `127.0.0.1` only, so nothing is reachable from your local network.

## Requirements

- Windows 10 (22H2) or Windows 11, with virtualization enabled in the BIOS/UEFI.
- 8 GB of RAM or more. The stack needs roughly 2-3 GB on top of Docker Desktop itself.
- A Tailscale account.
- Docker Desktop is free for personal use and small businesses. Check its license terms for other cases.

## 1. Install WSL2 and Ubuntu

Open **PowerShell as Administrator** and run:

```powershell
wsl --install -d Ubuntu
```

Restart when asked, then open **Ubuntu** from the Start menu and create your Linux username and password.

Check that it is version 2:

```powershell
wsl -l -v
```

The `VERSION` column should say `2`.

### Optional: limit WSL memory

By default WSL can take up to half of your RAM. To cap it, create the file `%UserProfile%\.wslconfig` (in your Windows user folder) with:

```ini
[wsl2]
memory=4GB
```

Then run `wsl --shutdown` in PowerShell and reopen Ubuntu.

## 2. Install Docker Desktop

1. Download and install **Docker Desktop for Windows**.
2. Open Docker Desktop, then **Settings > General** and make sure **Use the WSL 2 based engine** is on.
3. Go to **Settings > Resources > WSL integration**, turn on **Ubuntu**, and click **Apply & restart**.

In Ubuntu, check it works:

```bash
docker version
docker compose version
```

Both should print client and server details without errors.

## 3. Install Tailscale

1. Install **Tailscale for Windows** and sign in.
2. In the [Tailscale admin console](https://login.tailscale.com/admin/dns), turn on **MagicDNS** and then **Enable HTTPS**. Without this, `tailscale serve` cannot issue certificates.
3. In PowerShell, find your machine's full name:

   ```powershell
   tailscale status
   ```

   Your machine name plus the tailnet name looks like `mypc.tailnet-name.ts.net`. You will need it as `TS_HOSTNAME` below.

## 4. Get the repository

Do this **inside Ubuntu**, in your Linux home folder. Do not clone under `/mnt/c`, because file access there is much slower and file permissions break.

```bash
sudo apt update && sudo apt install -y git
git clone https://github.com/AmuraXD7/Homelab.git ~/docker
cd ~/docker
```

## 5. Configure

**Environment files.** Copy each example and set your hostname:

```bash
for d in vaultwarden homepage ntfy; do cp "$d/.env.example" "$d/.env"; done
nano vaultwarden/.env    # set TS_HOSTNAME, and ADMIN_TOKEN (see below)
nano homepage/.env       # set TS_HOSTNAME
nano ntfy/.env           # set TS_HOSTNAME
```

`TS_HOSTNAME` is the full Tailscale name from step 3.

**Vaultwarden admin token.** Generate a hash, then paste the whole `ADMIN_TOKEN='$argon2id$...'` line into `vaultwarden/.env`, keeping the single quotes:

```bash
docker run --rm -it vaultwarden/server:1.36.0 /vaultwarden hash
```

The password you type is what you will use at the `/admin` page. If you do not want the admin page, delete the `ADMIN_TOKEN` line from `vaultwarden/compose.yaml`, which disables it.

**Fix the home folder paths.** Two compose files contain the author's Linux home folder. Replace it with yours:

```bash
sed -i "s|/home/amura|$HOME|g" dockge/compose.yaml kavita/compose.yaml
grep -n "$HOME" dockge/compose.yaml kavita/compose.yaml
```

**Books and manga (Kavita).** The default mounts `~/Documents/Books` from your Linux home. To use a folder on your Windows drive instead, edit the volume line in `kavita/compose.yaml`, for example:

```yaml
      - /mnt/c/Users/YourName/Documents/Books:/books:ro
```

Inside that folder, keep one subfolder per series, with no loose files at the top level. Kavita does not support files at the root of a library folder.

**Create the Navidrome folders** so the container user can write to them:

```bash
mkdir -p navidrome/data navidrome/music
```

## 6. Start the stacks

```bash
for d in vaultwarden navidrome searxng dockge homepage uptime-kuma ntfy dozzle cyberchef kavita; do
  (cd "$d" && docker compose up -d)
done
docker ps --format 'table {{.Names}}\t{{.Status}}'
```

All ten containers should be running. The first start downloads several images, so it can take a few minutes.

## 7. Publish on your tailnet

From Ubuntu, call the Windows Tailscale program:

```bash
TAILSCALE=tailscale.exe ./scripts/tailscale-serve.sh
```

If `tailscale.exe` is not found from inside WSL, run the same commands in PowerShell instead:

```powershell
tailscale serve --bg --https=443   http://127.0.0.1:8081   # Vaultwarden
tailscale serve --bg --https=8443  http://127.0.0.1:4533   # Navidrome
tailscale serve --bg --https=10000 http://127.0.0.1:8080   # SearXNG
tailscale serve --bg --https=5000  http://127.0.0.1:5002   # Kavita
tailscale serve --bg --https=3010  http://127.0.0.1:3010   # Homepage
tailscale serve --bg --https=5001  http://127.0.0.1:5001   # Dockge
tailscale serve --bg --https=3001  http://127.0.0.1:3002   # Uptime Kuma
tailscale serve --bg --https=8091  http://127.0.0.1:8091   # ntfy
tailscale serve --bg --https=8888  http://127.0.0.1:8888   # Dozzle
tailscale serve --bg --https=8100  http://127.0.0.1:8100   # CyberChef
tailscale serve status
```

Then open the dashboard from any device on your tailnet:

```
https://mypc.tailnet-name.ts.net:3010
```

## 8. First-run setup

Create the admin accounts in Dockge, Uptime Kuma, Kavita and Navidrome with strong, unique passwords. In Dozzle, turn on login and leave **Actions and shell** off. In Uptime Kuma, choose **SQLite**, add a Docker host with the socket `/var/run/docker.sock`, and add one **Docker Container** monitor per service.

## What differs from Linux

| Item | On Windows |
|---|---|
| `scripts/harden-host.sh` | Linux only (it configures `ufw`). Windows Defender Firewall already blocks incoming connections by default, and every container binds to `127.0.0.1`, so you do not need it. |
| `scripts/backup.sh` | Run it inside Ubuntu with `sudo ./scripts/backup.sh`. It should work with Docker Desktop's WSL integration, but it is untested. |
| `scripts/tailscale-serve.sh` | Run with `TAILSCALE=tailscale.exe`, and without `sudo`. |
| Docker socket | Docker Desktop provides `/var/run/docker.sock` inside Ubuntu, so Dockge, Dozzle and Uptime Kuma work as described in [SECURITY.md](../SECURITY.md). |
| Ports | Containers publish on Windows localhost. If a port is taken by another program, change the left side of the port mapping in that stack's compose file and the matching line in `tailscale serve`. |

## Troubleshooting

- **`docker: command not found` in Ubuntu.** Docker Desktop is not running, or WSL integration for Ubuntu is off. Start Docker Desktop and re-check step 2.
- **`tailscale serve` says HTTPS is not enabled.** Turn on MagicDNS and Enable HTTPS in the admin console (step 3).
- **A port is already in use.** Find the owner in PowerShell with `netstat -ano | findstr :8081`, then stop it or change the port as described above.
- **The browser shows a certificate warning.** You are probably using an address other than the full `*.ts.net` name. Use the name from `tailscale status`, with the port.
- **Slow file access or odd permissions.** The repository is under `/mnt/c`. Move it to your Linux home folder.
- **Kavita shows no books.** The folder has loose files at the top level, or the path in `kavita/compose.yaml` is wrong. Put each book or series in its own subfolder.

## Stopping and updating

```bash
cd ~/docker
for d in */; do [ -f "$d/compose.yaml" ] && (cd "$d" && docker compose down); done
```

To update an image, change its pinned version in the stack's `compose.yaml`, then run `docker compose up -d` in that folder.
