// Leaflet maps for Trotter: the route-drawing map on activities/new and the static route
// maps in the activities/index feed. Leaflet is loaded from the CDN in the layout <head>,
// so it is available here as the global `L`.

const BOISE = [ 43.606, -116.204 ]
const OSM_TILE_URL = "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
const OSM_ATTRIBUTION = '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
const METERS_PER_UNIT = { mi: 1609.344, km: 1000 }

// Every map on the current page, so they can be torn down before Turbo caches it.
let liveMaps = []

function createMap(container, options = {}) {
  const map = L.map(container, options)
  L.tileLayer(OSM_TILE_URL, { maxZoom: 19, attribution: OSM_ATTRIBUTION }).addTo(map)
  liveMaps.push(map)
  return map
}

function parseRoute(json) {
  try {
    const route = JSON.parse(json || "null")
    return Array.isArray(route) ? route : []
  } catch {
    return []
  }
}

// ~11 cm of precision is plenty for a horse.
function roundCoordinate(value) {
  return Math.round(value * 1e6) / 1e6
}

// distanceTo is the same haversine formula Activity uses on the server, so the numbers match.
function routeDistance(route) {
  let meters = 0
  for (let i = 1; i < route.length; i++) meters += L.latLng(route[i - 1]).distanceTo(route[i])
  return meters
}

// activities/new: each click on the map adds a point; "Undo Last Point" removes one.
function initDrawMap() {
  const container = document.getElementById("route-draw-map")
  if (!container) return
  if (container._leaflet_id) return // Already initialized; Leaflet would throw "Map container is already initialized."

  const input = document.getElementById("route-coordinates-input")
  const undoButton = document.getElementById("undo-last-point")
  const distanceLabel = document.getElementById("route-distance")

  let route = []
  // After a failed save the form re-renders with the submitted points, so keep them.
  route.push(...parseRoute(input.value))

  // Double-clicking would add two points and zoom in, so keep zooming to the buttons and scroll wheel.
  const map = createMap(container, { doubleClickZoom: false }).setView(BOISE, 13)
  const line = L.polyline([], { color: "red", weight: 4, interactive: false }).addTo(map)
  // A one-point polyline is invisible, so mark each point to show the first click landed.
  const points = L.layerGroup().addTo(map)

  function redraw() {
    line.setLatLngs(route)
    points.clearLayers()
    route.forEach((point) => {
      L.circleMarker(point, { radius: 4, color: "red", fillOpacity: 1, interactive: false }).addTo(points)
    })
    input.value = JSON.stringify(route)
    undoButton.disabled = route.length === 0

    const unit = distanceLabel.dataset.distanceUnit
    distanceLabel.textContent = `${(routeDistance(route) / METERS_PER_UNIT[unit]).toFixed(2)} ${unit}`
  }

  map.on("click", (event) => {
    // wrap() keeps longitude within -180..180 even if the map was panned onto another world copy.
    const { lat, lng } = event.latlng.wrap()
    route.push([ roundCoordinate(lat), roundCoordinate(lng) ])
    redraw()
  })

  undoButton.addEventListener("click", () => {
    route.pop()
    redraw()
  })

  redraw()
  if (route.length > 0) map.fitBounds(line.getBounds(), { padding: [ 30, 30 ], maxZoom: 16 })
}

// activities/index: one static, non-interactive map per activity card.
function initFeedMaps() {
  document.querySelectorAll(".feed-map").forEach((container) => {
    if (container._leaflet_id) return // Already initialized

    const map = createMap(container, {
      zoomControl: false,
      dragging: false,
      touchZoom: false,
      scrollWheelZoom: false,
      doubleClickZoom: false,
      boxZoom: false,
      keyboard: false,
    })

    const route = parseRoute(container.dataset.route)
    if (route.length === 0) {
      map.setView(BOISE, 12) // No route: show the map, but no line.
      return
    }

    const line = L.polyline(route, { color: "blue", weight: 4, interactive: false }).addTo(map)
    // maxZoom keeps a very short route from zooming all the way in.
    map.fitBounds(line.getBounds(), { padding: [ 20, 20 ], maxZoom: 16 })
  })
}

function initMaps() {
  // Destroy maps whose containers Turbo has swapped out of the page.
  liveMaps = liveMaps.filter((map) => {
    if (map.getContainer().isConnected) return true
    map.remove()
    return false
  })

  initDrawMap()
  initFeedMaps()
}

// turbo:load fires after every page visit. Turbo renders a failed form submission (422)
// without a visit, so only turbo:render fires then. The _leaflet_id guards make running both safe.
document.addEventListener("turbo:load", initMaps)
document.addEventListener("turbo:render", initMaps)

// Before leaving a page, Turbo saves a copy of it and shows that copy on Back or as a
// preview. Tear the maps down first: map.remove() clears Leaflet's DOM and _leaflet_id,
// so the saved copy holds empty containers that initMaps can fill again.
document.addEventListener("turbo:before-cache", () => {
  liveMaps.forEach((map) => map.remove())
  liveMaps = []
})
