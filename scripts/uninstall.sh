#!/bin/sh
DA_CUSTOM=/usr/local/directadmin/scripts/custom
PLUGIN_DIR=/usr/local/directadmin/plugins/radicale_dav
hook=email_destroy_post.sh

if [ -L "$DA_CUSTOM/$hook" ] && [ "$(readlink "$DA_CUSTOM/$hook")" = "$PLUGIN_DIR/da-hooks/$hook" ]; then
    rm -f "$DA_CUSTOM/$hook"
    echo "removed $hook"
fi
echo "Plugin hook removed. Calendar/contact data left in place."
