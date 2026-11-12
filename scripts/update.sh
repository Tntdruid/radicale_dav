#!/bin/sh
set -eu

SERVICE_USER=radicale
VENV_ROOT=/opt/radicale-dav
VENV_DIR=$VENV_ROOT/venv
OVERRIDE_DIR=/etc/systemd/system/radicale.service.d
OVERRIDE_FILE=$OVERRIDE_DIR/90-radicale-dav-venv.conf

FORCE=0
case "${1:-}" in
    --force) FORCE=1 ;;
    "") ;;
    *) echo "Usage: $0 [--force]" >&2; exit 2 ;;
esac

fail() {
    echo "Error: $*" >&2
    exit 1
}

if [ "$(id -u)" -ne 0 ]; then
    fail "Run this script as root. Radicale itself will continue running as '$SERVICE_USER'."
fi

command -v runuser >/dev/null 2>&1 || fail "runuser is required."
command -v systemctl >/dev/null 2>&1 || fail "systemctl is required."
command -v install >/dev/null 2>&1 || fail "install is required."
command -v cmp >/dev/null 2>&1 || fail "cmp is required."
PYTHON=$(command -v python3) || fail "python3 is required."
getent passwd "$SERVICE_USER" >/dev/null || fail "The '$SERVICE_USER' user does not exist."
getent group "$SERVICE_USER" >/dev/null || fail "The '$SERVICE_USER' group does not exist."
systemctl cat radicale >/dev/null 2>&1 || fail "Install /etc/systemd/system/radicale.service first."

if [ -L "$VENV_ROOT" ] || [ -L "$VENV_DIR" ]; then
    fail "The virtualenv path must not be a symbolic link."
fi
install -d -o root -g root -m 0755 "$VENV_ROOT"
install -d -o "$SERVICE_USER" -g "$SERVICE_USER" -m 0755 "$VENV_DIR"

if [ ! -x "$VENV_DIR/bin/python" ]; then
    echo "==> Creating the Radicale virtualenv as $SERVICE_USER"
    runuser -u "$SERVICE_USER" -- "$PYTHON" -m venv "$VENV_DIR" || fail "Could not create the virtualenv. Install your distribution's Python venv package and retry."
fi

echo "==> Checking the latest official Radicale release"
if ! RELEASE_TAG=$("$PYTHON" -c '
import json
import re
import urllib.request

request = urllib.request.Request(
    "https://api.github.com/repos/Kozea/Radicale/releases/latest",
    headers={"Accept": "application/vnd.github+json", "User-Agent": "radicale-dav-updater"},
)
with urllib.request.urlopen(request, timeout=15) as response:
    tag = json.load(response).get("tag_name", "")
if not isinstance(tag, str) or not re.fullmatch(r"v?[0-9]+(?:\.[0-9]+)+(?:[A-Za-z0-9.+_-]*)?", tag):
    raise SystemExit("Invalid release tag")
print(tag)
' 2>/dev/null); then
    fail "Could not read the latest release from api.github.com."
fi

RELEASE_VERSION=${RELEASE_TAG#v}
CURRENT_VERSION=$(runuser -u "$SERVICE_USER" -- "$VENV_DIR/bin/python" -c 'from importlib.metadata import version; print(version("Radicale"))' 2>/dev/null || true)
CHANGED=0
if [ "$FORCE" -eq 0 ] && [ -n "$CURRENT_VERSION" ] && [ "$CURRENT_VERSION" = "$RELEASE_VERSION" ]; then
    echo "==> Radicale $CURRENT_VERSION is already the latest release"
else
    echo "==> Installing Radicale $RELEASE_TAG as $SERVICE_USER"
    runuser -u "$SERVICE_USER" -- "$VENV_DIR/bin/python" -m pip install --upgrade "https://github.com/Kozea/Radicale/archive/refs/tags/$RELEASE_TAG.tar.gz" || fail "Radicale installation failed."
    CHANGED=1
fi

if [ -e "$OVERRIDE_FILE" ] && ! grep -Fqx '# Managed by radicale_dav/scripts/update.sh' "$OVERRIDE_FILE"; then
    fail "$OVERRIDE_FILE already exists and is not managed by this plugin; merge the service override manually."
fi

install -d -o root -g root -m 0755 "$OVERRIDE_DIR"
TEMP_OVERRIDE=$(mktemp "$OVERRIDE_DIR/.radicale-dav-venv.XXXXXX")
trap 'rm -f "$TEMP_OVERRIDE"' 0
{
    printf '%s\n' \
        '# Managed by radicale_dav/scripts/update.sh' \
        '[Service]' \
        'ExecStart=' \
        "ExecStart=$VENV_DIR/bin/python -m radicale --config /etc/radicale/config"
} > "$TEMP_OVERRIDE"
if [ -f "$OVERRIDE_FILE" ] && cmp -s "$TEMP_OVERRIDE" "$OVERRIDE_FILE"; then
    rm -f "$TEMP_OVERRIDE"
else
    chmod 0644 "$TEMP_OVERRIDE"
    chown root:root "$TEMP_OVERRIDE"
    mv -f "$TEMP_OVERRIDE" "$OVERRIDE_FILE"
    systemctl daemon-reload
    CHANGED=1
fi

systemctl enable --quiet radicale
if [ "$CHANGED" -eq 0 ] && systemctl is-active --quiet radicale; then
    echo "Radicale $CURRENT_VERSION is up to date and running; nothing to do. Use --force to reinstall."
    exit 0
fi

echo "==> Restarting the Radicale service"
if ! systemctl restart radicale; then
    systemctl --no-pager --full status radicale || true
    fail "Radicale did not start successfully. Check journalctl -u radicale."
fi

INSTALLED_VERSION=$(runuser -u "$SERVICE_USER" -- "$VENV_DIR/bin/python" -c 'from importlib.metadata import version; print(version("Radicale"))')
echo "Radicale $INSTALLED_VERSION is running as $SERVICE_USER."