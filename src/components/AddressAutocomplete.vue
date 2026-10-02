<script setup lang="ts">
import { ref, watch } from 'vue'

interface AddressSuggestion {
  place_id?: string
  formatted: string
}

interface GeoapifyResponse {
  results?: AddressSuggestion[]
  features?: Array<{
    properties?: AddressSuggestion
  }>
}

const props = withDefaults(
  defineProps<{
    id: string
    label: string
    modelValue: string
    placeholder?: string
    required?: boolean
  }>(),
  { placeholder: 'Saisis une adresse ou une ville', required: false },
)

const emit = defineEmits<{
  'update:modelValue': [value: string]
}>()

const inputValue = ref(props.modelValue)
const selectedAddress = ref(props.modelValue)
const suggestions = ref<AddressSuggestion[]>([])
const isLoading = ref(false)
const requestError = ref('')
const isOpen = ref(false)
const apiKey = import.meta.env.VITE_GEOAPIFY_API_KEY

watch(
  () => props.modelValue,
  (value) => {
    selectedAddress.value = value
    inputValue.value = value
  },
)

watch(inputValue, (value, _previousValue, onCleanup) => {
  if (value === selectedAddress.value) return

  selectedAddress.value = ''
  emit('update:modelValue', '')
  suggestions.value = []
  requestError.value = ''
  isOpen.value = false

  const query = value.trim()
  if (query.length < 3) {
    isLoading.value = false
    return
  }

  if (!apiKey) {
    requestError.value = 'Configure VITE_GEOAPIFY_API_KEY pour rechercher une adresse.'
    return
  }

  const controller = new AbortController()
  const timer = setTimeout(async () => {
    isLoading.value = true

    try {
      const url = new URL('https://api.geoapify.com/v1/geocode/autocomplete')
      url.searchParams.set('text', query)
      url.searchParams.set('apiKey', apiKey)
      url.searchParams.set('lang', 'fr')
      url.searchParams.set('limit', '5')
      url.searchParams.set('filter', 'countrycode:fr')

      const response = await fetch(url, { signal: controller.signal })
      if (!response.ok) throw new Error('La recherche d’adresse est indisponible.')

      const data = (await response.json()) as GeoapifyResponse
      const results =
        data.results ?? data.features?.map((feature) => feature.properties).filter(Boolean) ?? []
      suggestions.value = results.filter((result): result is AddressSuggestion =>
        Boolean(result?.formatted),
      )
      isOpen.value = suggestions.value.length > 0
    } catch (error) {
      if (!controller.signal.aborted) {
        requestError.value =
          error instanceof Error ? error.message : 'Impossible de rechercher cette adresse.'
      }
    } finally {
      if (!controller.signal.aborted) isLoading.value = false
    }
  }, 300)

  onCleanup(() => {
    clearTimeout(timer)
    controller.abort()
  })
})

const selectSuggestion = (suggestion: AddressSuggestion) => {
  selectedAddress.value = suggestion.formatted
  inputValue.value = suggestion.formatted
  suggestions.value = []
  isOpen.value = false
  requestError.value = ''
  emit('update:modelValue', suggestion.formatted)
}
</script>

<template>
  <div class="relative">
    <label :for="id" class="block text-sm font-semibold text-gray-700">
      {{ label }}
    </label>
    <input
      :id="id"
      v-model="inputValue"
      type="search"
      :required="required"
      :placeholder="placeholder"
      autocomplete="off"
      role="combobox"
      aria-autocomplete="list"
      :aria-expanded="isOpen"
      :aria-controls="`${id}-suggestions`"
      class="mt-1 w-full rounded-xl border border-gray-200 bg-white px-4 py-3 outline-none focus:ring-2 focus:ring-red-500"
      @focus="isOpen = suggestions.length > 0"
    />

    <ul
      v-if="isOpen && suggestions.length"
      :id="`${id}-suggestions`"
      role="listbox"
      class="absolute inset-x-0 top-full z-50 mt-1 overflow-hidden rounded-xl border border-gray-200 bg-white shadow-xl"
    >
      <li v-for="(suggestion, index) in suggestions" :key="suggestion.place_id ?? index">
        <button
          type="button"
          role="option"
          :aria-selected="false"
          class="w-full px-4 py-3 text-left text-sm text-gray-800 hover:bg-gray-100 focus:bg-gray-100 focus:outline-none"
          @mousedown.prevent="selectSuggestion(suggestion)"
        >
          {{ suggestion.formatted }}
        </button>
      </li>
    </ul>

    <p v-if="isLoading" role="status" class="mt-1 text-xs text-gray-500">Recherche d’adresses...</p>
    <p v-if="requestError" role="alert" class="mt-1 text-xs text-red-700">
      {{ requestError }}
    </p>
    <p
      v-else-if="
        inputValue.trim().length >= 3 && !isLoading && !suggestions.length && !selectedAddress
      "
      class="mt-1 text-xs text-gray-500"
    >
      Sélectionne une adresse proposée pour continuer.
    </p>
  </div>
</template>
