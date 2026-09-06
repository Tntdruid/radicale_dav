#!/bin/sh
# Run manually as root after copying the plugin into
# /usr/local/directadmin/plugins/radicale_dav/
#
#   cd /usr/local/directadmin/plugins/radicale_dav
#   ./scripts/install.sh

set -e

PLUGIN_DIR=/usr/local/directadmin/plugins/radicale_dav
DA_CUSTOM=/usr/local/directadmin/scripts/custom

echo "==> Setting permissions"
chmod 755 "$PLUGIN_DIR/user/index.html"
chmod 644 "$PLUGIN_DIR/hooks/"*.html
chmod 755 "$PLUGIN_DIR/da-hooks/"*.sh

echo "==> Installing the OPTIONAL email_destroy_post.sh cleanup hook"
mkdir -p "$DA_CUSTOM"
hook=email_destroy_post.sh
if [ -e "$DA_CUSTOM/$hook" ] && [ ! -L "$DA_CUSTOM/$hook" ]; then
    echo "    !! $DA_CUSTOM/$hook already exists and isn't managed by this"
    echo "       plugin -- merge $PLUGIN_DIR/da-hooks/$hook into it by hand."
else
    ln -sf "$PLUGIN_DIR/da-hooks/$hook" "$DA_CUSTOM/$hook"
    echo "    linked $hook"
fi

echo
echo "==> Remaining manual steps (see README.md):"
echo "    1. Install Radicale + point it at Dovecot's auth socket."
echo "    2. Add 'radicale' user to the group that owns that socket."
echo "    3. Edit user/index.html: set \$BASE_URL to your real hostname."
echo "    4. Add the Apache reverse-proxy vhost and reload Apache."
echo "    5. Start/enable the radicale service."
echo "Done."
