# Raspberry Pi 4 Home Server

A self-hosted home server running on a **Raspberry Pi 4** using Docker Compose. It provides media streaming, network file sharing, ad-blocking DNS, a relational database, a web interface for AI models running elsewhere on your local network, and a Docker management UI.

---

## Services

| Service | Container | Port(s) | Purpose |
|---------|-----------|---------|---------|
| [DuckDNS](https://www.duckdns.org) | `duckdns` | – | Dynamic DNS – keeps your subdomain pointed at your current public IP |
| [Jellyfin](https://jellyfin.org) | `jellyfin` | `8096` (HTTP), `8920` (HTTPS) | Media server – movies, TV, music |
| [Samba](https://www.samba.org) | `samba` | `139`, `445` | SMB/CIFS network file shares |
| [Pi-hole](https://pi-hole.net) | `pihole` | `53` (DNS), `8080` (admin UI) | Network-wide ad blocking & local DNS |
| [PostgreSQL](https://www.postgresql.org) | `postgres` | `5432` | Relational database used by Open WebUI and other services |
| [Open WebUI](https://github.com/open-webui/open-webui) | `open-webui` | `3000` | Browser-based UI for Ollama (AI models on your LAN) |
| [Portainer](https://www.portainer.io) | `portainer` | `9000` (HTTP), `9443` (HTTPS) | Docker management UI – manage containers, images, and volumes |

---

## Prerequisites

- Raspberry Pi 4 (2 GB RAM minimum, 4 GB+ recommended)
- Raspberry Pi OS 64-bit (Bookworm or later)
- A [DuckDNS](https://www.duckdns.org) account and token
- An [Ollama](https://ollama.ai) instance running somewhere on your local network (for Open WebUI)

---

## Quick Start

### 1. Clone the repository

```bash
git clone https://github.com/trmccormick/home-server.git
cd home-server
```

### 2. Run the setup script

```bash
chmod +x scripts/setup.sh
sudo ./scripts/setup.sh
```

This will:
- Update the system and install Docker + Docker Compose
- Create the required data directories under `./data/`
- Create per-service `./env/<service>.env` files from the bundled examples
- Disable the `systemd-resolved` stub listener so Pi-hole can bind to port 53

### 3. Configure your environment

The setup script copies each `env/<service>.env.example` to `env/<service>.env`.  
Edit the files that apply to your setup:

```bash
nano env/common.env      # timezone, PUID/PGID
nano env/duckdns.env     # subdomain & token
nano env/pihole.env      # web password, upstream DNS, server IP
nano env/postgres.env    # database credentials
nano env/open-webui.env  # Ollama URL, DB connection, secret key
nano env/samba.env       # Samba share password
```

Key variables to set:

| File | Variable | Description |
|------|----------|-------------|
| `common.env` | `TZ` | Your timezone, e.g. `America/New_York` |
| `common.env` | `PUID` / `PGID` | Output of `id` for your user |
| `duckdns.env` | `SUBDOMAINS` | Your DuckDNS subdomain (without `.duckdns.org`) |
| `duckdns.env` | `TOKEN` | Your DuckDNS token |
| `pihole.env` | `WEBPASSWORD` | Pi-hole admin password |
| `pihole.env` | `FTLCONF_LOCAL_IPV4` | Static LAN IP of this Raspberry Pi |
| `samba.env` | `SAMBA_PASSWORD` | Password for the `smbuser` Samba account |
| `postgres.env` | `POSTGRES_PASSWORD` | PostgreSQL password |
| `open-webui.env` | `OLLAMA_BASE_URL` | URL of your Ollama server, e.g. `http://192.168.1.200:11434` |
| `open-webui.env` | `DATABASE_URL` | PostgreSQL connection string (update user/password to match `postgres.env`) |
| `open-webui.env` | `WEBUI_SECRET_KEY` | Random secret for Open WebUI session cookies |

### 4. Start all services

```bash
docker compose up -d
```

Check that everything is running:

```bash
docker compose ps
```

---

## Service Details

### DuckDNS

Runs a lightweight updater that refreshes your DuckDNS record every 5 minutes.

- Logs are available via: `docker compose logs duckdns`

### Jellyfin

- **Web UI:** `http://<pi-ip>:8096`
- Media libraries are served from `./data/media` (movies, TV, music sub-directories).
- On first launch, add your libraries pointing to `/media/movies`, `/media/tv`, etc.

### Samba

Two shares are configured out of the box:

| Share | Path on host | Description |
|-------|--------------|-------------|
| `\\<pi-ip>\media` | `./data/media` | Media library (read/write) |
| `\\<pi-ip>\shared` | `./data/shared` | General-purpose share |

Default username: `smbuser` / Password: value of `SAMBA_PASSWORD` in `env/samba.env`

To customise shares, edit `config/samba/smb.conf` then restart the container:

```bash
docker compose restart samba
```

### Pi-hole

- **Admin UI:** `http://<pi-ip>:8080/admin`
- To use Pi-hole as your network DNS, set your router's primary DNS to `<pi-ip>` (or configure individual devices).
- Custom local DNS entries can be added to `config/pihole/custom.list` (format: `<IP>  <hostname>`).

> **Note:** The setup script disables the `systemd-resolved` stub listener so Pi-hole can bind to port 53.

### PostgreSQL

- Accessible on port `5432` from other containers and (optionally) from the host.
- Credentials are set via `POSTGRES_USER`, `POSTGRES_PASSWORD`, and `POSTGRES_DB` in `env/postgres.env`.
- Open WebUI connects to this database automatically via the `DATABASE_URL` in `env/open-webui.env`.

### Open WebUI

- **Web UI:** `http://<pi-ip>:3000`
- Connects to the Ollama server specified by `OLLAMA_BASE_URL` in `env/open-webui.env`.
- Conversation history and user data are stored in PostgreSQL.
- On first launch you will be prompted to create an admin account.

### Portainer

- **Web UI (HTTP):** `http://<pi-ip>:9000`
- **Web UI (HTTPS):** `https://<pi-ip>:9443`
- On first launch you will be prompted to create an admin account and connect to the local Docker environment.
- Portainer has access to the Docker socket and can manage all containers, images, volumes, and networks on this host.
- Persistent Portainer data is stored in `./data/portainer/`.

---

## Directory Structure

```
home-server/
├── docker-compose.yml       # All service definitions
├── env/                     # Per-service environment files (git-ignored)
│   ├── common.env.example   # Shared variables template (TZ, PUID, PGID)
│   ├── duckdns.env.example  # DuckDNS token & subdomain template
│   ├── jellyfin.env.example # (no service-specific vars beyond common)
│   ├── samba.env.example    # Samba password template
│   ├── pihole.env.example   # Pi-hole password & DNS template
│   ├── postgres.env.example # PostgreSQL credentials template
│   ├── open-webui.env.example # Open WebUI & Ollama settings template
│   └── portainer.env.example  # Portainer template (no required vars)
├── data/                    # All persistent container data (git-ignored)
│   ├── duckdns/config/
│   ├── jellyfin/config/
│   ├── media/               # Shared media library (movies, tv, music)
│   ├── shared/              # General-purpose Samba share
│   ├── samba/config/
│   ├── pihole/
│   ├── postgres/data/
│   ├── open-webui/
│   └── portainer/
├── config/
│   ├── samba/
│   │   └── smb.conf         # Samba share configuration
│   └── pihole/
│       └── custom.list      # Pi-hole local DNS overrides
└── scripts/
    └── setup.sh             # One-time bootstrap script
```

> **Note:** `data/` and `env/` are listed in `.gitignore` so runtime data and secrets are never committed.

---

## Updating Services

Pull the latest images and recreate containers:

```bash
docker compose pull
docker compose up -d
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Pi-hole won't start / port 53 in use | Run `sudo systemctl stop systemd-resolved` and re-run the setup script |
| Jellyfin can't find media | Verify files exist under `./data/media/` |
| Samba shares not accessible | Verify firewall allows ports 139/445; confirm `SAMBA_PASSWORD` in `env/samba.env` matches what the client uses |
| Open WebUI can't reach Ollama | Make sure `OLLAMA_BASE_URL` in `env/open-webui.env` is reachable from the Pi (try `curl $OLLAMA_BASE_URL`) |
| PostgreSQL connection refused | Check logs: `docker compose logs postgres`; ensure the healthcheck passes before Open WebUI starts |
| Portainer shows "no environment" | Select **Get Started** and click the **local** environment on first login |

---

## License

MIT
