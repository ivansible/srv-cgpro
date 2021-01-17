# ivansible.srv_cgpro

[![Github Test Status](https://github.com/ivansible/srv-cgpro/workflows/test/badge.svg?branch=master)](https://github.com/ivansible/srv-cgpro/actions)
[![Ansible Galaxy](https://img.shields.io/badge/galaxy-ivansible.srv__cgpro-68a.svg?style=flat)](https://galaxy.ansible.com/ivansible/srv_cgpro/)

This role provisions CommuniGate Pro integrated mail / telephony server on Linux.

This play can purge the data directory and force initial setup depending on
the `cgpro_reset` flag, which is normally `false` when running over already
deployed cgpro. Force it from command line:

    ivantory-role .srv-cgpro cgpro-hostname -e cgpro_reset=true

By default this role either performs a vanilla cgpro setup or (when running over
already install cgpro) only tweaks a few critical settings without changing
a whole lot. If you want to restore all settings (and probably mails) from backup,
force it from command line:

    ivantory-role .srv-cgpro cgpro-hostname -e cgpro_restore=true


## Requirements

None


## Variables

Available variables are listed below, along with default values.

    cgpro_reset: false
    cgpro_restore: false
These switches can be only activated from ansible cli.

    cgpro_domains:
      - "{{ mail_domain }}"  # test.example.com, main domain
      - "{{ cgpro_mail_site }}"  # mail.test.example.com, secondary domains
      - localhost
      - local
      - mail
The first domain is the main cgpro domain name. The rest is aliases.
The `mail_domain` setting is imported from the `nginx_base` role.

    cgpro_mail_site: "mail.{{ web_domain }}"
    cgpro_admin_site: "cgpro.{{ web_domain }}"
The `web_domain` setting is imported from the `nginx_base` role.

    cgpro_force_ssl: true
By default nginx sites for cgpro always redirect to _https_.

    cgpro_ssl_cert: "{{ nginx_ssl_cert }}"
    cgpro_ssl_key: "{{ nginx_ssl_key }}"
Path of files with certificate chain and private key in _pem_ format.
The first file must be a full-chain pem file, where first part is
a server certificate and remaining parts consitute authority chain (optional).
This role creates a script `/usr/local/sbin/cgpro-update-cert.sh`
which you can manually run (as root) after changing the certificate.
If this role detects that a letsencrypt certificate is used, it will
install a post-renewal hook `/etc/letsencrypt/renewal-hooks/post/cgpro`.

    cgpro_trusted_cacerts:
      - name: Let's Encrypt Authority X3
        serial: 0A0141420000015385736A0B85ECA708
        file: letsencrypt-x3.cross-signed.pem
Files of trusted authority certificates should be placed in the `files`
directory beside the playbook. This role detects whether a particular
certificate is already installed in cgpro and only installs new certificates.
By default it uses `serial` for detection, but some authorities use
trivial serials, like `01` or `02`. In this case set the `serial` field
to an empty string, and the role will use authority `name` for detection.

    cgpro_postmaster_password: cgpro-secret1
Please change the default. If you are restoring from a backup, make sure
the password matches archived settings (else installation will fail).

    cgpro_master_key: ""
    cgpro_enabling_keys: []
License keys. Master key must correspond to the main domain.

    cgpro_restore_urls: []
The list of backup archives is required only if `cgpro_restore` is `true`.
This can be set in inventory as a list of urls
or on ansible command line as a string of urls concatenated by comma.

Archives should be in the `tar.gz` format encrypted with `openssl aes`
cipher (see [ivansible.backup_base](https://github.com/ivansible/backup-base)).
This role creates a utility script `/usr/local/bin/cgpro-make-backup.sh`
for producing compatible archives in future.

    cgpro_skins:
      - name: Example Skin
        url: https://example.com/download/skins/example.tar.zip?param=test
        check_file: version
        md5sum: 1a2b3c4d5e6f708192a3b4c5d6e7f80e
The `cgpro_skins` parameter must be a list of extra skins to install.
The `name` and `url` fields are required. If one of them is empty, the
corresponding skin will not be installed.
The `url` must point to a zip archive containing a required tarball
with name `SKIN_NAME.tar` and optional files (skin README, help etc).
The `check_file` and `md5sum` fields are optional. If they are omitted,
that skin will be installed even if it's already present in cgpro.
If these fields are present, the given file will be searched under
the skin directory `/var/CommuniGate/Accounts/WebSkins/<SKIN_NAME>/`,
and the skin will be installed only if the file is absent
or upgraded only if its md5 checksum mismatches.

    cgpro_port_smtp: 25       # you'll never change this one
    cgpro_port_smtp_ssl: 465
    cgpro_port_imap: 143
    cgpro_port_imap_ssl: 993
    cgpro_port_sip: 5060
    cgpro_port_sip_ssl: 5061
    cgpro_port_ldap: 389
    cgpro_port_ldap_ssl: 636
Normally you only need to change ports only if you have another daemon
that uses them, like OpenLDAP or Asterisk.

    cgpro_open_ports: ...
Normally only SMTP and IMAP-SSL ports are open in ubuntu firewall.

    cgpro_deb_url: https://communigate.com/...-Linux_6.2-7_amd64.deb
Location of the CGpro Ubuntu x86-64 debian package.
See official download page: https://www.communigate.com/main/purchase/download.html

    cgpro_favicon_url: https://communigate.com/favicon.ico
Custom favicon for webmail.


## Tags

- `cgpro_all` -- the whole role

- `cgpro_install` -- install cgpro debian package, install utilities
                     required for configuration, tweak sysctl.
- `cgpro_sysctl` -- tweak a few sysctl parameters
                    (e.g. maximum number of threads per process
                     or size of a socket listen backlog)
- `cgpro_alternatives` -- create symbolic links for `mail` and `sendmail`
- `cgpro_dir` -- if `cgpro_reset` is `true`, completely purge cgpro data directory
- `cgpro_restore` -- restore cgpro settings and mails from encrypted backup archives
- `cgpro_service` -- disable `/etc/init.d` cgpro script
                     and enable new-style systemd service `cgpro`
- `cgpro_firstrun` -- the first cgpro install should tweak postmaster password
                      and basic settings, cgpro requires these first steps
                      only when its data directory is empty.
- `cgpro_configure` -- configure main domain name and aliases, install licenses,
                       select modern administration interface skin
- `cgpro_ports` -- set SIP, LDAP, SMTP and IMAP ports,
                   open ports in ubuntu firewall
- `cgpro_firewall` -- open CGPro ports in firewall
- `cgpro_ssl` -- add new cgpro trusted certificate authorities,
                 upload cgpro ssl certificate and private key,
                 if letsencrypt certificate is detected, deploy a letsencrypt hook
                 to automatically update cgpro when certificate is renewed
- `cgpro_skin` -- install and configure a custom webmail skin
- `cgpro_nginx` -- setup nginx in front of cgpro webmail and administration sites


## Dependencies

- [ivansible.lin_base](https://github.com/ivansible/lin-base) --
  for common modules and settings, e.g. `allow_sysctl`
- [ivansible.cert_base](https://github.com/ivansible/cert-base) --
  for common certbot settings
- [ivansible.nginx_base](https://github.com/ivansible/nginx-base) --
  for ssl certificate file path and nginx config snippets
- [ivansible.backup_base](https://github.com/ivansible/backup-base) --
  for `unarchive_encrypted.yml`

The following roles are imported directly from tasks:
- [ivansible.lin_nginx](https://github.com/ivansible/lin-nginx)

This role _may_ require one of _letsencrypt_ roles deployed on the box.


## Example Playbook

    - hosts: cgpro-server
      roles:
         - role: ivansible.srv_cgpro
           cgpro_domains:
             - example.com
             - mail.example.org


## License

MIT

## Author Information

Created in 2018-2021 by [IvanSible](https://github.com/ivansible)
