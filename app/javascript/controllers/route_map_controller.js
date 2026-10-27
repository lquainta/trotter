import { Controller } from "@hotwired/stimulus"
import * as L from "leaflet"
import { createMap, addEndpoints, ROUTE_STYLE } from "lib/maps"

// A still map framed around one ride's route, for the feed.
export default class extends Controller {
  static values = { points: Array }

  connect() {
    this.map = createMap(this.element, {
      zoomControl: false, dragging: false, touchZoom: false, scrollWheelZoom: false,
      doubleClickZoom: false, boxZoom: false, keyboard: false
    })
    const route = L.polyline(this.pointsValue, ROUTE_STYLE).addTo(this.map)
    addEndpoints(this.map, this.pointsValue)
    this.map.fitBounds(route.getBounds(), { padding: [ 24, 24 ], maxZoom: 17 })
  }

  disconnect() {
    this.map.remove()
  }
}
