#!/usr/bin/env bash
set -e

USER_HOME="${HOME:-/home/ubuntu}"
EXT_DIR="${USER_HOME}/.config/inkscape/extensions/inkmcp"
VENV_PYTHON="${EXT_DIR}/venv/bin/python"

# Support multiple execution modes: GUI runner (default), FastMCP stdio server, and D-Bus CLI tester
case "$1" in
  mcp)
    exec "${VENV_PYTHON}" "${EXT_DIR}/main.py"
    ;;
  test|cli)
    shift
    exec "${VENV_PYTHON}" "${EXT_DIR}/inkmcpcli.py" "$@"
    ;;
  inkscape|"")
    # Clean up stale D-Bus socket from prior container runs
    rm -f /tmp/dbus-session.sock

    # Ensure runtime and Inkscape configuration directories exist
    mkdir -p /tmp/runtime-ubuntu "${USER_HOME}/.config/inkscape"
    chmod 700 /tmp/runtime-ubuntu

    # Disable Inkscape welcome dialog if preferences.xml does not exist so canvas opens immediately
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

    # Launch isolated session D-Bus daemon at the fixed socket path
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
