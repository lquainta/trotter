import { Controller } from "@hotwired/stimulus"
import * as L from "leaflet"
import { createMap, addEndpoints, ROUTE_STYLE } from "lib/maps"

// A map framed around one ride's route. Feed maps are still pictures; the ride page sets
// interactive so the rider can pan and zoom around the route.
export default class extends Controller {
  static values = { points: Array, interactive: Boolean }

  connect() {
    const still = {
      zoomControl: false, dragging: false, touchZoom: false, scrollWheelZoom: false,
      doubleClickZoom: false, boxZoom: false, keyboard: false
    }
    // Scrolling the page shouldn't zoom the map by accident; the + and − buttons and pinching still do.
    this.map = createMap(this.element, this.interactiveValue ? { scrollWheelZoom: false } : still)
    const route = L.polyline(this.pointsValue, ROUTE_STYLE).addTo(this.map)
    addEndpoints(this.map, this.pointsValue)
    this.map.fitBounds(route.getBounds(), { padding: [ 24, 24 ], maxZoom: 17 })
  }

  disconnect() {
    this.map.remove()
  }
}
