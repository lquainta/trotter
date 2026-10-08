#!/usr/bin/env bash
#
# One-time setup for a fresh Ubuntu EC2 instance.
#
# Copy this whole deploy/ folder to the server and run it once as root:
#
#   scp -i mykey.pem -r deploy ubuntu@<PUBLIC-IP>:~
#   ssh -i mykey.pem ubuntu@<PUBLIC-IP>
#   sudo bash deploy/setup-ec2.sh            # HTTP only
#   sudo bash deploy/setup-ec2.sh --https    # also get HTTPS for trotter-app.com
#
# It installs Ruby (through rbenv), libvips and nginx, creates /opt/trotter,
# sets nginx to forward port 80 to the app, and registers deploy/trotter.service
# with systemd so the app starts on boot. After this, use deploy/deploy.sh from
# your laptop to push code.
#
# --https needs trotter-app.com's DNS A records to point at this server first.
# It runs certbot, which agrees to Let's Encrypt's terms of service.
#
# Safe to run again. Works on Ubuntu 24.04.

set -euo pipefail

APP_NAME="trotter"
APP_DIR="/opt/trotter"
RUBY_VERSION="3.3.5"          # Keep in step with .ruby-version
DOMAINS=(trotter-app.com www.trotter-app.com)
ENV_FILE="/etc/trotter.env"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# The person who ran sudo owns the code, runs the app, and gets Ruby installed.
DEPLOY_USER="${SUDO_USER:-ubuntu}"
DEPLOY_HOME="$(getent passwd "$DEPLOY_USER" | cut -d: -f6)"

HTTPS="false"
[ "${1:-}" = "--https" ] && HTTPS="true"

say() {
    printf '\n==> %s\n' "$1"
}

die() {
    printf 'ERROR: %s\n' "$1" >&2
    exit 1
}

# --- checks -----------------------------------------------------------------

[ "$(id -u)" -eq 0 ] || die "run this with sudo: sudo bash $0"
[ -r /etc/os-release ] || die "cannot read /etc/os-release; unsupported system"
# shellcheck disable=SC1091
. /etc/os-release
[ "${ID:-}" = "ubuntu" ] || die "this script supports Ubuntu; found '${ID:-unknown}'"
[ -n "$DEPLOY_HOME" ] || die "cannot find the home directory of '$DEPLOY_USER'"

say "Setting up $APP_NAME on ${PRETTY_NAME:-Ubuntu} for user '$DEPLOY_USER'"

# If the app is already running (a re-run), stop it so nothing holds port 80
# while nginx is installed and restarted.
systemctl stop "$APP_NAME" 2>/dev/null || true

# --- packages ---------------------------------------------------------------

say "Installing system packages"
export DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a
apt-get update -y
apt-get install -y --no-install-recommends \
    git curl ca-certificates rsync \
    build-essential pkg-config \
    libssl-dev libreadline-dev zlib1g-dev libyaml-dev libffi-dev libgmp-dev \
    sqlite3 libsqlite3-dev \
    libvips libheif-plugin-libde265 \
    nginx certbot python3-certbot-nginx
# libheif only suggests the HEVC decoder plugin, which iPhone HEIC photos need.

# --- swap -------------------------------------------------------------------

# A t2.micro has 1 GB of memory, not enough to compile Ruby.
if ! swapon --show | grep -q '^/swapfile'; then
    say "Adding 2 GB of swap"
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# --- Ruby -------------------------------------------------------------------

