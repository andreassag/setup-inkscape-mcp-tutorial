# Running Inkscape MCP via Docker Compose: Quick Setup Guide

A lightweight, centralized setup to run **Inkscape MCP** ([`Shriinivas/inkmcp`](https://github.com/Shriinivas/inkmcp)) as a containerized Model Context Protocol (MCP) server for AI coding assistants without cluttering host Python dependencies.

---

## Directory Layout

Store the Docker setup in a workspace-specific location (e.g., `.mcp/inkmcp` in your project root) or a centralized location on your system:

### macOS / Linux

- **Centralized location**: `~/.mcp/inkmcp/`
- **Workspace-specific location**: `path/to/project/.mcp/inkmcp/`

```text
~/.mcp/inkmcp/
├── Dockerfile          # Required only when building locally
├── entrypoint.sh       # Required only when building locally
├── docker-compose.yml  # Service definitions
└── .env                # Local environment configuration (optional)
```

### Windows 11

- **Centralized location**: `%USERPROFILE%\.mcp\inkmcp\` (e.g., `C:\Users\<username>\.mcp\inkmcp\`)
- **Workspace-specific location**: `C:\path\to\project\.mcp\inkmcp\`

```text
C:\Users\<username>\.mcp\inkmcp\
├── Dockerfile          # Required only when building locally
├── entrypoint.sh       # Required only when building locally
├── docker-compose.yml  # Service definitions
└── .env                # Local environment configuration (optional)
```

> **Note**: If you are using pre-built images from Docker Hub or GitHub Container Registry, only `docker-compose.yml` (and `.env`) is required.

---

## 1. Installation & Image Setup

Choose one of the two approaches depending on whether you want to build the container locally from the `Dockerfile` or pull a pre-built image from a registry.

### Option A: Building from Dockerfile (Local Build)

Use this method if you want to build or modify the container image locally.

1. Create or place `Dockerfile`:

```dockerfile
# syntax=docker/dockerfile:1

ARG UBUNTU_VERSION=24.04

# ==============================================================================
# Stage 1: Fetch Shriinivas/inkmcp extension files
# ==============================================================================
FROM ubuntu:${UBUNTU_VERSION} AS fetcher

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    unzip \
    git \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src

RUN set -e; \
    mkdir -p /src/extensions; \
    if curl -fsSL https://github.com/Shriinivas/inkmcp/releases/download/v1.0.0/inkmcp-extension.zip -o inkmcp-extension.zip; then \
        unzip -q inkmcp-extension.zip -d /src/extensions && rm inkmcp-extension.zip; \
    else \
        git clone --depth 1 https://github.com/Shriinivas/inkmcp.git /tmp/inkmcp-repo; \
        cp /tmp/inkmcp-repo/inkscape_mcp.inx /tmp/inkmcp-repo/inkscape_mcp.py /src/extensions/; \
        cp -r /tmp/inkmcp-repo/inkmcp /src/extensions/; \
        rm -rf /tmp/inkmcp-repo; \
    fi

# ==============================================================================
# Stage 2: Ubuntu Runtime (glibc-based to avoid musl libc crashes)
# ==============================================================================
FROM ubuntu:${UBUNTU_VERSION}

ARG UID=1000
ARG GID=1000

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    inkscape \
    dbus \
    dbus-x11 \
    libglib2.0-bin \
    fonts-dejavu-core \
    fontconfig \
    python3 \
    python3-pip \
    python3-venv \
    python3-gi \
    python3-gi-cairo \
    python3-cairo \
    python3-dbus \
    python3-lxml \
    python3-pil \
    python3-cssselect \
    python3-numpy \
    python3-scour \
    python3-packaging \
    gir1.2-gtk-3.0 \
    python3-dev \
    libcairo2-dev \
    libgirepository-2.0-dev \
    pkg-config \
    build-essential \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN if [ "${UID}" != "1000" ] || [ "${GID}" != "1000" ]; then \
      groupmod -g ${GID} ubuntu 2>/dev/null || true; \
      usermod -u ${UID} -g ${GID} ubuntu 2>/dev/null || true; \
    fi && \
    mkdir -p /home/ubuntu/.config/inkscape /workspace && \
    chown -R ubuntu:ubuntu /home/ubuntu /workspace

USER ubuntu
WORKDIR /home/ubuntu

ENV DBUS_SESSION_BUS_ADDRESS="unix:path=/tmp/dbus-session.sock" \
    DISPLAY=":0" \
    GDK_BACKEND="x11" \
    PYTHONUNBUFFERED="1" \
    PYTHONPATH="/usr/share/inkscape/extensions:/home/ubuntu/.config/inkscape/extensions"

COPY --from=fetcher --chown=ubuntu:ubuntu /src/extensions /home/ubuntu/.config/inkscape/extensions

WORKDIR /home/ubuntu/.config/inkscape/extensions/inkmcp
RUN chmod +x *.py *.sh 2>/dev/null || true && \
    python3 -m venv --system-site-packages venv && \
    ./venv/bin/pip install --no-cache-dir --upgrade pip && \
    ./venv/bin/pip install --no-cache-dir \
      "mcp>=1.6.0,<2.0.0" \
      "fastmcp>=2.0.0,<3.0.0" \
      inkex \
      cssselect

COPY --chown=ubuntu:ubuntu entrypoint.sh /home/ubuntu/entrypoint.sh
RUN chmod +x /home/ubuntu/entrypoint.sh

WORKDIR /workspace

ENTRYPOINT ["/home/ubuntu/entrypoint.sh"]
CMD ["inkscape"]
```

2. Create or place `entrypoint.sh` (ensure it is executable with `chmod +x entrypoint.sh`):

```bash
#!/usr/bin/env bash
set -e

USER_HOME="${HOME:-/home/ubuntu}"
EXT_DIR="${USER_HOME}/.config/inkscape/extensions/inkmcp"
VENV_PYTHON="${EXT_DIR}/venv/bin/python"

case "$1" in
  mcp)
    exec "${VENV_PYTHON}" "${EXT_DIR}/main.py"
    ;;
  test|cli)
    shift
    exec "${VENV_PYTHON}" "${EXT_DIR}/inkmcpcli.py" "$@"
    ;;
  inkscape|"")
    rm -f /tmp/dbus-session.sock
    mkdir -p /tmp/runtime-ubuntu "${USER_HOME}/.config/inkscape"
    chmod 700 /tmp/runtime-ubuntu

    if [ ! -f "${USER_HOME}/.config/inkscape/preferences.xml" ]; then
      cat << 'EOF' > "${USER_HOME}/.config/inkscape/preferences.xml"
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<inkscape version="1.0">
  <group id="window">
    <group id="welcome" show="0" />
  </group>
