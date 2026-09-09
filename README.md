# radicale_dav — DirectAdmin ⇄ Radicale integration plugin (Dovecot auth)

Every DirectAdmin **mailbox** (`user@domain.tld`) gets a CalDAV/CardDAV
account that reuses its existing mail password, via Radicale's built-in
`dovecot` auth backend, reachable at **`https://<their-domain>/caldav`** —
no dedicated subdomain, no per-domain setup. There is no separate
password to manage and no account-provisioning step: Radicale creates a
mailbox's calendar/address book automatically the first time a client
connects with valid Dovecot credentials.

## How it works

- Radicale runs locally (`127.0.0.1:5232`), config'd with
  `[auth] type = dovecot`, pointed at Dovecot's auth-client socket.
  Every login attempt is relayed straight to Dovecot for a real
  username/password check — DirectAdmin/Dovecot stays the single
  source of truth for mail credentials.
- **Every domain's own Apache vhost** proxies `/caldav` to that local
  Radicale instance. This is done by editing DirectAdmin's shared SSL
  vhost *template* (not per-domain config), so it applies to every
  existing domain and every domain created afterwards, automatically.
  `/.well-known/caldav` and `/.well-known/carddav` are also redirected
  to `/caldav/`, so clients that only need "domain.tld" find it themselves.
- The plugin's user-level GUI page is a no-JavaScript URL builder — submit
  your mailbox address and get your CalDAV/CardDAV URLs (derived from the
  domain part of the address you submit — nothing to configure). No
  passwords touch this plugin at all.
- The page also links to Radicale's built-in calendar manager. With Radicale
  3.7 or newer, users can create read-only map shares for other authenticated
  mailboxes without giving their password to this plugin; the recipient must
  accept the share before it becomes visible.
- One optional DA hook, `email_destroy_post.sh`, deletes the leftover
  calendar/contacts files when a mailbox is deleted (not required for
  security — Dovecot no longer authenticating the mailbox is what
  actually locks it out — this just tidies up disk space).

## Install

1. **Install Radicale**:
   ```
   python3 -m pip install --upgrade radicale
   useradd --system --user-group --home-dir / --shell /sbin/nologin radicale
   mkdir -p /var/lib/radicale/collections
   chown -R radicale:radicale /var/lib/radicale/collections
   ```
2. Find your real Dovecot auth-client socket path and group:
   ```
   doveconf -a | grep -A3 'service auth '
   ```
   Look for a `unix_listener .../auth-client { ... group = ... }` block.
   Update `dovecot_socket` in `config/radicale-config` if it differs
   from `/var/run/dovecot/auth-client`.
3. Let Radicale read that socket:
   ```
   usermod -aG <the-group-from-step-2> radicale
   ```
4. Copy `config/radicale-config` to `/etc/radicale/config`.
5. Copy `config/radicale.service` to
   `/etc/systemd/system/radicale.service`, then:
   ```
   systemctl daemon-reload
   systemctl enable --now radicale
   ```
  Radicale 3.7 or newer is required for the built-in sharing manager.
  After changing `/etc/radicale/config`, restart it with
  `systemctl restart radicale`.
  The service is tied to `dovecot.service`, so restarting Dovecot also
  restarts Radicale and reconnects its authentication socket. After updating
  the service unit, run `systemctl daemon-reload` and
  `systemctl restart radicale` once.
6. Test dovecot auth directly, hitting Radicale locally, before wiring
   up Apache at all:
   ```
   curl -u alice@example.com:mailpassword http://127.0.0.1:5232/alice@example.com/
   ```
   Confirm it returns something other than 401.
7. **Add `/caldav` and `/carddav` to every domain's vhost** — copy the
  appropriate files from `config/` into DirectAdmin's custom template
  directory:
  - `virtual_host2_secure.conf.CUSTOM.post` for HTTPS vhosts (recommended).
  - `virtual_host2.conf.CUSTOM.post` only when the HTTP vhost redirects to
    HTTPS before authentication. Do not expose Basic Auth over plain HTTP.

  Then run `./build rewrite_confs` from
  `/usr/local/directadmin/custombuild` and reload Apache. Requires
  `mod_proxy`, `mod_proxy_http`, and `mod_headers` — check with
  `httpd -M | grep -E 'proxy|headers'`.
8. Copy this whole directory to
   `/usr/local/directadmin/plugins/radicale_dav/`.
9. Run `./scripts/install.sh` as root — sets permissions and symlinks
  the optional cleanup hook. This also makes both DirectAdmin entry
  points (`admin/index.html` and `user/index.html`) executable.
10. Confirm the "Calendar & Contacts" tab appears for a test DA user,
    and that entering a real mailbox address there produces a URL a
    CalDAV client (or `curl -u`) can actually authenticate against:
    ```
    curl -u alice@example.com:mailpassword https://example.com/caldav/alice@example.com/
    ```

## Files

```
plugin.conf                    DA plugin manifest
hooks/user_txt.html            Menu link shown to end users
hooks/admin_txt.html           Menu link shown to admin
admin/index.html                Admin-level info/reference page
user/index.html                 GUI page: mailbox -> CalDAV/CardDAV URLs
da-hooks/email_destroy_post.sh  Optional: purge a mailbox's calendar data on deletion
scripts/install.sh              Run once after copying the plugin into place
scripts/uninstall.sh            Removes the hook symlink (keeps calendar data)
config/radicale-config                       /etc/radicale/config using dovecot auth
config/radicale.service                      Systemd unit (joins the dovecot socket group)
config/virtual_host2_secure.conf.CUSTOM.post HTTPS CalDAV/CardDAV proxy fragment
config/virtual_host2.conf.CUSTOM.post        HTTP proxy fragment; use only with HTTPS redirect
lang.php                                      Plugin translations (English and Danish)
```

## Languages

The plugin pages use English by default and Danish when DirectAdmin or the
browser reports a Danish language (`da`, `da-DK`, or `danish`). The menu hooks
show both English and Danish because DirectAdmin loads those labels as static
hook text.

## Things worth double-checking on your system

- **Socket path/permissions are the main auth failure point.** If
  Radicale can't read Dovecot's auth-client socket, every login fails
  with no useful client-side error — check `journalctl -u radicale`
  first.
- **Use HTTPS for authentication.** CalDAV/CardDAV send Basic Auth
  credentials. The secure custom template is the recommended deployment;
  if the HTTP fragment is installed, HTTP must redirect to HTTPS before a
  client can authenticate.
- **mod_proxy/mod_headers must be built into Apache** — check with
  `httpd -M | grep -E 'proxy|headers'` before assuming the vhost
  template edit alone is enough.
- **Template edits only apply after a rebuild.** `./build
  rewrite_confs` regenerates every *existing* domain's config from the
  template; new domains pick it up automatically going forward, but
  already-existing ones need that one rebuild step.
- **Only accounts real mailboxes**, not the DirectAdmin panel login —
  by design. A DA user with no mailboxes has nothing to log into here
  yet.
- **DA plugin lifecycle**: `scripts/install.sh`/`uninstall.sh` here are
  meant to be run by hand once, not auto-invoked by DA's plugin
  manager.
- If `email_destroy_post.sh` already exists on your box for something
  else, `install.sh` won't overwrite it — merge the logic in by hand.
  Same goes for `virtual_host2_secure.conf` if you've already
  customized it — merge the `/caldav` block into your existing custom
  copy rather than starting from a fresh default.
