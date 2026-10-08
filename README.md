# 🐴 Trotter

A Strava-style ride tracker for horses and their riders. Draw your route on a map, log how long you rode, add photos of the views, and share it all in a feed.

**Live site:** https://trotter-app.com

## Features

- **Log a ride** by clicking points on a map to draw the route (with Undo). Trotter calculates the distance, average pace, and average speed.
- **Feed** of everyone's rides, each with a map automatically framed around its route, its stats, and photos.
- **Photos** on each ride (up to 10; JPEG, PNG, WebP, or iPhone HEIC), resized and converted to WebP.
- **Accounts** with a username and password, and **rider profiles** with total rides, distance, and time.
- **Settings**: light, dark, or system appearance; miles or kilometers; change password.

## Tech stack

| | |
|---|---|
| Language / framework | Ruby 3.3.5, Ruby on Rails 8.1 |
| Database | SQLite (routes stored as JSON) |
| Frontend | ERB views, Hotwire (Turbo), import maps, Tailwind CSS 4 |
| Maps | Leaflet 1.9.4 with OpenStreetMap tiles |
| Photos | Active Storage + libvips |
| Web server | Puma behind nginx (HTTPS via Let's Encrypt and certbot) |
| Hosting | AWS EC2, Ubuntu 24.04 |

## Running it locally

**Step 1: install these tools first.**

| Tool | Ubuntu / Debian | macOS |
|---|---|---|
| Ruby 3.3 or newer | [rbenv and ruby-build from git](https://github.com/rbenv/rbenv#basic-git-checkout), then `rbenv install 3.3.5` (Ubuntu's packaged Ruby and ruby-build are too old) | `brew install rbenv ruby-build`, then `rbenv install 3.3.5` |
| C compiler and make | `sudo apt install build-essential libyaml-dev libssl-dev libffi-dev` | `xcode-select --install` |
| libvips (photo resizing) | `sudo apt install libvips-tools libheif-plugin-libde265` | `brew install vips` |
| Google Chrome (browser tests only) | from google.com/chrome | from google.com/chrome |

**Step 2: run it.**

```bash
git clone https://github.com/lquainta/trotter.git
cd trotter
./start.sh
```

`start.sh` checks the tools above, installs the Ruby gems, creates the SQLite database with sample riders and rides, builds the CSS, and starts the app at **http://localhost:3000**. It's safe to run again. Log in as `demo` with password `password123`. Use `./start.sh --port 4000` for another port.

For development with automatic CSS rebuilding, use `bin/dev` instead.

## Tests

```bash
bin/rails test          # model, helper, and controller tests
bin/rails test:system   # browser tests in headless Chrome (needs internet for the map tiles)
bin/rails test:all      # both

bin/rubocop             # code style
bin/brakeman            # security scan
```

GitHub Actions runs all of these on every push and pull request (`.github/workflows/ci.yml`).

## Deploying to AWS EC2

The `deploy/` folder holds everything for an Ubuntu 24.04 instance (the security group needs ports 22, 80 and 443 open):

| File | What it does |
|---|---|
| `deploy/setup-ec2.sh` | One-time server setup, run on the server with sudo: Ruby (via rbenv), libvips, nginx, `/opt/trotter`, and the systemd service |
| `deploy/trotter.service` | The systemd unit that starts Trotter on boot and restarts it if it crashes |
| `deploy/nginx-trotter.conf`, `deploy/nginx-trotter-proxy.conf` | nginx forwards ports 80/443 to Puma on port 3000 |
| `deploy/deploy.sh` | Run from your laptop: tests, copies the code with rsync, installs gems, migrates, restarts, and checks `/api/health` |

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

The site is then at `http://<PUBLIC-IP>/` and https://trotter-app.com. The database and uploaded photos live in `/opt/trotter/storage` on the server and are never overwritten by a deploy. The public IP changes if the instance is *stopped*, so keep EC2 stop protection on (reboots are fine).

### Everyday commands (on the server)

| Task | Command |
|---|---|
| Status / logs | `systemctl status trotter` / `journalctl -u trotter -f` |
| Restart | `sudo systemctl restart trotter` |
| Health check | `curl http://localhost/api/health` |
| Rails console | `cd /opt/trotter && set -a && . /etc/trotter.env && set +a && RAILS_ENV=production bin/rails console` |

## Credits

- Map data © [OpenStreetMap](https://www.openstreetmap.org/copyright) contributors, displayed with [Leaflet](https://leafletjs.com).
- Tab icon: horse face from [Noto Emoji](https://github.com/googlefonts/noto-emoji) (Apache 2.0).
- Settings icon from [Heroicons](https://heroicons.com) (MIT).
