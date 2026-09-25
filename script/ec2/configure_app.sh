#!/usr/bin/env bash
# Trotter EC2 setup, script 2 of 2: download and configure the app, and start it on every boot.
#
# Run as the ubuntu user after install_packages.sh has finished:
#   REPO_URL=https://github.com/lquainta/trotter.git bash configure_app.sh
# Safe to re-run to deploy new code: it pulls, installs gems, migrates, rebuilds assets, and restarts.
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/lquainta/trotter.git}"
APP_DIR="${APP_DIR:-$HOME/trotter}"
ENV_FILE=/etc/trotter.env
export PATH="$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH"

echo "==> Getting the code"
if [ -d "$APP_DIR/.git" ]; then
  git -C "$APP_DIR" pull --ff-only
else
  git clone "$REPO_URL" "$APP_DIR"
fi
cd "$APP_DIR"

echo "==> Installing Ruby gems (production only)"
rbenv install --skip-existing "$(cat .ruby-version)"
gem install bundler --conservative --no-document
bundle config set --local deployment true
bundle config set --local without "development test"
bundle install

echo "==> Creating $ENV_FILE with a new secret key (first run only)"
if [ ! -f "$ENV_FILE" ]; then
  sudo install -m 600 -o "$USER" -g "$USER" /dev/null "$ENV_FILE"
  cat > "$ENV_FILE" <<EOF
RAILS_ENV=production
SECRET_KEY_BASE=$(openssl rand -hex 64)
SOLID_QUEUE_IN_PUMA=true
EOF
fi
set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

echo "==> Preparing the SQLite databases and compiling assets"
bin/rails db:prepare
bin/rails assets:precompile
if [ "${SEED_DEMO_DATA:-false}" = "true" ]; then
  bin/rails db:seed
fi

echo "==> Installing the systemd service so Trotter starts on boot"
sudo tee /etc/systemd/system/trotter.service > /dev/null <<EOF
[Unit]
Description=Trotter (Rails app)
After=network-online.target
Wants=network-online.target

[Service]
User=$USER
WorkingDirectory=$APP_DIR
EnvironmentFile=$ENV_FILE
Environment=PATH=$HOME/.rbenv/shims:$HOME/.rbenv/bin:/usr/local/bin:/usr/bin:/bin
# Thruster serves port 80 and forwards requests to Puma on port 3000.
ExecStart=$APP_DIR/bin/thrust $APP_DIR/bin/rails server
# Lets Thruster use port 80 without running as root.
AmbientCapabilities=CAP_NET_BIND_SERVICE
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable trotter
sudo systemctl restart trotter

echo "==> Waiting for Trotter to respond"
for _ in $(seq 1 30); do
  if curl -fs http://localhost/up > /dev/null; then
    echo "Trotter is running at http://$(curl -fs https://checkip.amazonaws.com)/"
    exit 0
  fi
  sleep 2
done
echo "Trotter didn't start. See the logs with: journalctl -u trotter -n 100" >&2
exit 1
