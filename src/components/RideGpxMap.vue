<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { gpx as parseGpx } from '@tmcw/togeojson'
import type { Position } from 'geojson'
import L from 'leaflet'
import 'leaflet/dist/leaflet.css'

const props = defineProps<{ fileUrl: string }>()

const mapContainer = ref<HTMLDivElement | null>(null)
const isLoading = ref(true)
const errorMessage = ref('')

let map: L.Map | null = null
let trackLayer: L.FeatureGroup | null = null
let requestController: AbortController | null = null

const createFlagIcon = (label: string) =>
  L.divIcon({
    className: 'ride-gpx-flag-icon',
    html: `<span class="ride-gpx-flag"><span aria-hidden="true">🏁</span>${label}</span>`,
    iconSize: [112, 34],
    iconAnchor: [15, 32],
  })

const loadTrack = async () => {
  if (!map || !props.fileUrl) return

  requestController?.abort()
  requestController = new AbortController()
  isLoading.value = true
  errorMessage.value = ''

  try {
    const response = await fetch(props.fileUrl, { signal: requestController.signal })
    if (!response.ok) throw new Error('Impossible de télécharger la trace GPX.')

    const xml = new DOMParser().parseFromString(await response.text(), 'application/xml')
    if (xml.querySelector('parsererror')) throw new Error('Le fichier GPX est invalide.')

    const featureCollection = parseGpx(xml)
    const lineFeatures = featureCollection.features.filter(
      (feature) =>
        feature.geometry.type === 'LineString' || feature.geometry.type === 'MultiLineString',
    )
    if (lineFeatures.length === 0) throw new Error('Aucune trace trouvée dans ce fichier GPX.')

    const routeSegments: L.LatLng[][] = []
    const appendSegment = (coordinates: Position[]) => {
      const points = coordinates.flatMap((coordinate) => {
        const [longitude, latitude] = coordinate
        return longitude === undefined || latitude === undefined
          ? []
          : [L.latLng(latitude, longitude)]
      })

      if (points.length > 1) routeSegments.push(points)
    }

    for (const feature of lineFeatures) {
      if (feature.geometry.type === 'LineString') {
        appendSegment(feature.geometry.coordinates)
      } else if (feature.geometry.type === 'MultiLineString') {
        feature.geometry.coordinates.forEach(appendSegment)
      }
    }

    const routeCoordinates = routeSegments.flat()
    if (routeCoordinates.length < 2)
      throw new Error('La trace GPX ne contient pas assez de points.')

    trackLayer?.remove()
    trackLayer = L.featureGroup(
      routeSegments.map((points) =>
        L.polyline(points, { color: '#dc2626', weight: 5, opacity: 0.9 }),
      ),
    ).addTo(map)

    const start = routeCoordinates[0]
    const end = routeCoordinates[routeCoordinates.length - 1]
    if (!start || !end) throw new Error('La trace GPX ne contient pas assez de points.')
    const isLoop = map.distance(start, end) <= 75

    L.marker(start, { icon: createFlagIcon(isLoop ? 'Départ / arrivée' : 'Départ') }).addTo(
      trackLayer,
    )
    if (!isLoop) L.marker(end, { icon: createFlagIcon('Arrivée') }).addTo(trackLayer)

    map.fitBounds(trackLayer.getBounds(), { padding: [32, 32] })
  } catch (error) {
    if (error instanceof DOMException && error.name === 'AbortError') return
    errorMessage.value = error instanceof Error ? error.message : 'Impossible de lire la trace GPX.'
  } finally {
    isLoading.value = false
  }
}

onMounted(() => {
  if (!mapContainer.value) return

  map = L.map(mapContainer.value, { scrollWheelZoom: false }).setView([46.67, -1.43], 11)
  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    attribution: '&copy; OpenStreetMap contributors',
    maxZoom: 19,
  }).addTo(map)
  void loadTrack()
})

watch(
  () => props.fileUrl,
  () => void loadTrack(),
)

onBeforeUnmount(() => {
  requestController?.abort()
  map?.remove()
  map = null
})
</script>

<template>
  <div class="relative mb-6 overflow-hidden rounded-3xl border border-gray-200 bg-gray-100">
    <div ref="mapContainer" class="ride-gpx-map" />
    <p
      v-if="isLoading"
      class="absolute inset-x-3 top-3 rounded-lg bg-white/95 px-3 py-2 text-sm text-gray-700 shadow-sm"
    >
      Chargement de la trace...
    </p>
    <p
      v-if="errorMessage"
      role="alert"
      class="absolute inset-x-3 bottom-3 rounded-lg bg-white/95 px-3 py-2 text-sm text-red-700 shadow-sm"
    >
      {{ errorMessage }}
    </p>
  </div>
</template>

<style>
.ride-gpx-map {
  height: min(65vh, 460px);
  min-height: 280px;
  width: 100%;
}

.ride-gpx-flag-icon {
  background: transparent;
  border: 0;
}

.ride-gpx-flag {
  align-items: center;
  background: white;
  border: 1px solid #e5e7eb;
  border-radius: 9999px;
  box-shadow: 0 1px 4px rgb(0 0 0 / 18%);
  color: #111827;
  display: inline-flex;
  font: 600 12px/1.2 sans-serif;
  gap: 5px;
  padding: 6px 9px;
  white-space: nowrap;
}
</style>
