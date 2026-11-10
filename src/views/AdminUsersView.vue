<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { Search, ShieldCheck, ShieldOff, Users } from 'lucide-vue-next'
import { getSupabaseClient } from '../supabase.ts'
import { useAuth } from '../composables/useAuth'

interface UserAccount {
  id: string
  firstname: string
  lastname: string
  level: string | null
  created_at: string
  email: string
  role: 'rvc' | 'maison_du_velo' | 'admin'
  phone: string | null
  gender: 'Féminin' | 'Masculin' | null
  is_active: boolean
}

const users = ref<UserAccount[]>([])
const searchQuery = ref('')
const isLoading = ref(true)
const loadingUserId = ref<string | null>(null)
const errorMessage = ref('')
const { user: authUser } = useAuth()

const filteredUsers = computed(() => {
  const query = searchQuery.value.trim().toLocaleLowerCase()
  if (!query) return users.value

  return users.value.filter((user) =>
    `${user.firstname} ${user.lastname} ${user.email}`.toLocaleLowerCase().includes(query),
  )
})

const loadUsers = async () => {
  isLoading.value = true
  errorMessage.value = ''

  try {
    const { data, error } = await getSupabaseClient()
      .from('users')
      .select('id, firstname, lastname, level, created_at, email, role, phone, gender, is_active')
      .order('created_at', { ascending: false })

    if (error) throw error
    users.value = data
  } catch (error) {
    errorMessage.value =
      error instanceof Error ? error.message : 'Impossible de charger les comptes.'
  } finally {
    isLoading.value = false
  }
}

const toggleUserStatus = async (user: UserAccount) => {
  loadingUserId.value = user.id
  errorMessage.value = ''

  try {
    const { error } = await getSupabaseClient().rpc('set_user_active', {
      p_user_id: user.id,
      p_is_active: !user.is_active,
    })

    if (error) throw error
    user.is_active = !user.is_active
  } catch (error) {
    errorMessage.value =
      error instanceof Error ? error.message : 'Impossible de modifier le statut du compte.'
  } finally {
    loadingUserId.value = null
  }
}

const formatCreatedAt = (value: string) =>
  new Intl.DateTimeFormat('fr-FR', { dateStyle: 'medium' }).format(new Date(value))

const roleLabel = (role: UserAccount['role']) =>
  role === 'admin' ? 'Administrateur' : role === 'rvc' ? 'Roche Vendée Cyclisme' : 'Maison du Vélo'

onMounted(() => void loadUsers())
</script>

<template>
  <div class="min-h-screen px-4 pb-28 pt-7 sm:px-6">
    <div class="mx-auto max-w-7xl">
      <header class="mb-6 flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <p class="mb-1 text-sm font-semibold uppercase tracking-wide text-emerald-400">
            Administration
          </p>
          <h1 class="text-2xl font-bold text-white sm:text-3xl">Gestion des comptes</h1>
          <p class="mt-1 text-sm text-gray-400">
            Consulte les profils et autorise ou bloque leur connexion.
          </p>
        </div>
        <div class="flex items-center gap-2 text-sm text-gray-300">
          <Users class="h-5 w-5" />
          {{ users.length }} compte{{ users.length === 1 ? '' : 's' }}
        </div>
      </header>

      <label class="relative mb-4 block max-w-md">
        <Search class="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-400" />
        <input
          v-model="searchQuery"
          type="search"
          placeholder="Rechercher par nom ou email"
          class="w-full rounded-xl border border-white/10 bg-white/5 py-3 pl-10 pr-4 text-sm text-white outline-none placeholder:text-gray-500 focus:ring-2 focus:ring-emerald-500"
        />
      </label>

      <p
        v-if="errorMessage"
        role="alert"
        class="mb-4 rounded-xl bg-red-950/60 p-3 text-sm text-red-200"
      >
        {{ errorMessage }}
      </p>
      <p v-if="isLoading" class="py-10 text-center text-sm text-gray-400">
        Chargement des comptes...
      </p>
      <p v-else-if="filteredUsers.length === 0" class="py-10 text-center text-sm text-gray-400">
        Aucun compte trouvé.
      </p>

      <div v-else class="overflow-x-auto rounded-2xl border border-white/10 bg-white/[0.04]">
        <table class="w-full min-w-[1050px] border-collapse text-left text-sm">
          <thead class="bg-white/[0.06] text-xs uppercase tracking-wide text-gray-400">
            <tr>
              <th class="px-4 py-3 font-semibold">Prénom et nom</th>
              <th class="px-4 py-3 font-semibold">Niveau</th>
              <th class="px-4 py-3 font-semibold">Créé le</th>
              <th class="px-4 py-3 font-semibold">Email</th>
              <th class="px-4 py-3 font-semibold">Rôle</th>
              <th class="px-4 py-3 font-semibold">Téléphone</th>
              <th class="px-4 py-3 font-semibold">Sexe</th>
              <th class="px-4 py-3 font-semibold">Compte</th>
              <th class="px-4 py-3 font-semibold">Action</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-white/10">
            <tr v-for="user in filteredUsers" :key="user.id" class="text-gray-200">
              <td class="px-4 py-4 font-semibold text-white">
                {{ user.firstname }} {{ user.lastname }}
              </td>
              <td class="px-4 py-4">{{ user.level || '—' }}</td>
              <td class="px-4 py-4">{{ formatCreatedAt(user.created_at) }}</td>
              <td class="px-4 py-4">{{ user.email }}</td>
              <td class="px-4 py-4">{{ roleLabel(user.role) }}</td>
              <td class="px-4 py-4">{{ user.phone || '—' }}</td>
              <td class="px-4 py-4">{{ user.gender || '—' }}</td>
              <td class="px-4 py-4">
                <span
                  class="inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-semibold"
                  :class="
                    user.is_active
                      ? 'bg-emerald-400/10 text-emerald-300'
                      : 'bg-red-400/10 text-red-300'
                  "
                >
                  <span
                    class="h-1.5 w-1.5 rounded-full"
                    :class="user.is_active ? 'bg-emerald-400' : 'bg-red-400'"
                  />
                  {{ user.is_active ? 'Actif' : 'Désactivé' }}
                </span>
              </td>
              <td class="px-4 py-4">
                <button
                  type="button"
                  :disabled="
                    loadingUserId === user.id || (authUser?.id === user.id && user.is_active)
                  "
                  :aria-label="`${user.is_active ? 'Désactiver' : 'Activer'} le compte de ${user.firstname} ${user.lastname}`"
                  :title="
                    authUser?.id === user.id && user.is_active
                      ? 'Vous ne pouvez pas désactiver votre propre compte.'
                      : undefined
                  "
                  class="inline-flex min-h-9 items-center gap-1.5 rounded-lg border px-3 text-xs font-semibold transition-colors disabled:cursor-wait disabled:opacity-50"
                  :class="
                    user.is_active
                      ? 'border-red-400/30 text-red-300 hover:bg-red-400/10'
                      : 'border-emerald-400/30 text-emerald-300 hover:bg-emerald-400/10'
                  "
                  @click="toggleUserStatus(user)"
                >
                  <span v-if="loadingUserId === user.id">Mise à jour...</span>
                  <template v-else>
                    <ShieldOff v-if="user.is_active" class="h-4 w-4" />
                    <ShieldCheck v-else class="h-4 w-4" />
                    {{ user.is_active ? 'Désactiver' : 'Activer' }}
                  </template>
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>
