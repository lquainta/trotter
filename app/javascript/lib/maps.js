import * as L from "leaflet"

export const ROUTE_STYLE = { color: "#b45309", weight: 4, interactive: false } // Tailwind amber-700

const METERS_PER_UNIT = { mi: 1609.344, km: 1000 }
const EARTH_RADIUS_METERS = 6371000

// A Leaflet map with OpenStreetMap tiles. Turbo keeps a copy of each page you leave and shows
// it again on Back or Forward. The map controllers call map.remove() in disconnect() so that copy
// is saved without a map; clearing the element here as well means a stray copy of an old map
// can never end up stacked under the new one.
export function createMap(element, options = {}) {
  element.replaceChildren()
  const map = L.map(element, options)
  L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
    maxZoom: 19,
    attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
  }).addTo(map)
  return map
}

// Small dots marking where the route starts (green) and ends (red).
export function addEndpoints(layer, points) {
  if (points.length === 0) return
  const dot = { radius: 6, weight: 2, color: "#ffffff", fillOpacity: 1, interactive: false }
  L.circleMarker(points[0], { ...dot, fillColor: "#16a34a" }).addTo(layer)
  if (points.length > 1) L.circleMarker(points[points.length - 1], { ...dot, fillColor: "#dc2626" }).addTo(layer)
}

// Same haversine math as Activity.route_distance, so the live distance matches the saved one.
export function routeDistance(points) {
  let meters = 0
  for (let i = 1; i < points.length; i++) {
    const [lat1, lng1] = points[i - 1].map(toRadians)
    const [lat2, lng2] = points[i].map(toRadians)
    const a = Math.sin((lat2 - lat1) / 2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin((lng2 - lng1) / 2) ** 2
    meters += 2 * EARTH_RADIUS_METERS * Math.asin(Math.sqrt(a))
  }
  return meters
}

// Matches the format_distance helper: "6.00 mi"
export function formatDistance(meters, unit) {
  return `${(meters / METERS_PER_UNIT[unit]).toFixed(2)} ${unit}`
}

function toRadians(degrees) {
  return degrees * Math.PI / 180
}
