#!/usr/bin/env bash
#
# Start Trotter on your own machine.
#
# Checks that the tools Trotter needs are installed, installs the Ruby gems,
# creates the database with sample riders and rides, and starts the app.
# Safe to run again: each step only does work that hasn't been done yet.
#
#   ./start.sh              start the app on http://localhost:3000
#   ./start.sh --port 4000  listen somewhere other than port 3000
#   ./start.sh --help       show this message
#
# Until launch the site is a single "Hello World" page. To run the full app:
#   TROTTER_SHOW_APP=true ./start.sh
#
# This is for development. On the EC2 server, systemd starts the app instead --
# see deploy/setup-ec2.sh and deploy/trotter.service.
#
# Works on Linux and macOS.

set -euo pipefail

# Rails 8.1 and several locked gems (solid_cable among them) need Ruby 3.3+.
REQUIRED_RUBY="3.3"
PORT="3000"

say() {
    printf '==> %s\n' "$1"
}

warn() {
    printf 'WARNING: %s\n' "$1" >&2
}

die() {
    printf 'ERROR: %s\n' "$1" >&2
    exit 1
}

usage() {
    awk 'NR>1 { if (/^#/) { sub(/^# ?/, ""); print } else { exit } }' "$0"
    exit 0
}

while [ $# -gt 0 ]; do
    case "$1" in
        -p|--port)
            [ $# -ge 2 ] || die "--port needs a number, for example: --port 4000"
            case "$2" in
                ''|*[!0-9]*) die "--port needs a number, got '$2'" ;;
            esac
            PORT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            die "unknown option '$1' (try --help)"
            ;;
    esac
done

# Run from the project root no matter where this script was called from.
cd "$(cd "$(dirname "$0")" && pwd)"
[ -f Gemfile ] || die "no Gemfile here. Run this script from inside the project folder."

# Pick up rbenv's Ruby if it's installed but not set up in this shell.
if [ -d "$HOME/.rbenv/shims" ]; then
    export PATH="$HOME/.rbenv/shims:$PATH"
fi

# --- checks -----------------------------------------------------------------

command -v ruby >/dev/null 2>&1 \
    || die "Ruby is not installed. Install Ruby ${REQUIRED_RUBY} or newer (see README.md, step 1)."

ruby -e "exit(Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('${REQUIRED_RUBY}') ? 0 : 1)" \
    || die "Ruby $(ruby -e 'print RUBY_VERSION') is too old. Trotter needs Ruby ${REQUIRED_RUBY} or newer (see README.md, step 1)."

# Several gems (puma, bcrypt, bootsnap, ...) compile C code when installed.
command -v make >/dev/null 2>&1 && { command -v cc >/dev/null 2>&1 || command -v gcc >/dev/null 2>&1; } \
    || die "a C compiler and make are not installed. On Ubuntu: sudo apt install build-essential. On macOS: xcode-select --install."

if ! command -v bundle >/dev/null 2>&1; then
    say "Installing Bundler"
    gem install bundler --no-document \
        || die "could not install Bundler. Try: gem install bundler"
fi

# libvips resizes photos. Everything else works without it, so only warn.
if ! command -v vips >/dev/null 2>&1 && ! pkg-config --exists vips 2>/dev/null \
    && ! { command -v ldconfig >/dev/null 2>&1 && ldconfig -p | grep -q 'libvips\.so'; }; then
    warn "libvips is not installed, so uploaded photos won't be resized or shown."
    warn "On Ubuntu: sudo apt install libvips-tools libheif-plugin-libde265. On macOS: brew install vips."
fi

# --- dependencies -----------------------------------------------------------

if bundle check >/dev/null 2>&1; then
    say "Ruby gems are already installed"
else
    say "Installing Ruby gems (the first time takes a few minutes)"
    bundle install
fi

# --- database and assets ----------------------------------------------------

# Creates the SQLite database in storage/ on the first run and applies any new
# migrations after that. The seeds use find_or_create_by, so running them again
# doesn't duplicate anything. Every sample account's password is "password123".
say "Preparing the database and sample data"
bin/rails db:prepare
bin/rails db:seed

say "Building the CSS"
bin/rails tailwindcss:build

# --- start ------------------------------------------------------------------

say "Starting Trotter on http://localhost:${PORT} -- press Ctrl+C to stop"
if [ "${TROTTER_SHOW_APP:-}" = "true" ]; then
    say "Sample login: username demo, password password123"
fi

# exec replaces this shell with the server, so Ctrl+C reaches it directly.
exec bin/rails server --port "$PORT"