</inkscape>
EOF
    fi

    dbus-daemon --session --address="unix:path=/tmp/dbus-session.sock" --fork

    echo "[inkmcp] Session D-Bus daemon started at $DBUS_SESSION_BUS_ADDRESS"
    echo "[inkmcp] Starting Inkscape GUI on DISPLAY=${DISPLAY:-:0}..."

    if [ "$1" = "inkscape" ]; then
      shift
    fi
    exec inkscape "$@"
    ;;
  *)
    exec "$@"
    ;;
esac
```

3. Build the image locally:

- **Using Docker CLI**:
  - **macOS / Linux**:
    ```bash
    docker build -t inkmcp:latest ~/.mcp/inkmcp
    ```
  - **Windows 11**:
    ```powershell
    docker build -t inkmcp:latest "$HOME\.mcp\inkmcp"
    ```

- **Using Docker Compose**:
  ```bash
  docker compose -f ~/.mcp/inkmcp/docker-compose.yml build
  ```

*(Note: When using a locally built image, ensure `image: andreassag/inkmcp:latest` or `inkmcp:latest` in `docker-compose.yml` matches your local tag).*

### Option B: Pulling Pre-built Image from Registry

Use this method if you want to use pre-built images without maintaining a local `Dockerfile`.

Pre-built images are published to Docker Hub and GitHub Container Registry (GHCR):
- **Docker Hub**: `andreassag/inkmcp:latest` (or tagged versions like `andreassag/inkmcp:ubuntu24.04`)
- **GitHub Container Registry (GHCR)**: `ghcr.io/andreassag/inkmcp:latest`

Pull the image:

```bash
# Pull from Docker Hub
docker pull andreassag/inkmcp:latest

