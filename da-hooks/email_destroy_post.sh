#!/bin/sh
# Installed at: /usr/local/directadmin/scripts/custom/email_destroy_post.sh
# Called by DirectAdmin AFTER an email account is deleted.
# DA provides: $username (DA account)  $user (mailbox local part)  $domain
#
# OPTIONAL. Since auth is handled entirely by Dovecot, nothing needs to
# be provisioned or de-provisioned for login to work -- deleting the
# mailbox in Dovecot is enough to lock the CalDAV/CardDAV account out.
# This hook only removes the leftover calendar/contact files on disk so
# they don't sit around forever after a mailbox is deleted. Comment out
# the rm -rf line (or don't install this hook at all) if you'd rather
# keep the data in case the mailbox gets recreated.

RADICALE_COLLECTIONS_ROOT=/var/lib/radicale/collections/collection-root
LOG=/var/log/directadmin/radicale_dav.log

if [ -z "$user" ] || [ -z "$domain" ]; then
    exit 0
fi

mailbox="${user}@${domain}"
target="$RADICALE_COLLECTIONS_ROOT/$mailbox"

# Basic safety check before any rm -rf: must be a direct child of the
# collections root, and must actually look like our expected path.
case "$target" in
    "$RADICALE_COLLECTIONS_ROOT"/*@*)
        if [ -d "$target" ]; then
            rm -rf -- "$target"
            echo "$(date -Is) email_destroy_post: removed radicale data for $mailbox" >> "$LOG"
        fi
        ;;
    *)
        echo "$(date -Is) email_destroy_post: refusing to remove suspicious path for $mailbox" >> "$LOG"
        ;;
esac

exit 0
