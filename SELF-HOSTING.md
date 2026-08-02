# Self-hosting Macro ForgeFit

Macro ForgeFit works standalone on your phone with no setup — all your
data stays on the device. This guide is for the optional alternative:
running your own backend server (Docker + PostgreSQL) so your data lives
on a machine you control instead, and can be shared across multiple
devices.

If you just want to use the app, you don't need any of this.

## What you need

- A machine that can run Docker (a Raspberry Pi, a home server, a NAS,
  an Umbrel box, a cloud VM — anything). The app images are published for
  both **x86-64 (amd64)** and **ARM64**, so they run on ordinary Intel/AMD
  servers, VMs and NAS boxes as well as ARM devices like a Raspberry Pi.
- [Docker](https://docs.docker.com/get-docker/) and the Docker Compose
  plugin installed on it.

## 1. Get the files

```bash
git clone https://github.com/fazle1337-del/macro-tracker-public-info.git
cd macro-tracker-public-info
```

(Or copy `docker-compose.yml` from this repo to your server by any means
you like — nothing else is required, the app images are pulled from
Docker Hub.)

## 2. Change the default secrets (only if internet-facing)

`docker-compose.yml` ships with placeholder credentials so it runs out of
the box:

- `POSTGRES_PASSWORD: changeme123` — the database password
- `API_SECRET: myapisecret123` — the key the app uses to talk to your server
- `APP_SEED: change-this-to-a-long-random-string` — encrypts your saved
  backup / Open Food Facts tokens at rest

**If your server only lives on your own private network** (the usual case —
a Pi or box at home), the defaults are fine. Leave them and skip to step 3.

**If you expose the server to the internet** (a public IP, a domain, a
reverse proxy open to the world), change all three to your own values
first:

- **Database password** — this appears in **two** places that must match:
  `POSTGRES_PASSWORD` on the `db` service, and *inside* `DATABASE_URL` on the
  `api` service (`postgres://macrouser:<password>@macro-tracker-db:5432/macrotracker`).
  Change it in both.
- **`API_SECRET`** — set your own value, then enter that same value as the
  **API key** in step 4 below (leave it at the default and you can skip that
  field entirely).
- **`APP_SEED`** — any long random string of your own.

## 3. Start it

```bash
docker compose up -d
```

This starts three containers: a PostgreSQL database, the API server, and
the web frontend, and exposes everything on **port 8069**.

Find your server's address:

```bash
hostname -I   # local network IP, e.g. 192.168.1.50
```

Your server is now reachable at `http://<that-ip>:8069` on your local
network. To reach it from outside your home network too (e.g. from
mobile data), put it behind something like Tailscale or a reverse proxy
with HTTPS — that part is up to your own setup and outside the scope of
this guide.

## 4. Point the app at your server

On your phone, open Macro ForgeFit → **Settings → Server connection**:

- **Server URL** — your server's address from step 3, e.g.
  `http://192.168.1.50:8069` (or your HTTPS/Tailscale address if you set
  one up).
- **API key** — leave blank unless you changed `API_SECRET` in step 2, in
  which case enter that value here.

Tap **Save & test**. If it connects, this is what switches the app from
phone-only mode over to your server — from then on, all your logging
reads and writes to your server instead of the device.

If you already have entries logged on your phone, you'll be offered the
choice to upload them to your new server before switching. **Uploading
replaces anything already on that server**, so only do this against a
freshly-started server with nothing on it yet.

## Updating later

```bash
docker compose pull
docker compose up -d
```

## Umbrel users

If you're already running [Umbrel](https://umbrel.com/) and would rather
install this as an app than run `docker compose` by hand, you can add this
repository as a **custom community app store**: Umbrel → App Store →
(top-right ⋯) → *Community App Stores* → add
`https://github.com/fazle1337-del/macro-tracker-public-info`. It shows up as
the **"Macro ForgeFit" App Store**, and Macro ForgeFit installs from there
like any other app (Umbrel manages its data and updates for you). The plain
`docker compose` steps above are the alternative for non-Umbrel hosts.
