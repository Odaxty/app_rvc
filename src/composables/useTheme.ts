import { readonly, ref, watch } from 'vue'

export type AppTheme = 'dark' | 'light'

const readSavedTheme = (): AppTheme => {
  try {
    return localStorage.getItem('rvc-theme') === 'light' ? 'light' : 'dark'
  } catch {
    return 'dark'
  }
}

const currentTheme = ref<AppTheme>(readSavedTheme())

watch(
  currentTheme,
  (theme) => {
    try {
      localStorage.setItem('rvc-theme', theme)
    } catch {
      return
    }
  },
  { flush: 'sync' },
)

export function useTheme() {
  const setTheme = (theme: AppTheme) => {
    currentTheme.value = theme
  }

  return { theme: readonly(currentTheme), setTheme }
}
