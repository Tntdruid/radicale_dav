# Changelog

## 2026-10-19

- Rewrite the README install guide: requirements, clone-first order,
  copy-paste commands, and a new Updating section.
- Remove the stale `$BASE_URL` step from `scripts/install.sh`.
- Mark the plugin scripts and pages executable in git.

## 2026-09-26

- Refresh the DirectAdmin admin and user pages with responsive, panel-style UI.
- Show Radicale's local TCP availability on the admin page.
- Use a stable per-mailbox collection-list URL instead of assuming the default
  calendar exists, and clarify the URL behavior in Danish and English.
- Keep the user page rendering if its translation file lacks the collection
  heading key.
- Add a Radicale update check to the admin page, reading request data from
  DirectAdmin's CLI environment so the button works.
- Add `scripts/update.sh` to install/update Radicale in a service-owned
  virtualenv.

## 2026-09-09

- Restart Radicale automatically when `dovecot.service` is restarted, so the
  Dovecot authentication socket connection is recreated and clients do not
  remain stuck with HTTP 401 responses.
- Document the one-time `systemctl daemon-reload` and Radicale restart needed
  after installing the updated service unit.
- Fix persistent 401s caused by DirectAdmin's default `auth-client` socket
  being `mode 0600, group root` (unreadable by any group). Document and
  configure a dedicated `auth-client-radicale` Dovecot listener instead of
  joining Radicale to Dovecot's group, which never granted access.