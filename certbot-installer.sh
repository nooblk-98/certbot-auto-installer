#!/bin/bash

set -e

echo "==============================="
echo "   Certbot Installer Script"
echo "==============================="

# Check if Certbot is installed
if ! command -v certbot &> /dev/null; then
    echo "[INFO] Installing Certbot..."
    if command -v apt &> /dev/null; then
        sudo apt update
        sudo apt install -y certbot
    elif command -v yum &> /dev/null; then
        sudo yum install -y epel-release
        sudo yum install -y certbot
    else
        echo "[ERROR] Package manager not supported. Install Certbot manually."
        exit 1
    fi
else
    echo "[INFO] Certbot already installed."
fi

# Detect Web Server
WEBSERVER=""
INSTALL_PLUGIN=""

if systemctl is-active --quiet nginx; then
    WEBSERVER="nginx"
    INSTALL_PLUGIN="python3-certbot-nginx"
elif systemctl is-active --quiet apache2; then
    WEBSERVER="apache"
    INSTALL_PLUGIN="python3-certbot-apache"
elif systemctl is-active --quiet httpd; then
    WEBSERVER="apache"
    INSTALL_PLUGIN="python3-certbot-apache"
else
    echo "[WARN] No active Nginx or Apache server detected."
fi

# Install plugin if needed
if [[ -n "$INSTALL_PLUGIN" ]]; then
    echo "[INFO] Installing Certbot plugin for $WEBSERVER..."
    if command -v apt &> /dev/null; then
        sudo apt install -y "$INSTALL_PLUGIN"
    elif command -v yum &> /dev/null; then
        # For RHEL-based systems, plugin package name may be different
        if [[ "$WEBSERVER" == "nginx" ]]; then
            sudo yum install -y certbot-nginx
        elif [[ "$WEBSERVER" == "apache" ]]; then
            sudo yum install -y certbot-apache
        fi
    fi
fi

# Show existing certificates
echo
echo "--------------------------------------"
echo "[INFO] Current Certificates:"
sudo certbot certificates || echo "[WARN] No certificates found."
echo "--------------------------------------"

# Offer to renew a certificate
read -rp "Do you want to renew an existing certificate? (y/n): " RENEW
if [[ "$RENEW" =~ ^[Yy]$ ]]; then
    read -rp "Enter the domain name to renew (e.g., example.com): " DOMAIN
    echo "[INFO] Renewing $DOMAIN..."
    sudo certbot renew --cert-name "$DOMAIN"
fi

# Offer to obtain a certificate manually
echo
read -rp "Do you want to manually obtain a new certificate? (y/n): " MANUALCERT
if [[ "$MANUALCERT" =~ ^[Yy]$ ]]; then
    read -rp "Enter the domain name (e.g., example.com): " DOMAIN
    echo "Choose verification method:"
    echo "  1) HTTP Challenge (requires you to serve a file)"
    echo "  2) DNS Challenge (you will set a TXT DNS record)"
    read -rp "Enter option [1 or 2]: " CHOICE

    if [[ "$CHOICE" == "1" ]]; then
        sudo certbot certonly --manual --preferred-challenges http -d "$DOMAIN" \
            --agree-tos --no-eff-email --manual-public-ip-logging-ok
    elif [[ "$CHOICE" == "2" ]]; then
        sudo certbot certonly --manual --preferred-challenges dns -d "$DOMAIN" \
            --agree-tos --no-eff-email --manual-public-ip-logging-ok
    else
        echo "[ERROR] Invalid option. Skipping manual certificate request."
    fi
fi

# Offer to schedule auto-renewal
echo
read -rp "Do you want to enable auto-renewal? (y/n): " AUTORENEW
if [[ "$AUTORENEW" =~ ^[Yy]$ ]]; then
    if systemctl list-timers | grep -q 'certbot.timer'; then
        echo "[INFO] systemd certbot.timer is already active."
    else
        echo "[INFO] Enabling systemd certbot.timer..."
        sudo systemctl enable certbot.timer
        sudo systemctl start certbot.timer
        echo "[INFO] Auto-renewal enabled via systemd timer."
    fi
else
    echo "[INFO] Skipping auto-renew setup."
fi

echo
echo "==============================="
echo "✅ Certbot operations complete."
echo "==============================="
