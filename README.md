# Raspberry Pi 4 Home Server

A self-hosted home server running on a **Raspberry Pi 4** using Docker Compose. It provides media streaming, network file sharing, ad-blocking DNS, a relational database, and a web interface for AI models running elsewhere on your local network.

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

---

## Prerequisites

- Raspberry Pi 4 (2 GB RAM minimum, 4 GB+ recommended)
- Raspberry Pi OS 64-bit (Bookworm or later)
- An external drive or NAS mount at `/mnt/data` (recommended for media)
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
- Create the required data directories under `/mnt/data`
- Disable the `systemd-resolved` stub listener so Pi-hole can bind to port 53
- Generate a `.env` file from `.env.example`

### 3. Configure your environment

```bash
nano .env
```

At minimum, set:

| Variable | Description |
|----------|-------------|
| `TZ` | Your timezone, e.g. `America/New_York` |
| `PUID` / `PGID` | Output of `id` for your user |
| `DATA_DIR` | Root directory for persistent data (default `/mnt/data`) |
| `DUCKDNS_SUBDOMAINS` | Your DuckDNS subdomain (without `.duckdns.org`) |
| `DUCKDNS_TOKEN` | Your DuckDNS token |
| `SERVER_IP` | Static LAN IP of this Raspberry Pi |
| `PIHOLE_WEB_PASSWORD` | Pi-hole admin password |
| `SAMBA_PASSWORD` | Password for the `smbuser` Samba account |
| `POSTGRES_PASSWORD` | PostgreSQL password |
| `OLLAMA_BASE_URL` | URL of your Ollama server, e.g. `http://192.168.1.200:11434` |
| `WEBUI_SECRET_KEY` | Random secret for Open WebUI session cookies |

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
- Media is mapped from `${JELLYFIN_MEDIA_DIR}` (default `/mnt/data/media`) to `/media` inside the container.
- On first launch, add your libraries pointing to `/media/movies`, `/media/tv`, etc.

### Samba

Two shares are configured out of the box:

| Share | Path on host | Description |
|-------|--------------|-------------|
| `\\<pi-ip>\media` | `/mnt/data/media` | Media library (read/write) |
| `\\<pi-ip>\shared` | `/mnt/data/shared` | General-purpose share |

Default username: `smbuser` / Password: value of `SAMBA_PASSWORD` in `.env`

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
- Credentials are set via `POSTGRES_USER`, `POSTGRES_PASSWORD`, and `POSTGRES_DB` in `.env`.
- Open WebUI connects to this database automatically via the `DATABASE_URL` environment variable.

### Open WebUI

- **Web UI:** `http://<pi-ip>:3000`
- Connects to the Ollama server specified by `OLLAMA_BASE_URL`.
- Conversation history and user data are stored in PostgreSQL.
- On first launch you will be prompted to create an admin account.

---

## Directory Structure

```
home-server/
├── docker-compose.yml       # All service definitions
├── .env.example             # Environment variable template
├── .env                     # Your configuration (git-ignored)
├── config/
│   ├── samba/
│   │   └── smb.conf         # Samba share configuration
│   └── pihole/
│       └── custom.list      # Pi-hole local DNS overrides
└── scripts/
    └── setup.sh             # One-time bootstrap script
```

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
| Jellyfin can't find media | Check that `JELLYFIN_MEDIA_DIR` is set correctly in `.env` |
| Samba shares not accessible | Verify firewall allows ports 139/445; confirm `SAMBA_PASSWORD` matches what the client uses |
| Open WebUI can't reach Ollama | Make sure `OLLAMA_BASE_URL` is reachable from the Pi (try `curl $OLLAMA_BASE_URL`) |
| PostgreSQL connection refused | Check logs: `docker compose logs postgres`; ensure the healthcheck passes before Open WebUI starts |

---

## License

MIT
