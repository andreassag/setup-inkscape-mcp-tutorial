# Inkscape MCP Guide: Native & Headless Docker Setup

A modern, comprehensive guide to running **Inkscape MCP** ([`aravindev/inkscape_mcp`](https://github.com/aravindev/inkscape_mcp)) as a Model Context Protocol (MCP) server for AI coding assistants (such as Google Antigravity, Claude Desktop, Claude Code, Cursor, Windsurf, and VS Code).

---

## Overview

[Inkscape MCP](https://github.com/aravindev/inkscape_mcp) connects AI coding assistants directly to Inkscape, providing **8 high-level portmanteau tools** and **over 49 vector operations**. It allows agents to manipulate vector graphics dynamically, run geometry operations, generate complex assets, inspect documents, and drive a live interactive Inkscape GUI canvas in real time.

This guide covers:
1. **Native Setup (Recommended)**: Run directly on your host OS (**Linux**, **macOS**, and **Windows**) via Astral's `uvx` or standard Python virtual environments with live GUI canvas interaction over D-Bus and headless CLI operations.
2. **Headless Docker Setup (Alternative / CI)**: Run an isolated, headless container (`ubuntu:24.04`, Inkscape 1.4+, `inkscape-mcp`) communicating over stdio for CI/CD runners, batch graphic conversion, or environments without a local Inkscape installation.

---

## Part 1: Native Setup (Recommended)

Running natively provides the best experience: instant execution, access to your system fonts, live D-Bus canvas control, and zero display socket forwarding.

### 1. Prerequisites

#### A. Install Inkscape 1.4+

- **Ubuntu / Debian**:
  ```bash
  sudo add-apt-repository ppa:inkscape.dev/stable
  sudo apt update
  sudo apt install inkscape libcairo2-dev libgirepository-2.0-dev libgirepository1.0-dev \
    pkg-config python3-dev xclip wl-clipboard
  ```
  *(Note: `wl-clipboard` and `xclip` handle clipboard staging for live SVG insertion into the canvas; the server auto-detects Wayland vs X11).*

- **Fedora**:
  ```bash
  sudo dnf install inkscape cairo-devel gobject-introspection-devel pkgconf-pkg-config \
    python3-devel wl-clipboard xclip
  ```

- **Arch Linux**:
  ```bash
  sudo pacman -S inkscape cairo gobject-introspection pkgconf python wl-clipboard xclip
  ```

- **macOS**:
  ```bash
  brew install --cask inkscape
  ```
  *Ensure the Inkscape CLI is reachable on your PATH, or set `INKSCAPE_BIN="/Applications/Inkscape.app/Contents/MacOS/inkscape"`.*

- **Windows 11 / 10**:
  Install Inkscape via winget or official installer:
  ```powershell
  winget install Inkscape.Inkscape
  ```
  *For Live GUI Mode on Windows*: A D-Bus daemon is required for live canvas bridge communication. The easiest installation method is via [MSYS2](https://www.msys2.org/):
  ```sh
  pacman -S mingw-w64-x86_64-dbus
  ```
  The MCP server will auto-discover `dbus-daemon.exe`.

#### B. Install Astral `uv` (or Python 3.12+)

Astral's [`uv`](https://docs.astral.sh/uv/) provides the fastest, most reliable execution via `uvx`:

- **Linux / macOS**:
  ```bash
  curl -LsSf https://astral.sh/uv/install.sh | sh
  ```

- **Windows**:
  ```powershell
  winget install astral-sh.uv
  ```

---

### 2. Quickstart Test

Run `inkscape-mcp` on demand using `uvx` (no permanent venv installation required):

```bash
uvx inkscape-mcp --help
```

You should see the FastMCP options and help output.

Alternatively, install into a dedicated virtual environment:
```bash
python3 -m venv ~/.venvs/inkscape_mcp
~/.venvs/inkscape_mcp/bin/pip install inkscape-mcp
~/.venvs/inkscape_mcp/bin/inkscape-mcp --help
```

---

### 3. MCP Client Configuration

Add `inkscape-mcp` to your preferred AI coding assistant or client:

#### Google Antigravity

- **Global Config**: `~/.gemini/config/mcp_config.json`
- **Project-Level Config**: `.agents/mcp_config.json`

```json
{
  "mcpServers": {
    "inkscape-mcp": {
      "command": "uvx",
      "args": ["inkscape-mcp"]
    }
  }
}
```

#### Claude Desktop

- **macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Windows**: `%APPDATA%\Claude\claude_desktop_config.json`
- **Linux**: `~/.config/Claude/claude_desktop_config.json`

```json
{
  "mcpServers": {
    "inkscape-mcp": {
      "command": "uvx",
      "args": ["inkscape-mcp"]
    }
  }
}
```

*(If using a dedicated Python venv rather than `uvx`, replace `"command": "uvx"` and `"args": ["inkscape-mcp"]` with `"command": "/path/to/venv/bin/inkscape-mcp"` and `"args": []`)*.

#### Claude Code CLI

Register in one command:
```bash
claude mcp add inkscape_mcp -s user -- uvx inkscape_mcp
claude mcp list | grep inkscape_mcp   # Verifies: ✓ Connected
```

#### Cursor / Windsurf / VS Code

In your assistant's MCP configuration settings:
```json
{
  "mcpServers": {
    "inkscape-mcp": {
      "command": "uvx",
      "args": ["inkscape-mcp"]
    }
  }
}
```

---

### 4. Modes of Operation

1. **Live GUI Mode (`inkscape_live`)**:
   - Keep Inkscape open on your desktop with your artwork canvas.
   - The AI agent communicates with the live window over D-Bus.
   - The agent can inspect your current selection (`get_selection`), paste geometric shapes in place (`insert_svg`), mutate XML attributes (`edit_xml`), execute actions (`apply_action`), and rasterize the canvas into an image to visually inspect its work.
   - Every operation creates a standard Inkscape undo entry (`Ctrl+Z`), preserving full human control.

2. **Headless CLI Mode (`inkscape_file`, `inkscape_vector`, `inkscape_analysis`)**:
   - Executes headlessly using Inkscape's command-line verbs and Inkex scripts.
   - Ideal for generating SVG files from scratch, running boolean operations (`apply_boolean`), converting formats (`SVG -> PDF/PNG/DXF`), simplifying paths, and optimizing files (`scour_svg`).
   - Does not require a graphical window to be open.

---

## Part 2: Headless Docker Setup (Alternative / CI / Isolated)

When should you use Docker?
- Running on headless Linux servers or CI/CD pipelines without a desktop environment.
- Environments where installing Inkscape 1.4+ or Python 3.12+ locally is restricted or inconvenient.
- Isolated batch operations where vector assets are mounted into a container.

> **Note**: The Docker container is strictly **headless**. It communicates using MCP JSON-RPC over `stdio` and does not forward X11 or Wayland displays.

### 1. Using Pre-Built Images

Pre-built multi-arch images (`linux/amd64` and `linux/arm64`) are published to both GitHub Container Registry and Docker Hub, tagged with the MCP release version alongside the Ubuntu base image version:
- **Docker Hub**:
  - `andreassag/inkscape-mcp:v1.3.1-ubuntu24.04` (or `:v1.3.1`, `:latest`)
- **GitHub Container Registry (GHCR)**:
  - `ghcr.io/andreassag/inkscape-mcp:v1.3.1-ubuntu24.04` (or `:v1.3.1`, `:latest`)

Run ad-hoc:
```bash
docker run -i --rm -v $(pwd):/workspace ghcr.io/andreassag/inkscape-mcp:latest --help
```

### 2. Using Docker Compose

The repository includes a simplified `docker-compose.yml`:

```yaml
services:
  mcp:
    build:
      context: .
      args:
        UID: ${UID:-1000}
        GID: ${GID:-1000}
    image: andreassag/inkscape-mcp:latest
    stdin_open: true
    tty: false
    volumes:
      - ${WORKSPACE_DIR:-.}:/workspace:rw
    command: ["--mode", "stdio"]
```

#### Environment Variables (`.env`)

Copy `.env.example` to `.env`:
```bash
cp .env.example .env
```

```bash
# User and Group ID matching host permissions
UID=1000
GID=1000

# Directory mounted to /workspace inside container
WORKSPACE_DIR=.
```

### 3. MCP Client Configuration for Docker

To run the headless Docker container from your MCP client, configure stdio execution:

```json
{
  "mcpServers": {
    "inkscape-mcp": {
      "command": "docker",
      "args": [
        "compose",
        "-f",
        "/path/to/setup-inkscape-mcp-tutorial/docker-compose.yml",
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

*Crucial flag*: `-T` disables pseudo-TTY allocation in Docker, preventing escape characters and carriage returns from corrupting the JSON-RPC communication stream.

---

## Part 3: Tool Reference & Examples

`inkscape-mcp` organizes functionality into 8 portmanteau tools. Each tool accepts an `operation` parameter:

| Tool | Operations | Purpose |
| :--- | :--- | :--- |
| **`inkscape_file`** | `load`, `save`, `convert`, `info`, `validate`, `list_formats`, `batch_convert` | Load, export, validate, and batch-convert vector documents. |
| **`inkscape_vector`** | `apply_boolean`, `align`, `distribute`, `trace_image`, `scour_svg`, `optimize_svg`, `measure_object`, `generate_barcode_qr`, `lpe_add_corners`, `tile_clone`, +39 more | Comprehensive geometric and vector operations. |
| **`inkscape_analysis`** | `quality`, `statistics`, `validate`, `objects`, `dimensions`, `structure` | Inspect SVG object hierarchy, calculate dimensions, compute quality score. |
| **`inkscape_system`** | `status`, `help`, `diagnostics`, `version`, `config`, `list_extensions`, `execute_extension` | Query server health, verify binary paths, inspect configuration provenance. |
| **`inkscape_extension`** | `list`, `describe`, `run`, `run_live` | Discover and invoke bundled Inkscape/Inkex Python extensions. |
| **`inkscape_gradient`** | `add_stop`, `remove_stop`, `set_stop_color`, `convert_to_linear`, `convert_to_radial`, `list_stops` | Manipulate linear and radial color stops and transitions. |
| **`inkscape_metadata`** | `get`, `set_title`, `set_creator`, `set_description`, `set_rights`, `set_keywords` | Read and write Dublin-Core RDF metadata embedded in the SVG. |
| **`inkscape_live`** | `ping`, `get_selection`, `set_selection`, `apply_action`, `insert_svg`, `edit_xml`, `rasterize`, `inspect_element` | Control live open Inkscape window over D-Bus with visual feedback. |

---

### Practical Prompting Recipes

#### 1. Procedural Vector Design (Constructing Without Hardcoded SVG)
> *"Design a modern hexagonal tech badge in this document. Create a regular hexagon, center an icon path inside it, align them horizontally and vertically, and subtract an inner shape using boolean difference."*

The agent uses:
- `inkscape_vector` (`operation="construct_svg"`) or primitive placement.
- `inkscape_vector` (`operation="align"`, `operation_type="hcenter vcenter"`).
- `inkscape_vector` (`operation="apply_boolean"`, `operation_type="difference"`).

#### 2. Visual Iteration with Live Canvas Feedback
> *"Look at my open Inkscape canvas, tell me what looks unbalanced, recolor the accent palette to warm amber, and show me the resulting render."*

The agent uses:
- `inkscape_live` (`operation="get_selection"` / `inspect_element`).
- `inkscape_live` (`operation="apply_action"`, `action="select-by-color"` or XML edit).
- `inkscape_live` (`operation="rasterize"`) to render a temporary PNG and visually verify its output.

#### 3. Asset Minification & Scour
> *"Sanitize and minify `icon.svg` for web production. Strip unnecessary namespaces, round decimal points, and preserve element IDs."*

The agent uses:
- `inkscape_vector` (`operation="scour_svg"`, `input_path="icon.svg"`).

#### 4. Batch Exporting for Print & Web
> *"Convert all SVGs in `./assets` into 300 DPI print-ready PDFs and 2x resolution PNGs."*

The agent uses:
- `inkscape_file` (`operation="batch_convert"`, `format="pdf"`).
- `inkscape_file` (`operation="batch_convert"`, `format="png"`).

---

## Part 4: Troubleshooting & Diagnostics

### Run Server Diagnostics

If an operation fails or you suspect Inkscape is not being detected properly, instruct your agent to run diagnostics or inspect it via CLI:

```bash
uvx inkscape-mcp --mode stdio
```

Inside the client:
```json
{
  "name": "inkscape_system",
  "arguments": {
    "operation": "diagnostics"
  }
}
```

The output returns:
- Detected Inkscape binary path and version.
- Provenance of settings (`cli_flag`, `env_var`, `config_file`, `auto_detected`, or `default`).
- D-Bus connection status.
- Extension directory state.

### Explicit Binary Path Override

If Inkscape is installed in a custom location, set the `INKSCAPE_BIN` environment variable:

```bash
export INKSCAPE_BIN="/custom/path/to/inkscape"
```

In client config:
```json
{
  "mcpServers": {
    "inkscape-mcp": {
      "command": "uvx",
      "args": ["inkscape-mcp"],
      "env": {
        "INKSCAPE_BIN": "/custom/path/to/inkscape"
      }
    }
  }
}
```

### Windows MSYS2 D-Bus Configuration

If Live Mode cannot establish a connection on Windows:
1. Ensure MSYS2's `dbus-daemon.exe` is installed (`pacman -S mingw-w64-x86_64-dbus`).
2. If installed in a non-standard path, set:
   ```powershell
   [System.Environment]::SetEnvironmentVariable("INKSCAPE_MCP_DBUS_DAEMON", "C:\msys64\mingw64\bin\dbus-daemon.exe", "User")
   ```
3. Note: On Windows, Live Mode automatically launches and manages its own Inkscape instance when calling `open_file`.

---

## Contributing

Contributions, issues, and feature requests are welcome!

### Testing Workflows Locally with `gh act`

This repository uses continuous integration workflows to validate configuration syntax, test multi-OS headless installation (`ubuntu-latest`, `macos-latest`, `windows-latest`), and build the container image.

To preserve GitHub Actions minutes and verify changes before pushing, you can execute the pipeline locally using [`gh act`](https://github.com/nektos/gh-act) (the GitHub CLI extension) or standalone [`act`](https://github.com/nektos/act):

```bash
# Validate configurations, bake targets, and workflow schemas (fast, no Docker daemon required):
gh act -j validate

# Run native multi-OS headless smoke test matrix (Ubuntu, macOS, Windows):
gh act -j native-test

# Build and verify the headless Docker container:
gh act -j docker-test

# Run entire CI workflow:
gh act
```

---

## License & Credits

- This tutorial repository and configuration files are dedicated to the public domain under the [Unlicense](LICENSE).
- **`inkscape_mcp`** is created by [Aravind EV](https://github.com/aravindev) and licensed under the [MIT License](https://github.com/aravindev/inkscape_mcp/blob/main/LICENSE).
- Upstream project and issue tracker: [https://github.com/aravindev/inkscape_mcp](https://github.com/aravindev/inkscape_mcp).
- PyPI package: [`inkscape-mcp`](https://pypi.org/project/inkscape-mcp/).
- Maintained by [Andreas Sagen](https://github.com/andreassag).
