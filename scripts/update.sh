#!/bin/sh
# Run by DirectAdmin's plugin manager after it updates this plugin.
# Only re-applies permissions and the cleanup hook link; it does not touch
# Radicale itself (that is scripts/update_radicale.sh, run by hand).

exec sh "$(dirname "$0")/install.sh"
