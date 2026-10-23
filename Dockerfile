# syntax=docker/dockerfile:1

ARG UBUNTU_VERSION=24.04
ARG MCP_VERSION=1.3.1

FROM ubuntu:${UBUNTU_VERSION}

ARG UID=1000
ARG GID=1000
ARG MCP_VERSION=1.3.1

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH"

# Install system dependencies, PPA for Inkscape 1.4+, dev headers, and runtime utilities
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    software-properties-common \
    gnupg \
    && add-apt-repository -y ppa:inkscape.dev/stable \
    && apt-get update && apt-get install -y --no-install-recommends \
    inkscape \
    python3 \
    python3-pip \
    python3-venv \
    python3-gi \
    python3-cairo \
    python3-lxml \
    python3-numpy \
    python3-scour \
    python3-cssselect \
    libcairo2-dev \
    libgirepository-2.0-dev \
    libgirepository1.0-dev \
    pkg-config \
    python3-dev \
    build-essential \
    potrace \
    ghostscript \
    poppler-utils \
    imagemagick \
    git \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Create virtual environment with system site-packages and install inkscape-mcp from PyPI
RUN python3 -m venv --system-site-packages /opt/venv && \
    /opt/venv/bin/pip install --no-cache-dir --upgrade pip && \
    /opt/venv/bin/pip install --no-cache-dir "inkscape-mcp==${MCP_VERSION}"

# Setup workspace directory and ensure proper user mapping
RUN if [ "${UID}" != "1000" ] || [ "${GID}" != "1000" ]; then \
      groupmod -g ${GID} ubuntu 2>/dev/null || true; \
      usermod -u ${UID} -g ${GID} ubuntu 2>/dev/null || true; \
    fi && \
    mkdir -p /workspace /home/ubuntu && \
    chown -R ubuntu:ubuntu /workspace /home/ubuntu

USER ubuntu
WORKDIR /workspace

ENTRYPOINT ["inkscape-mcp"]
CMD ["--mode", "stdio"]
