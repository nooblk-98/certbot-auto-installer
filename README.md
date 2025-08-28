# Certbot Auto Installer

Certbot Auto Installer is a small, cross-distro Bash tool to install Certbot, obtain TLS certificates from Let's Encrypt, and manage renewals. It supports non-interactive usage, basic DNS/HTTP challenges, and auto-renew configuration via systemd timer or cron.

## Features
- Simple install across popular distros (apt, dnf/yum, pacman, apk, zypper)
- Detects Nginx/Apache and installs the matching Certbot plugin when possible
- Obtain certificates via DNS or HTTP (webroot) challenges
- Renew one certificate or all due certificates; supports `--dry-run`
- Manage auto-renewal (enable/disable/status) using systemd or cron
- CLI-focused with clear help, suitable for automation

## Quick Start
- Install Certbot and plugin if a webserver is active:
  - `bin/certbot-auto-installer install`
- Obtain a certificate using HTTP (webroot):
  - `bin/certbot-auto-installer obtain --http -d example.com -w /var/www/html`
- Obtain a certificate using DNS challenge (manual):
  - `bin/certbot-auto-installer obtain --dns -d example.com`
- Renew all due certificates:
  - `bin/certbot-auto-installer renew --all`
- Enable auto-renewal:
  - `bin/certbot-auto-installer auto-renew enable`

You can also use the legacy wrapper at the repository root:
- `./certbot-installer.sh <command> [options]`

## Usage
Run `bin/certbot-auto-installer help` for full help:

```
certbot-auto-installer [command] [options]

Commands:
  install                       Install certbot and optional webserver plugin
  list                          List existing certificates
  detect                        Detect OS, package manager, and active webserver
  obtain [--dns|--http] -d DOMAIN [-w WEBROOT]
                                Obtain a new certificate via DNS or HTTP challenge
  renew [-d DOMAIN|--all]       Renew a specific certificate or all due certificates
  auto-renew [enable|disable|status]
                                Manage system auto-renewal (systemd timer if available)
  version                       Print version
  help                          Show help

Options:
  -y                            Assume yes (non-interactive) where applicable
  --dry-run                     Use certbot --dry-run for obtain/renew
  -v, --verbose                 Enable verbose logging
```

## Supported Platforms
- Debian/Ubuntu (apt)
- RHEL/CentOS/Alma/Rocky/Fedora (dnf/yum)
- Arch Linux (pacman)
- Alpine (apk)
- openSUSE/SLES (zypper)

## Requirements
- Bash 4+
- `sudo` (when not running as root)
- Internet access from the server to Let's Encrypt endpoints

## Notes
- The DNS method uses Certbot manual DNS challenge; you’ll need to add TXT records as prompted.
- For HTTP validation, ensure your webroot is correct and reachable over port 80.
- On systems without `systemd`, the script falls back to `cron` for auto-renew.

## Project Structure
- `bin/certbot-auto-installer`: Main CLI entrypoint
- `lib/common.sh`: Shared helpers and platform detection
- `certbot-installer.sh`: Backwards-compatible wrapper (deprecated)

## Contributing
Issues and PRs are welcome. Please keep changes focused and aligned with the current style.

## License
This project is licensed under the MIT License. See `LICENSE`.
