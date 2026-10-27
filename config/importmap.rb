# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin_all_from "app/javascript/lib", under: "lib"

# Leaflet draws the ride maps. It comes from unpkg, pinned to one version, and the browser
# refuses the file if it doesn't match this hash (Subresource Integrity).
pin "leaflet", to: "https://unpkg.com/leaflet@1.9.4/dist/leaflet-src.esm.js",
  integrity: "sha384-zd+tdvh8fbJAYA8L9jwid1BxMzHku/D6vwnXYzTG7Euqsam73FrDLArv8nyvdlUg"
