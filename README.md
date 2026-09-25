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
| Web server | Puma behind Thruster (HTTPS via Let's Encrypt) |
| Hosting | AWS EC2, Ubuntu 24.04 |

## Running it locally (macOS)

You'll need [Homebrew](https://brew.sh), Git, and Google Chrome (for the browser tests).

```bash
# Ruby 3.3.5 and libvips (for photos)
brew install rbenv ruby-build vips
echo 'eval "$(rbenv init - zsh)"' >> ~/.zshrc   # then open a new terminal
rbenv install 3.3.5

# Get the code, install gems, and create the database
git clone https://github.com/lquainta/trotter.git
cd trotter
bin/setup --skip-server

# Optional: demo riders and rides (every demo password is "password123")
bin/rails db:seed

# Start the app at http://localhost:3000
bin/dev
```

`bin/dev` runs the Rails server plus a Tailwind watcher that rebuilds the CSS when views change.

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

Two scripts in `script/ec2/` set up a fresh **Ubuntu 24.04** instance. The security group needs ports 22, 80, and 443 open.

```bash
ssh -i your-key.pem ubuntu@<public-ip>
curl -fsSLO https://github.com/lquainta/trotter/raw/main/script/ec2/install_packages.sh
curl -fsSLO https://github.com/lquainta/trotter/raw/main/script/ec2/configure_app.sh
sudo bash install_packages.sh   # system packages, 2 GB swap, rbenv + Ruby (slow on a t2.micro)
bash configure_app.sh           # clones the app, sets up the database and assets, starts it on boot
```

`configure_app.sh` creates `/etc/trotter.env` with a new `SECRET_KEY_BASE` and installs a `trotter` systemd service, so the app starts on every boot and restarts if it crashes.

### HTTPS

Point your domain's `A` records (`@` and `www`) at the instance, then:

```bash
echo 'TLS_DOMAIN=trotter-app.com,www.trotter-app.com' | sudo tee -a /etc/trotter.env
sudo systemctl restart trotter
```

Thruster gets and renews Let's Encrypt certificates automatically. The public IP changes if the instance is *stopped*, so keep EC2 stop protection on (reboots are fine).

### Everyday commands (on the server)

| Task | Command |
|---|---|
| Deploy new code | `bash ~/trotter/script/ec2/configure_app.sh` (run it twice if the push changed the script itself) |
| Add demo data | `SEED_DEMO_DATA=true bash ~/trotter/script/ec2/configure_app.sh` |
| Status / logs | `systemctl status trotter` / `journalctl -u trotter -f` |
| Restart | `sudo systemctl restart trotter` |
| Health check | `curl http://localhost:3000/up` |

## Credits

- Map data © [OpenStreetMap](https://www.openstreetmap.org/copyright) contributors, displayed with [Leaflet](https://leafletjs.com).
- Tab icon: horse face from [Noto Emoji](https://github.com/googlefonts/noto-emoji) (Apache 2.0).
- Settings icon from [Heroicons](https://heroicons.com) (MIT).
