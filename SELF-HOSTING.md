# Self-hosting Macro ForgeFit

Macro ForgeFit works standalone on your phone with no setup — all your
data stays on the device. This guide is for the optional alternative:
running your own backend server (Docker + PostgreSQL) so your data lives
on a machine you control instead, can be shared across multiple devices,
and can be shared by several people in your household — each with their
own private account and data, on one server.

If you just want to use the app, you don't need any of this.

Two ways through this guide:

- **The easy way** — one script (`./install.sh`) installs Docker if it's
  missing, generates strong secrets for you, and starts everything. Jump
  to [Quick start](#quick-start-the-easy-way).
- **By hand** — if you'd rather understand and run each step yourself, see
  [Manual setup](#manual-setup).

Then everyone points their phone at the server ([step 5](#5-point-the-app-at-your-server)),
and — optionally — you make it reachable securely over the internet with
[automatic HTTPS](#optional-reach-it-over-the-internet-with-automatic-https).

---

## What you need

- **A machine that can run Docker** — a Raspberry Pi, a home server, a NAS,
  an Umbrel box, a cloud VM, an old laptop; anything Linux-based. The app
  images are published for both **x86-64 (amd64)** and **ARM64**, so they
  run on ordinary Intel/AMD boxes as well as ARM devices like a Pi.
- **A few minutes at a terminal on that machine.** Everything below is
  copy-paste.

You do **not** need to buy a domain, open any ports, or expose anything to
the internet for the basic (home-network) setup. That's only needed for the
optional [internet-access](#optional-reach-it-over-the-internet-with-automatic-https)
section at the end.

> **CPU architecture** doesn't matter — the app images are multi-arch
> (**amd64 + ARM64**), so the exact same steps work on an Intel/AMD box and on
> a Raspberry Pi; Docker pulls the right one automatically.
>
> **On Windows?** The one-command `install.sh` is a Linux/macOS shell script,
> so run it inside **WSL2** (which is Linux). Or install **Docker Desktop** and
> follow the [Manual setup](#manual-setup) `docker compose up -d` steps — those
> are fully cross-platform. (**macOS** works either way: install Docker Desktop
> first, then the script or the manual steps.)

---

## Quick start (the easy way)

On the machine that will be your server:

```bash
git clone https://github.com/fazle1337-del/macro-tracker-public-info.git
cd macro-tracker-public-info
chmod +x install.sh
./install.sh
```

`install.sh` will:

1. Check for Docker and the Docker Compose plugin, and offer to install
   them for you if they're missing (Linux only — it uses Docker's official
   installer).
2. Generate a strong random database password and `APP_SEED` (the key that
   signs your login tokens and encrypts saved backup credentials) and save
   them to a local `.env` file, so you never run on guessable defaults.
3. Start the three containers and wait until the server is healthy.
4. Print the address to type into the app.

When it finishes it prints something like:

```
✅ Macro ForgeFit is running at:  http://192.168.1.50:8069

Next: open the app → Settings → Server connection, enter that URL,
tap Save & test, then CREATE THE FIRST ACCOUNT — that account becomes
the household owner.
```

That's it. Skip to [step 4 (create your account)](#4-create-your-account-first-user-is-the-owner).

> Want internet access with HTTPS too? Run it with a domain:
> `./install.sh --domain yourname.duckdns.org --duckdns-token <token>` — see
> [the HTTPS section](#optional-reach-it-over-the-internet-with-automatic-https)
> for what that sets up and the one-time router/DNS steps it needs.

---

## Manual setup

Prefer to do it yourself? Here's every step the script automates.

### 1. Install Docker (skip if you already have it)

On most Linux servers (Raspberry Pi OS, Debian, Ubuntu), Docker's own
convenience script is the quickest route:

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker "$USER"   # so you can run docker without sudo
```

Log out and back in (or reboot) after the `usermod` line so the group
change takes effect. Verify:

```bash
docker --version
docker compose version
```

If `docker compose version` errors, install the Compose plugin:
`sudo apt-get install -y docker-compose-plugin`. Full instructions for
other systems: <https://docs.docker.com/get-docker/>.

### 2. Get the files

```bash
git clone https://github.com/fazle1337-del/macro-tracker-public-info.git
cd macro-tracker-public-info
```

(Or copy `docker-compose.yml` from this repo to your server by any means
you like — nothing else is required; the app images are pulled from
Docker Hub.)

### 3. Set your secrets

`docker-compose.yml` reads two values from the environment, each with a
safe-to-run default so it works out of the box:

- `POSTGRES_PASSWORD` — the database password.
- `APP_SEED` — signs the login tokens for every account **and** encrypts
  your saved backup / Open Food Facts credentials at rest. Because it now
  signs auth tokens, changing it later logs everyone out (they just sign in
  again — no data is lost).

**On a private home network** (the usual case — a Pi or box at home) the
defaults are fine; you can skip straight to starting it. **If you'll expose
this server to the internet**, set your own values first. The simplest way
is a `.env` file next to `docker-compose.yml`:

```bash
cat > .env <<EOF
POSTGRES_PASSWORD=$(openssl rand -hex 16)
APP_SEED=$(openssl rand -hex 32)
EOF
```

Compose picks that `.env` up automatically. (`install.sh` writes exactly
this file for you.)

### 4. Start it

```bash
docker compose up -d
```

This starts three containers — a PostgreSQL database, the API server, and
the web frontend — and exposes everything on **port 8069**. Find your
server's address:

```bash
hostname -I   # local network IP, e.g. 192.168.1.50
```

Your server is now reachable at `http://<that-ip>:8069` on your local
network.

---

## 4. Create your account (first user is the owner)

Macro ForgeFit's server mode is **multi-user**. Instead of a shared
password or API key, everyone who uses the server gets their **own account**
(username + password), and their logged data is private to them. The food
database is shared, so nobody has to re-enter common foods.

The very **first person to register becomes the household _owner_**. On that
first registration:

- Any data that already existed on the server (for example if you're
  upgrading from an older single-user version) is adopted into the owner's
  account automatically.
- The owner gets an extra **Manage household** panel in Settings — they can
  see the member list, remove a member, or reset a member's password.

Everyone else in the household just registers their own account on the same
server afterwards. Members are private by default; each member can opt in to
sharing their daily progress with the household via a toggle in
**Settings → Server connection** ("Share my progress with the household").

You create your account from the phone app in the next step — there's
nothing to set up on the server for it.

---

## 5. Point the app at your server

On your phone, open Macro ForgeFit → **Settings → Server connection**:

- **Server URL** — your server's address, e.g. `http://192.168.1.50:8069`
  (or your HTTPS address if you set one up below).

Tap **Save & test**. The app checks the server can be reached, then shows a
**sign-in screen**:

- **First time on this server?** Tap **Create an account**, pick a username
  and password. (Remember: the first account created on a brand-new server
  is the owner.)
- **Joining a server someone else set up?** Just create your own account the
  same way — you'll get your own private space.
- **Coming back on another device?** Sign in with the account you already
  made.

> There is **no "API key"** field any more — older versions of this app used
> one shared key; that's been replaced by per-person accounts. If a guide or
> screenshot mentions an API key, it's out of date.

Signing in is what switches the app from phone-only mode over to your
server — from then on, all your logging reads and writes to your server.

If you already had entries logged on this phone in standalone mode, you'll
be offered the choice to upload them to your account on the server before
switching. **Uploading replaces what's on the server for _your account_**,
so do it once, when your server account is still empty.

---

## Updating later

```bash
docker compose pull
docker compose up -d
```

(Or just re-run `./install.sh` — it pulls the latest images and restarts.)

---

## Optional: reach it over the internet with automatic HTTPS

The basic setup above only works on your home network. To reach your server
from anywhere (mobile data, a friend's house) **and** encrypt the connection
with a real HTTPS certificate, this repo includes a ready-made
[Caddy](https://caddyserver.com/) reverse proxy that gets and renews
Let's Encrypt certificates **automatically** — no certbot, no cron, no
manual renewal. It's paired with a [DuckDNS](https://www.duckdns.org/)
updater so a free `yourname.duckdns.org` hostname always points at your home
IP, even when your ISP changes it.

### What you'll need first (one-time)

1. **A free DuckDNS hostname.** Sign in at <https://www.duckdns.org/> (with
   Google/GitHub), create a subdomain like `yourname`, and copy your
   **token** from the top of the page. Your hostname is
   `yourname.duckdns.org`.
2. **Two ports forwarded on your router** to your server machine: **80** and
   **443** (TCP). This is the one step only you can do — it's in your
   router's admin page under "Port forwarding". Caddy needs port 80 reachable
   to prove ownership and issue the certificate, and 443 to serve HTTPS.

### Start it with HTTPS

```bash
# with the install script:
./install.sh --domain yourname.duckdns.org --duckdns-token YOUR_TOKEN

# or by hand:
cat >> .env <<EOF
DOMAIN=yourname.duckdns.org
DUCKDNS_SUBDOMAIN=yourname
DUCKDNS_TOKEN=YOUR_TOKEN
EOF
docker compose -f docker-compose.yml -f docker-compose.https.yml up -d
```

This adds two more containers:

- **Caddy** — listens on 80/443, obtains and auto-renews a Let's Encrypt
  certificate for your domain, and reverse-proxies to the app.
- **DuckDNS updater** — keeps `yourname.duckdns.org` pointed at your current
  home IP.

Give it a minute the first time (certificate issuance). Then, on your phone,
set **Server URL** to `https://yourname.duckdns.org` (no port needed — 443 is
the default) and sign in as usual. It now works from anywhere.

> Prefer not to open any router ports? [Tailscale](https://tailscale.com/) is
> a good alternative — install it on the server and each phone, and use the
> server's Tailscale address as your Server URL. No ports, no domain, no
> certificate needed, but every device must have Tailscale installed.

---

## Umbrel users

If you're already running [Umbrel](https://umbrel.com/) and would rather
install this as an app than run `docker compose` by hand, you can add this
repository as a **custom community app store**: Umbrel → App Store →
(top-right ⋯) → *Community App Stores* → add
`https://github.com/fazle1337-del/macro-tracker-public-info`. It shows up as
the **"Macro ForgeFit" App Store**, and Macro ForgeFit installs from there
like any other app (Umbrel manages its data and updates for you). The plain
`docker compose` steps above are the alternative for non-Umbrel hosts.

---

## Troubleshooting

- **`docker: permission denied`** — you skipped the log-out after
  `usermod -aG docker`. Log out/in, or prefix commands with `sudo`.
- **Phone says "couldn't connect"** — check the URL and port
  (`http://IP:8069`), and that the phone is on the same Wi-Fi as the server.
  Test from a computer first: open `http://IP:8069` in a browser.
- **"Failed to fetch" / stuck "Syncing…" over HTTPS** — the app is loaded
  over HTTPS but your Server URL is plain `http://`. Use the `https://`
  address once you've set up the Caddy section above.
- **Forgot the owner account** — the owner is whoever registered first.
  There's no separate admin login; if you're locked out entirely, you can
  reset by stopping the stack and removing the database volume
  (`docker compose down -v`) — but that erases all logged data, so it's a
  last resort.
- **See what's running / logs**: `docker compose ps` and
  `docker compose logs -f`.
