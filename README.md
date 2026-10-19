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

## Requirements

- DirectAdmin with Dovecot and Apache (`mod_proxy`, `mod_proxy_http` and
  `mod_headers` enabled; check with `httpd -M | grep -E 'proxy|headers'`).
- systemd, `runuser`, and `python3` with the `venv` module (on
  Debian/Ubuntu install `python3-venv`).
- Outbound HTTPS from the server to `api.github.com` and `github.com`.
- For the admin page's update check: DirectAdmin's PHP must allow
  `shell_exec` and `allow_url_fopen`. The check is optional; updates
  themselves always run over SSH.

## Install

All steps run as root.

1. **Put the plugin in place**:
   ```
   git clone https://github.com/Tntdruid/radicale_dav.git /usr/local/directadmin/plugins/radicale_dav
   cd /usr/local/directadmin/plugins/radicale_dav
   ```
   (Or copy this directory to `/usr/local/directadmin/plugins/radicale_dav/`.)
   All later paths are relative to this directory.
2. **Create the Radicale service user and storage**:
   ```
   useradd --system --user-group --home-dir / --shell /sbin/nologin radicale
   mkdir -p /var/lib/radicale/collections
   chown -R radicale:radicale /var/lib/radicale/collections
   ```
3. **Give Radicale its own Dovecot auth socket.** Check the existing
   auth-client socket:
   ```
   doveconf -a | grep -A3 'service auth '
   ls -l /var/run/dovecot/auth-client
   ```
   On DirectAdmin boxes this socket is commonly `mode 0600, user
   dovecot, group root` -- not readable by any group, so adding
   `radicale` to a group does nothing. Do not loosen that socket; it is
   normally reserved for the mail stack (Postfix/Exim SMTP AUTH).
   Instead add a second, dedicated listener. Dovecot merges `service {
   }` blocks across all included config files, so put this in its own
   new file, e.g. `/etc/dovecot/conf.d/99-radicale.conf` -- do **not**
   add it to a DirectAdmin-managed file such as
   `/etc/dovecot/service.conf` or `conf.d/10-master.conf`, since
   `da build dovecot`/`./build dovecot`/panel updates can silently
   overwrite those and drop your change (this is the same pattern
   DirectAdmin's own docs use for custom Dovecot config, e.g.
   `conf.d/99-trusted-ips.conf`):
   ```
   service auth {
     unix_listener auth-client-radicale {
       mode = 0660
       user = dovecot
       group = radicale
     }
   }
   ```
   Confirm `dovecot.conf` includes `conf.d/*.conf` (look for
   `!include_try conf.d/*.conf`), then:
   ```
   systemctl restart dovecot
   doveconf -a | grep -A3 auth-client-radicale
   ls -l /var/run/dovecot/auth-client-radicale
   ```
   The `radicale` user is already in the `radicale` group from step 2,
   so no `usermod` is needed. `config/radicale-config` already points
   `dovecot_socket` at `/var/run/dovecot/auth-client-radicale`.
4. **Install the Radicale config and service unit**:
   ```
   mkdir -p /etc/radicale
   cp config/radicale-config /etc/radicale/config
   cp config/radicale.service /etc/systemd/system/radicale.service
   systemctl daemon-reload
   ```
   Do not start the service yet; step 7 does that. The service is tied
   to `dovecot.service`, so restarting Dovecot also restarts Radicale
   and reconnects its authentication socket.
5. **Add `/caldav` and `/carddav` to every domain's vhost** — copy the
   proxy fragment into DirectAdmin's custom template directory:
   ```
   mkdir -p /usr/local/directadmin/data/templates/custom
   cp config/virtual_host2_secure.conf.CUSTOM.post /usr/local/directadmin/data/templates/custom/
   ```
   Only use `virtual_host2.conf.CUSTOM.post` (the HTTP vhost) when HTTP
   redirects to HTTPS before authentication. Do not expose Basic Auth
   over plain HTTP. Then rebuild and reload Apache:
   ```
   (cd /usr/local/directadmin/custombuild && ./build rewrite_confs)
   ```
6. **Run the plugin installer** — sets permissions and links the
   optional cleanup hook:
   ```
   sh scripts/install.sh
   ```
7. **Install Radicale and start it**:
   ```
   sh scripts/update.sh
   ```
   It fetches the latest official Radicale GitHub release, installs it
   into `/opt/radicale-dav/venv` as the `radicale` user, adds a systemd
   drop-in (`radicale.service.d/90-radicale-dav-venv.conf`) so the
   service uses that virtualenv, and enables/restarts the service.
   Radicale itself runs as the unprivileged `radicale` user. Radicale
   3.7 or newer is required for the built-in sharing manager.
8. **Test Dovecot auth directly**, hitting Radicale locally:
   ```
   curl -u alice@example.com:mailpassword http://127.0.0.1:5232/alice@example.com/
   ```
   Confirm it returns something other than 401.
9. **Test through Apache.** Confirm the "Calendar & Contacts" tab
   appears for a test DA user, and that entering a real mailbox address
   there produces a URL a CalDAV client (or `curl -u`) can authenticate
   against:
   ```
   curl -u alice@example.com:mailpassword https://example.com/caldav/alice@example.com/
   ```

## Updating

- **Radicale**: the admin page's "Check for updates" button shows the
  installed and latest version. To update, run as root:
  ```
  cd /usr/local/directadmin/plugins/radicale_dav
  sh scripts/update.sh
  ```
- **The plugin**: `git pull` in the plugin directory (or copy the new
  files over), then run `sh scripts/install.sh` again. If
  `config/radicale.service` changed, copy it to `/etc/systemd/system/`,
  run `systemctl daemon-reload` and `systemctl restart radicale`. After
  changing `/etc/radicale/config`, run `systemctl restart radicale`.

## Files

```
plugin.conf                    DA plugin manifest
hooks/user_txt.html            Menu link shown to end users
hooks/admin_txt.html           Menu link shown to admin
admin/index.html                Admin-level info/reference page
user/index.html                 GUI page: mailbox -> CalDAV/CardDAV URLs
da-hooks/email_destroy_post.sh  Optional: purge a mailbox's calendar data on deletion
scripts/install.sh              Run once after copying the plugin into place
scripts/update.sh               Install/update Radicale in a service-owned virtualenv
scripts/uninstall.sh            Removes the hook symlink (keeps calendar data)
config/radicale-config                       /etc/radicale/config using dovecot auth
config/radicale.service                      Systemd unit (ExecStart overridden by update.sh drop-in)
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
- **DA plugin lifecycle**: `scripts/install.sh`, `update.sh` and
  `uninstall.sh` are run by hand as root, not auto-invoked by DA's
  plugin manager.
- If `email_destroy_post.sh` already exists on your box for something
  else, `install.sh` won't overwrite it — merge the logic in by hand.
  Same goes for `virtual_host2_secure.conf` if you've already
  customized it — merge the `/caldav` block into your existing custom
  copy rather than starting from a fresh default.
