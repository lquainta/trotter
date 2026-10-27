# 🐴 Trotter

A Strava-style ride tracker for horses and their riders. This is Checkpoint 3: logging rides by drawing the route on a map, on top of the accounts, profiles, and settings from Checkpoint 2 and the landing page and feed from Checkpoint 1. Ride pages, photos, horses, and search arrive in later checkpoints.

**Live site:** https://trotter-app.com

## Features

- **Landing page** (`/`) introducing Trotter, with the three most recent rides.
- **Log a Ride** (`/activities/new`, logged-in riders): click the map to draw the route, with Undo last point and Clear route, and a live distance readout; plus title, description, start time, and duration in hours, minutes, and seconds.
- **Distance, pace, and speed**: the distance is calculated from the route (haversine formula) when the ride is saved; pace (time per mile or km) and speed (mph or km/h) follow the rider's units.
- **Feed** (`/activities`) of every ride, newest first, with its distance, time, pace, speed, and a map framed around its route. The map code is Turbo-safe: it cleans up on page changes, so Back and Forward never leave a broken or doubled map.
- **Accounts** (`/registration/new`, `/session/new`): sign up, log in, and log out with a username and password (bcrypt via `has_secure_password`; 10 login attempts per 3 minutes).
- **Rider profiles** (`/users/:username`) with each rider's total rides, distance, and time, and their rides.
- **Settings** (`/settings`): light, dark, or system appearance; miles or kilometers; change password (logs out your other devices); log out; delete your account and rides (needs your password).
- **Shared header and footer** on every page. Logged-out visitors see Log in and Sign up; riders see Log a Ride, their avatar, and a Settings gear.

## Tech stack

| | |
|---|---|
| Language / framework | Ruby 3.3.5, Ruby on Rails 8.1 |
| Database | SQLite |
| Frontend | ERB views, Hotwire (Turbo and Stimulus), import maps, Tailwind CSS 4 |
| Maps | Leaflet 1.9.4 (from unpkg, with Subresource Integrity hashes) and OpenStreetMap tiles |
| Web server | Puma behind nginx (HTTPS via Let's Encrypt and certbot) |
| Hosting | AWS EC2, Ubuntu 24.04 |

## Running it locally

**Step 1: install these tools first.**

| Tool | Ubuntu / Debian | macOS |
|---|---|---|
| Ruby 3.3 or newer | [rbenv and ruby-build from git](https://github.com/rbenv/rbenv#basic-git-checkout), then `rbenv install 3.3.5` (Ubuntu's packaged Ruby and ruby-build are too old) | `brew install rbenv ruby-build`, then `rbenv install 3.3.5` |
| C compiler and make | `sudo apt install build-essential libyaml-dev libssl-dev libffi-dev` | `xcode-select --install` |
| Google Chrome (browser tests only) | from google.com/chrome | from google.com/chrome |

**Step 2: run it.**

```bash
git clone https://github.com/lquainta/trotter.git
cd trotter
./start.sh
```

`start.sh` checks the tools above, installs the Ruby gems, creates the SQLite database with sample riders and rides (log in as `demo` / `password123`), builds the CSS, and starts the app at **http://localhost:3000**. It's safe to run again. Use `./start.sh --port 4000` for another port.

For development with automatic CSS rebuilding, use `bin/dev` instead.

## Tests

```bash
bin/rails test          # model, helper, and controller tests
bin/rails test:system   # browser tests in headless Chrome
bin/rails test:all      # both

bin/rubocop             # code style
bin/brakeman            # security scan
```

GitHub Actions runs all of these on every push and pull request (`.github/workflows/ci.yml`).

## Deploying to AWS EC2

The `deploy/` folder holds everything for an Ubuntu 24.04 instance (the security group needs ports 22, 80 and 443 open):

| File | What it does |
|---|---|
| `deploy/setup-ec2.sh` | One-time server setup, run on the server with sudo: Ruby (via rbenv), nginx, `/opt/trotter`, and the systemd service |
| `deploy/trotter.service` | The systemd unit that starts Trotter on boot and restarts it if it crashes |
| `deploy/nginx-trotter.conf`, `deploy/nginx-trotter-proxy.conf` | nginx forwards ports 80/443 to Puma on port 3000 |
| `deploy/deploy.sh` | Run from your laptop: tests, copies the code with rsync, installs gems, migrates, loads the sample riders and rides, restarts, and checks `/api/health` |

**One-time server setup** (compiling Ruby takes 20-30 minutes on a t2.micro):

```bash
scp -i landonquaintance-cs408.pem -r deploy ubuntu@<PUBLIC-IP>:~
ssh -i landonquaintance-cs408.pem ubuntu@<PUBLIC-IP>
sudo bash deploy/setup-ec2.sh --https   # --https: Let's Encrypt for trotter-app.com (DNS must point at the server)
```

**Deploy** (from your laptop, every time you want the server to have your latest code):

```bash
./deploy/deploy.sh -h <PUBLIC-IP> -i landonquaintance-cs408.pem
```

The site is then at `http://<PUBLIC-IP>/` and https://trotter-app.com. The database lives in `/opt/trotter/storage` on the server and are never overwritten by a deploy. The public IP changes if the instance is *stopped*, so keep EC2 stop protection on (reboots are fine).

### Everyday commands (on the server)

| Task | Command |
|---|---|
| Status / logs | `systemctl status trotter` / `journalctl -u trotter -f` |
| Restart | `sudo systemctl restart trotter` |
| Health check | `curl http://localhost/api/health` |
| Rails console | `cd /opt/trotter && set -a && . /etc/trotter.env && set +a && RAILS_ENV=production bin/rails console` |

## Credits

- Tab icon: horse face from [Noto Emoji](https://github.com/googlefonts/noto-emoji) (Apache 2.0).
