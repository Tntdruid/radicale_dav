# Changelog

## 2026-09-09

- Restart Radicale automatically when `dovecot.service` is restarted, so the
  Dovecot authentication socket connection is recreated and clients do not
  remain stuck with HTTP 401 responses.
- Document the one-time `systemctl daemon-reload` and Radicale restart needed
  after installing the updated service unit.