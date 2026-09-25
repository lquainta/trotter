#!/usr/bin/env bash
# Trotter EC2 setup, script 1 of 2: install system packages and Ruby.
#
# Target: a new Ubuntu Server 24.04 LTS EC2 instance (x86_64 or arm64) with the default "ubuntu" user.
# Run once as root:   sudo bash install_packages.sh
# (Or paste this file into the instance's "User data" box so it runs on first boot.)
set -euo pipefail

APP_USER="${APP_USER:-ubuntu}"
RUBY_VERSION="${RUBY_VERSION:-3.3.5}" # Must match the app's .ruby-version

echo "==> Installing system packages"
export DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a
apt-get update
apt-get -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold upgrade
apt-get install -y --no-install-recommends \
  git curl ca-certificates \
  build-essential pkg-config \
  libssl-dev libreadline-dev zlib1g-dev libyaml-dev libffi-dev libgmp-dev \
  sqlite3 libsqlite3-dev \
  libvips libheif-plugin-libde265 # libheif only suggests the HEVC decoder iPhone HEIC photos need

echo "==> Adding 2 GB of swap so small instances can compile Ruby"
if ! swapon --show | grep -q '^/swapfile'; then
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

echo "==> Installing rbenv and Ruby $RUBY_VERSION for $APP_USER (compiling takes 5-10 minutes)"
sudo -u "$APP_USER" -H bash -s -- "$RUBY_VERSION" <<'EOF'
set -euo pipefail
[ -d ~/.rbenv ] || git clone --depth 1 https://github.com/rbenv/rbenv.git ~/.rbenv
[ -d ~/.rbenv/plugins/ruby-build ] || git clone --depth 1 https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
grep -q 'rbenv init' ~/.bashrc || echo 'eval "$(~/.rbenv/bin/rbenv init - bash)"' >> ~/.bashrc
~/.rbenv/bin/rbenv install --skip-existing "$1"
~/.rbenv/bin/rbenv global "$1"
~/.rbenv/shims/gem install bundler --no-document
EOF

echo "==> Packages installed. Next, as $APP_USER: bash configure_app.sh"