# Pull from GitHub Container Registry
docker pull ghcr.io/andreassag/inkmcp:latest
```

When pulling from a registry, you only need `docker-compose.yml` and your `.env` configuration.

---

## 2. Docker Compose Configuration

Create `docker-compose.yml`:

```yaml
x-inkmcp-common: &inkmcp-common
  build:
    context: .
    args:
      UID: ${UID:-1000}
      GID: ${GID:-1000}
  image: andreassag/inkmcp:latest
  environment:
    - DISPLAY=${DISPLAY:-:0}
    - WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-wayland-0}
    - XDG_RUNTIME_DIR=/tmp/runtime-ubuntu
    - DBUS_SESSION_BUS_ADDRESS=unix:path=/tmp/dbus-session.sock
    - GDK_BACKEND=x11
    - PYTHONUNBUFFERED=1
    - PYTHONPATH=/usr/share/inkscape/extensions:/home/ubuntu/.config/inkscape/extensions
  volumes:
    - /tmp/.X11-unix:/tmp/.X11-unix:rw
    - inkmcp-tmp:/tmp
    - ./workspace:/workspace:rw

services:
  inkscape:
    <<: *inkmcp-common
    container_name: inkmcp-gui
    ipc: host
    command: ["inkscape"]
    healthcheck:
      test: ["CMD-SHELL", "test -S /tmp/dbus-session.sock"]
      interval: 2s
      timeout: 2s
      retries: 10
      start_period: 2s

  mcp:
    <<: *inkmcp-common
    profiles: ["mcp"]
    ipc: "service:inkscape"
    pid: "service:inkscape"
    depends_on:
      inkscape:
        condition: service_healthy
    stdin_open: true
    tty: false
    command: ["mcp"]

  test-dbus:
    <<: *inkmcp-common
    profiles: ["test", "cli"]
    ipc: "service:inkscape"
    pid: "service:inkscape"
    depends_on:
      inkscape:
        condition: service_healthy
    command: ["test", "circle", "cx=120 cy=120 r=50 fill=#10b981 stroke=#064e3b stroke-width=3"]

volumes:
  inkmcp-tmp:
