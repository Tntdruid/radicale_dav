# Changelog

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