say "Installing rbenv and Ruby $RUBY_VERSION for $DEPLOY_USER (compiling takes 20-30 minutes on a t2.micro)"
sudo -u "$DEPLOY_USER" -H bash -s -- "$RUBY_VERSION" <<'EOF'
set -euo pipefail
[ -d ~/.rbenv ] || git clone --depth 1 https://github.com/rbenv/rbenv.git ~/.rbenv
[ -d ~/.rbenv/plugins/ruby-build ] || git clone --depth 1 https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
git -C ~/.rbenv/plugins/ruby-build pull --ff-only -q || true
grep -q 'rbenv init' ~/.bashrc || echo 'eval "$(~/.rbenv/bin/rbenv init - bash)"' >> ~/.bashrc
~/.rbenv/bin/rbenv install --skip-existing "$1"
~/.rbenv/bin/rbenv global "$1"
~/.rbenv/shims/gem install bundler --conservative --no-document
EOF

# --- app directory and secrets ----------------------------------------------

say "Creating $APP_DIR"
mkdir -p "$APP_DIR/storage" "$APP_DIR/tmp" "$APP_DIR/log"
chown -R "$DEPLOY_USER:$DEPLOY_USER" "$APP_DIR"

if [ ! -f "$ENV_FILE" ]; then
    say "Creating $ENV_FILE with a new SECRET_KEY_BASE"
    install -m 600 -o "$DEPLOY_USER" -g "$DEPLOY_USER" /dev/null "$ENV_FILE"
    echo "SECRET_KEY_BASE=$(openssl rand -hex 64)" > "$ENV_FILE"
fi

# --- systemd ----------------------------------------------------------------

say "Installing the $APP_NAME systemd service"
sed -e "s#/home/ubuntu#${DEPLOY_HOME}#g" -e "s#^User=ubuntu#User=${DEPLOY_USER}#" -e "s#^Group=ubuntu#Group=${DEPLOY_USER}#" \
    "$SCRIPT_DIR/trotter.service" > "/etc/systemd/system/${APP_NAME}.service"
chmod 644 "/etc/systemd/system/${APP_NAME}.service"
systemctl daemon-reload
systemctl enable "$APP_NAME"

# Start it again if code has already been deployed (a re-run).
if [ -f "$APP_DIR/Gemfile" ]; then
    systemctl start "$APP_NAME"
fi

# --- nginx ------------------------------------------------------------------

say "Configuring nginx as a reverse proxy on port 80"
install -m 644 "$SCRIPT_DIR/nginx-trotter-proxy.conf" /etc/nginx/snippets/trotter-proxy.conf
install -m 644 "$SCRIPT_DIR/nginx-trotter.conf" "/etc/nginx/conf.d/${APP_NAME}.conf"

# Ubuntu's default site also claims port 80 as the default server.
rm -f /etc/nginx/sites-enabled/default

nginx -t
systemctl enable nginx
systemctl restart nginx

# --- HTTPS ------------------------------------------------------------------

# Run certbot when asked, or when a certificate already exists (a re-run just
# replaced the nginx config, so certbot has to add HTTPS back to it).
if [ "$HTTPS" = "true" ] || [ -d "/etc/letsencrypt/live/${DOMAINS[0]}" ]; then
    say "Setting up HTTPS for ${DOMAINS[*]}"
    certbot_args=()
    for domain in "${DOMAINS[@]}"; do certbot_args+=(-d "$domain"); done
    certbot --nginx "${certbot_args[@]}" --non-interactive --agree-tos \
        --register-unsafely-without-email --redirect --keep-until-expiring
fi

# --- firewall ---------------------------------------------------------------

if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
    say "Opening ports 22, 80 and 443 in ufw"
    ufw allow 22/tcp
    ufw allow 80/tcp
    ufw allow 443/tcp
fi

# --- done -------------------------------------------------------------------

cat <<EOF

==> Server setup is complete.

If you haven't deployed yet, run this from your laptop, in the project folder:

    ./deploy/deploy.sh -h <PUBLIC-IP> -i path/to/key.pem

Then open http://<PUBLIC-IP>/ in a browser.

The EC2 security group must allow inbound TCP 22, 80 and 443.

Handy commands on this server:
    sudo systemctl status $APP_NAME
    journalctl -u $APP_NAME -f
    sudo systemctl restart $APP_NAME
EOF
