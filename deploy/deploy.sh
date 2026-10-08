#!/usr/bin/env bash
#
# Push this project to an EC2 instance that has already been prepared with
# deploy/setup-ec2.sh.
#
# Run it from your own machine (macOS or Linux):
#
#   ./deploy/deploy.sh -h 16.144.234.75 -i landonquaintance-cs408.pem
#
# What it does:
#   1. Runs the tests (skip with -s).
#   2. rsyncs the code to /opt/trotter on the server. The database and uploaded
#      photos (storage/), logs and installed gems stay on the server.
#   3. Installs gems, applies database migrations and compiles assets there.
#   4. Restarts the systemd service and checks http://HOST/api/health.
#
# Options:
#   -h HOST   public IP or DNS name of the instance   (required)
#   -i KEY    path to your .pem private key           (optional if ssh-agent has it)
#   -u USER   SSH login user (default: ubuntu)
#   -s        skip the tests

set -euo pipefail

REMOTE_HOST=""
SSH_KEY=""
REMOTE_USER="ubuntu"
REMOTE_DIR="/opt/trotter"
SERVICE="trotter"
RUN_TESTS="true"

usage() {
    awk 'NR>1 { if (/^#/) { sub(/^# ?/, ""); print } else { exit } }' "$0"
    exit 1
}

while getopts ":h:i:u:s" option; do
    case "$option" in
        h) REMOTE_HOST="$OPTARG" ;;
        i) SSH_KEY="$OPTARG" ;;
        u) REMOTE_USER="$OPTARG" ;;
        s) RUN_TESTS="false" ;;
        :) echo "ERROR: -$OPTARG needs a value" >&2; usage ;;
        \?) echo "ERROR: unknown option -$OPTARG" >&2; usage ;;
    esac
done

[ -n "$REMOTE_HOST" ] || { echo "ERROR: -h HOST is required" >&2; usage; }

# Run from the project root no matter where the script was called from.
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
[ -f Gemfile ] || { echo "ERROR: no Gemfile in $PROJECT_DIR" >&2; exit 1; }

SSH_OPTS=(-o StrictHostKeyChecking=accept-new)
if [ -n "$SSH_KEY" ]; then
    [ -f "$SSH_KEY" ] || { echo "ERROR: key file not found: $SSH_KEY" >&2; exit 1; }
    SSH_OPTS+=(-i "$SSH_KEY")
fi
TARGET="${REMOTE_USER}@${REMOTE_HOST}"

if [ "$RUN_TESTS" = "true" ]; then
    echo "==> Running tests before deploying"
    bin/rails test
fi

echo "==> Copying files to ${TARGET}:${REMOTE_DIR}"
# --delete makes the server an exact mirror of your source. The excludes keep
# local-only and server-only things out of the copy (and safe from --delete).
rsync -az --delete \
    --exclude '.git' \
    --exclude '.bundle' \
    --exclude 'vendor/bundle' \
    --exclude 'storage/*' \
    --exclude 'tmp/*' \
    --exclude 'log/*' \
    --exclude 'public/assets' \
    --exclude 'app/assets/builds/*' \
    --exclude 'node_modules' \
    --exclude '*.pem' \
    --exclude '.env*' \
    --exclude '.DS_Store' \
    -e "ssh ${SSH_OPTS[*]}" \
    ./ "${TARGET}:${REMOTE_DIR}/"

echo "==> Installing gems, migrating the database and restarting the service"
ssh "${SSH_OPTS[@]}" "$TARGET" "
    set -e
    export PATH=\"\$HOME/.rbenv/shims:\$PATH\"
    cd '${REMOTE_DIR}'
    bundle config set --local deployment true
    bundle config set --local without 'development test'
    bundle install --quiet
    set -a; . /etc/trotter.env; set +a
    export RAILS_ENV=production
    bin/rails db:prepare
    bin/rails assets:precompile
    sudo systemctl restart ${SERVICE}
    sleep 3
    sudo systemctl is-active --quiet ${SERVICE} && echo 'service is running'
"

echo "==> Checking the health endpoint"
for _ in 1 2 3 4 5 6 7 8 9 10; do
    if curl -fsSL --max-time 10 -o /dev/null "http://${REMOTE_HOST}/api/health"; then
        printf '\n==> Deployed. Open http://%s/ in your browser.\n' "$REMOTE_HOST"
        exit 0
    fi
    sleep 3
done
echo "WARNING: the health check did not answer." >&2
echo "Check the EC2 security group (port 80 inbound) and the logs:" >&2
echo "  ssh ${SSH_OPTS[*]} $TARGET 'journalctl -u ${SERVICE} -n 50'" >&2
exit 1
