# FitTech — Run All Services

> One-command startup for the entire FitTech platform:  
> **Django backend · Next.js frontend · FitTech mobile app · Coach mobile app**

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Scripts Reference](#scripts-reference)
- [Service Details](#service-details)
- [Flags & Options](#flags--options)
- [Logs](#logs)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

Make sure the following tools are installed and available in your `PATH`:

| Tool | Minimum Version | Purpose |
|---|---|---|
| **Docker** | 24+ | MySQL database container |
| **Python** | 3.12 | Django backend |
| **Node.js** | 22+ | Next.js frontend |
| **npm** | 10+ | Frontend package manager |
| **Flutter** | 3.0+ | Mobile apps (FitTech & Coach) |

Also ensure the backend `.env` file exists at `backend/.env`.  
Refer to [`backend/README-env.md`](backend/README-env.md) for the full environment variable reference.

---

## Quick Start

```bash
# 1. Clone the repo (if you haven't already)
git clone <repo-url>
cd bbrahim

# 2. Make scripts executable
chmod +x run_all.sh stop_all.sh

# 3. Launch everything
./run_all.sh
```

Each service opens in its own **terminal window**. Logs are also saved to the `.logs/` directory.

To stop everything:

```bash
./stop_all.sh
```

---

## Scripts Reference

### `run_all.sh`

Starts all FitTech services in the correct order:

1. **MySQL** — via Docker Compose (`backend/docker-compose.yml`)
2. **Django Backend** — activates venv, runs migrations, starts dev server
3. **Next.js Frontend** — installs deps, starts dev server
4. **FitTech Mobile App** — `flutter pub get` + `flutter run`
5. **Coach Mobile App** — `flutter pub get` + `flutter run`

```bash
./run_all.sh [--no-mobile] [--no-docker]
```

### `stop_all.sh`

Gracefully stops all running services:

- Kills processes on ports **8000** (Django) and **3000** (Next.js)
- Stops the **MySQL Docker container**
- Terminates any tracked background processes

```bash
./stop_all.sh [--no-docker]
```

---

## Service Details

| Service | URL / Access | Log File |
|---|---|---|
| Django Backend | http://127.0.0.1:8000 | `.logs/backend.log` |
| Swagger API Docs | http://127.0.0.1:8000/swagger/ | `.logs/backend.log` |
| Next.js Frontend | http://localhost:3000 | `.logs/frontend.log` |
| FitTech Mobile App | Device / Emulator | `.logs/mobile_fittech.log` |
| Coach Mobile App | Device / Emulator | `.logs/mobile_coach.log` |
| MySQL Database | `127.0.0.1:3308` | Docker logs |

### Directory Layout

```
bbrahim/
├── backend/                  # Django REST API (Python 3.12)
│   ├── venv/                 # Python virtual environment (auto-created)
│   ├── docker-compose.yml    # MySQL container
│   └── .env                  # Environment variables (required)
│
├── frontend/                 # Next.js 16 + React 19 + Tailwind v4
│
├── mobile/
│   ├── fittech/              # Flutter — user-facing gym app
│   └── fittech coach/coach/  # Flutter — trainer/coach app
│
├── run_all.sh                # ← Start all services
├── stop_all.sh               # ← Stop all services
├── RUNALL.md                 # ← This file
└── .logs/                    # Runtime log files (auto-created)
```

---

## Flags & Options

### `run_all.sh`

| Flag | Description |
|---|---|
| `--no-mobile` | Skip both Flutter mobile apps (useful if no device/emulator connected) |
| `--no-docker` | Skip starting the MySQL Docker container (if MySQL is running externally) |

**Examples:**

```bash
# Start everything except mobile apps
./run_all.sh --no-mobile

# Start backend + frontend only, no Docker
./run_all.sh --no-mobile --no-docker

# Start all including mobile
./run_all.sh
```

### `stop_all.sh`

| Flag | Description |
|---|---|
| `--no-docker` | Keep the MySQL Docker container running |

---

## Logs

All service output is saved to the `.logs/` directory at the project root:

```
.logs/
├── backend.log         # Django runserver output
├── frontend.log        # Next.js dev server output
├── mobile_fittech.log  # Flutter FitTech app output
└── mobile_coach.log    # Flutter Coach app output
```

You can tail any log in real time:

```bash
tail -f .logs/backend.log
tail -f .logs/frontend.log
```

---

## Troubleshooting

### MySQL fails to start

```bash
# Check container status
cd backend && docker compose ps

# Check Docker logs
docker compose logs mysql

# Restart the container
docker compose down && docker compose up -d
```

Ensure port `3308` is not in use by another process.

### Backend venv or migration errors

```bash
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python manage.py migrate
```

Make sure `backend/.env` exists and has the correct `DB_*` variables.  
See [`backend/README-env.md`](backend/README-env.md) for the full template.

### Flutter: no devices found

```bash
# Check connected devices
flutter devices

# Launch Android emulator
flutter emulators --launch <emulator_id>
```

Mobile apps require either:
- A **physical device** connected via USB (with USB debugging enabled), or
- An **Android emulator** / **iOS Simulator** running

### Port already in use

```bash
# Free port 8000 (backend)
fuser -k 8000/tcp

# Free port 3000 (frontend)
fuser -k 3000/tcp
```

Or run `./stop_all.sh` first to clean up all ports.

### No graphical terminal (headless server)

If `gnome-terminal` and `xterm` are both unavailable, `run_all.sh` falls back to **background processes** with output piped to `.logs/`. Use `tail -f .logs/<service>.log` to monitor each service.

---

## Environment Variables

The backend requires a `backend/.env` file. Key variables:

| Variable | Example Value | Description |
|---|---|---|
| `SECRET_KEY` | `django-insecure-...` | Django secret key |
| `DB_NAME` | `fittech_db` | MySQL database name |
| `DB_USER` | `root` | MySQL user |
| `DB_PASSWORD` | `ibrahim12345` | MySQL password |
| `DB_HOST` | `127.0.0.1` | MySQL host |
| `DB_PORT` | `3308` | MySQL port (Docker mapped) |
| `FRONTEND_URL` | `http://localhost:3000` | Allowed CORS origin |
| `GEMINI_API_KEY` | `AIza...` | Google Gemini API key |

Refer to [`backend/README-env.md`](backend/README-env.md) for the complete list.
