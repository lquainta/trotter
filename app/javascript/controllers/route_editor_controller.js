import { Controller } from "@hotwired/stimulus"
import * as L from "leaflet"
import { createMap, addEndpoints, routeDistance, formatDistance, ROUTE_STYLE } from "lib/maps"

// The Log a Ride map: each click adds a point to the route. Keeps the hidden route field
// (JSON [[lat, lng], ...]) and the distance readout up to date.
export default class extends Controller {
  static targets = [ "map", "input", "distance", "undo", "clear" ]
  static values = { unit: String, center: Array, zoom: Number }

  connect() {
    this.points = this.#savedPoints()
    this.map = createMap(this.mapTarget, { doubleClickZoom: false })
    this.route = L.polyline([], ROUTE_STYLE).addTo(this.map)
    this.endpoints = L.layerGroup().addTo(this.map)

    if (this.points.length > 0) {
      this.map.fitBounds(L.latLngBounds(this.points), { padding: [ 32, 32 ], maxZoom: 16 })
    } else {
      this.map.setView(this.centerValue, this.zoomValue)
    }
    this.map.on("click", ({ latlng }) => this.#addPoint(latlng.wrap()))
    this.#render()
  }

  disconnect() {
    this.map.remove()
  }

  undo() {
    this.points.pop()
    this.#render()
  }

  clear() {
    this.points = []
    this.#render()
  }

  #addPoint({ lat, lng }) {
    this.points.push([ round(lat), round(lng) ])
    this.#render()
  }

  #render() {
    this.route.setLatLngs(this.points)
    this.endpoints.clearLayers()
    addEndpoints(this.endpoints, this.points)

    this.inputTarget.value = JSON.stringify(this.points)
    this.distanceTarget.textContent = formatDistance(routeDistance(this.points), this.unitValue)
    this.undoTarget.disabled = this.clearTarget.disabled = this.points.length === 0
  }

  // The route sent back with a form that had errors, so the rider doesn't have to redraw it.
  #savedPoints() {
    try {
      const points = JSON.parse(this.inputTarget.value)
      return Array.isArray(points) ? points.filter(isPoint) : []
    } catch {
      return []
    }
  }
}

function isPoint(point) {
  return Array.isArray(point) && point.length === 2 && point.every(Number.isFinite)
}

// About 10 cm, the same precision the server keeps
function round(degrees) {
  return Math.round(degrees * 1e6) / 1e6
}
