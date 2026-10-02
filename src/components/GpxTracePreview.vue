<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { gpx as parseGpx } from '@tmcw/togeojson'
import type { Position } from 'geojson'
import { Map } from 'lucide-vue-next'

const props = defineProps<{ fileUrl: string; title: string }>()

interface TracePath {
  points: string
  startX: number
  startY: number
  endX: number
  endY: number
  isLoop: boolean
}

const paths = ref<TracePath[]>([])
const isLoading = ref(true)
const hasError = ref(false)
let requestController: AbortController | null = null

const buildPaths = (segments: Position[][]): TracePath[] => {
  const validSegments = segments.filter((segment) => segment.length > 1)
  const coordinates = validSegments.flatMap((segment) => segment)
  if (!coordinates.length) return []

  const longitudes = coordinates.map((point) => point[0] ?? 0)
  const latitudes = coordinates.map((point) => point[1] ?? 0)
  const minLongitude = Math.min(...longitudes)
  const maxLongitude = Math.max(...longitudes)
  const minLatitude = Math.min(...latitudes)
  const maxLatitude = Math.max(...latitudes)
  const width = 320
  const height = 180
  const padding = 22
  const longitudeSpan = maxLongitude - minLongitude || 0.00001
  const latitudeSpan = maxLatitude - minLatitude || 0.00001
  const scale = Math.min(
    (width - padding * 2) / longitudeSpan,
    (height - padding * 2) / latitudeSpan,
  )
  const drawnWidth = longitudeSpan * scale
  const drawnHeight = latitudeSpan * scale
  const offsetX = (width - drawnWidth) / 2
  const offsetY = (height - drawnHeight) / 2

  const project = (point: Position) => {
    const longitude = point[0] ?? 0
    const latitude = point[1] ?? 0
    return {
      x: offsetX + (longitude - minLongitude) * scale,
      y: height - offsetY - (latitude - minLatitude) * scale,
    }
  }

  return validSegments.map((segment) => {
    const projected = segment.map(project)
    const start = projected[0]!
    const end = projected[projected.length - 1]!
    return {
      points: projected.map((point) => `${point.x.toFixed(1)},${point.y.toFixed(1)}`).join(' '),
      startX: start.x,
      startY: start.y,
      endX: end.x,
      endY: end.y,
      isLoop: Math.hypot(start.x - end.x, start.y - end.y) < 8,
    }
  })
}

const loadPreview = async () => {
  requestController?.abort()
  requestController = new AbortController()
  isLoading.value = true
  hasError.value = false

  try {
    const response = await fetch(props.fileUrl, { signal: requestController.signal })
    if (!response.ok) throw new Error('Could not load GPX preview')

    const xml = new DOMParser().parseFromString(await response.text(), 'application/xml')
    if (xml.querySelector('parsererror')) throw new Error('Invalid GPX file')

    const featureCollection = parseGpx(xml)
    const segments: Position[][] = []
    for (const feature of featureCollection.features) {
      if (feature.geometry.type === 'LineString') {
        segments.push(feature.geometry.coordinates)
      } else if (feature.geometry.type === 'MultiLineString') {
        segments.push(...feature.geometry.coordinates)
      }
    }

    paths.value = buildPaths(segments)
    if (!paths.value.length) throw new Error('No GPX route found')
  } catch (error) {
    if (error instanceof DOMException && error.name === 'AbortError') return
    hasError.value = true
    paths.value = []
  } finally {
    isLoading.value = false
  }
}

onMounted(() => void loadPreview())
watch(
  () => props.fileUrl,
  () => void loadPreview(),
)
onBeforeUnmount(() => requestController?.abort())
</script>

<template>
  <div
    class="relative flex aspect-video w-full items-center justify-center overflow-hidden bg-emerald-50"
    role="img"
    :aria-label="`Tracé GPX de ${title}`"
  >
    <svg v-if="paths.length" viewBox="0 0 320 180" class="h-full w-full" aria-hidden="true">
      <path d="M0 45H320M0 90H320M0 135H320M80 0V180M160 0V180M240 0V180" stroke="#d1fae5" />
      <g v-for="(path, index) in paths" :key="index">
        <polyline
          :points="path.points"
          fill="none"
          stroke="#dc2626"
          stroke-linecap="round"
          stroke-linejoin="round"
          stroke-width="4"
        />
        <circle
          :cx="path.startX"
          :cy="path.startY"
          r="5"
          fill="#16a34a"
          stroke="white"
          stroke-width="2"
        />
        <circle
          v-if="!path.isLoop"
          :cx="path.endX"
          :cy="path.endY"
          r="5"
          fill="#dc2626"
          stroke="white"
          stroke-width="2"
        />
      </g>
    </svg>
    <div v-else class="flex flex-col items-center gap-2 text-sm text-gray-500">
      <Map class="h-7 w-7" />
      <span>{{
        isLoading ? 'Chargement du tracé...' : hasError ? 'Tracé GPX indisponible' : 'Aucun tracé'
      }}</span>
    </div>
    <span
      class="absolute bottom-2 left-2 rounded-md bg-white/90 px-2 py-1 text-xs font-semibold text-gray-700"
    >
      Tracé GPX
    </span>
  </div>
</template>