```

### Environment Configuration (`.env`)

Docker Compose automatically loads variables from a `.env` file located in the same directory as `docker-compose.yml`.

Create a `.env` file in the same directory as `docker-compose.yml` (e.g., `~/.mcp/inkmcp/.env` or `C:\Users\<username>\.mcp\inkmcp\.env`):

```bash
DISPLAY=:0
WAYLAND_DISPLAY=wayland-0
UID=1000
GID=1000
```

---

## 3. Starting Inkscape & Testing Connection

Start the Inkscape GUI container in the background:

### macOS / Linux / WSL2

```bash
docker compose -f ~/.mcp/inkmcp/docker-compose.yml up -d
```

### Windows 11

```powershell
docker compose -f "$HOME\.mcp\inkmcp\docker-compose.yml" up -d
```

Inkscape will open on your desktop (via WSLg on Windows 10/11 or native X11/Wayland on Linux) with an active blank canvas ready to receive commands.

> **Tip**: Closing the Inkscape window exits the container and leaves it stopped. To reopen Inkscape, run `docker compose up -d` again.

### Test D-Bus Communication

Verify that commands can be dispatched to the active Inkscape canvas over D-Bus:

```bash
docker compose -f ~/.mcp/inkmcp/docker-compose.yml run --rm test-dbus
```

A green circle (`cx=120 cy=120 r=50`) will immediately appear on the active Inkscape canvas.

You can also pass custom shape commands directly:

```bash
docker compose -f ~/.mcp/inkmcp/docker-compose.yml run --rm test-dbus rect "x=50 y=50 width=180 height=100 fill=#3b82f6"
```

---

## 4. MCP Client Configuration

### Base Configuration (`mcp.json`)

Most MCP-compatible clients use an `mcpServers` object in their configuration file. Below is the base definition:

```json
{
    "mcpServers": {
        "inkscape-mcp": {
            "command": "docker",
            "args": [
                "compose",
                "-f",
                "/home/<user>/.mcp/inkmcp/docker-compose.yml",
                "run",
                "--rm",
                "-i",
                "-T",
                "mcp"
            ]
        }
    }
}
```

> **Windows 11 / WSL2 Host Note**: When running the AI client directly on Windows, route the command through `wsl.exe`:
> ```json
> {
>     "mcpServers": {
>         "inkscape-mcp": {
>             "command": "wsl.exe",
>             "args": [
>                 "-d", "Ubuntu", "--",
>                 "docker", "compose",
>                 "-f", "/home/<user>/.mcp/inkmcp/docker-compose.yml",
>                 "run", "--rm", "-i", "-T", "mcp"
>             ]
>         }
>     }
> }
> ```

---

### Client Configuration Locations

Add the base `inkscape-mcp` entry to the corresponding client configuration file or use the CLI command:

| Client | Scope / Platform | Configuration Path / CLI Command |
| :--- | :--- | :--- |
| **Google Antigravity** | Global | `~/.gemini/config/mcp_config.json` |
| | Workspace | `.agents/mcp_config.json` (repository root) |
| **Claude Desktop** | macOS / Linux | `~/.config/Claude/claude_desktop_config.json` |
| | Windows 11 | `%APPDATA%\Claude\claude_desktop_config.json` |
| **Claude Code** | CLI | `claude mcp add inkscape-mcp -- docker compose -f /home/<user>/.mcp/inkmcp/docker-compose.yml run --rm -i -T mcp` |
| **OpenAI Codex** | Global | `~/.codex/config.json` |
| | Workspace | `.codex/config.json` (repository root) |
| | CLI | `codex mcp add inkscape-mcp -- docker compose -f /home/<user>/.mcp/inkmcp/docker-compose.yml run --rm -i -T mcp` |

---

## 5. Docker Compose Services Reference

| Service | Profile | Purpose | Command Example |
| :--- | :--- | :--- | :--- |
| `inkscape` | *(default)* | Runs D-Bus session broker and persistent Inkscape GUI | `docker compose up -d` |
| `mcp` | `mcp` | Runs the FastMCP `stdio` server connected to Inkscape | `docker compose run --rm -i -T mcp` |
| `test-dbus` | `test`, `cli` | Runs `inkmcpcli.py` to issue direct commands over D-Bus | `docker compose run --rm test-dbus` |

---

## 6. Troubleshooting

| Symptom | Root Cause | Solution |
| :--- | :--- | :--- |
| Inkscape GUI window does not appear | WSLg X11 socket not forwarded or permissions mismatch. | Check that `/tmp/.X11-unix` exists in WSL2. Verify `DISPLAY=:0` in `.env`. |
| Black or blank canvas on older WSLg builds | Wayland buffer composition quirk. | The container sets `GDK_BACKEND=x11` by default to enforce reliable XWayland rendering. |
| `JSON-RPC parsing error` | Docker allocated a pseudo-TTY (`tty: true` or missing `-T` flag). | Ensure `-T` is included in `docker compose run` args to disable TTY formatting on `stdio`. |

---

## License

This project is dedicated to the public domain under the [Unlicense](LICENSE).
