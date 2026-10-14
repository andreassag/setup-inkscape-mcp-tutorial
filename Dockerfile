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

# Download pre-packaged release zip or fall back to extracting extension files from git
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

# Install Inkscape, D-Bus, and Python GObject/Cairo/D-Bus bindings
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

# Configure the built-in ubuntu user (UID/GID 1000) to match host WSL2 permissions
RUN if [ "${UID}" != "1000" ] || [ "${GID}" != "1000" ]; then \
      groupmod -g ${GID} ubuntu 2>/dev/null || true; \
      usermod -u ${UID} -g ${GID} ubuntu 2>/dev/null || true; \
    fi && \
    mkdir -p /home/ubuntu/.config/inkscape /workspace && \
    chown -R ubuntu:ubuntu /home/ubuntu /workspace

USER ubuntu
WORKDIR /home/ubuntu

# Shared session D-Bus socket path between Inkscape GUI and `docker compose run` MCP clients
ENV DBUS_SESSION_BUS_ADDRESS="unix:path=/tmp/dbus-session.sock" \
    DISPLAY=":0" \
    GDK_BACKEND="x11" \
    PYTHONUNBUFFERED="1" \
    PYTHONPATH="/usr/share/inkscape/extensions:/home/ubuntu/.config/inkscape/extensions"

# Copy extension files directly into Inkscape user extensions directory
COPY --from=fetcher --chown=ubuntu:ubuntu /src/extensions /home/ubuntu/.config/inkscape/extensions

# Build virtual environment with system-site-packages and pin mcp v1.x SDK
WORKDIR /home/ubuntu/.config/inkscape/extensions/inkmcp
RUN chmod +x *.py *.sh 2>/dev/null || true && \
    python3 -m venv --system-site-packages venv && \
    ./venv/bin/pip install --no-cache-dir --upgrade pip && \
    ./venv/bin/pip install --no-cache-dir \
      "mcp>=1.6.0,<2.0.0" \
      "fastmcp>=2.0.0,<3.0.0" \
      inkex \
      cssselect

# Copy entrypoint script
COPY --chown=ubuntu:ubuntu entrypoint.sh /home/ubuntu/entrypoint.sh
RUN chmod +x /home/ubuntu/entrypoint.sh

WORKDIR /workspace

ENTRYPOINT ["/home/ubuntu/entrypoint.sh"]
CMD ["inkscape"]
