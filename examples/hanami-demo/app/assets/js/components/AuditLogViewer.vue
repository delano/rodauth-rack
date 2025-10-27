<template>
  <Card>
    <template #header>
      <div class="flex items-center justify-between">
        <h2 class="text-lg font-semibold text-gray-900 dark:text-white">
          Security Activity
        </h2>
        <Button
          variant="ghost"
          size="sm"
          :disabled="loading"
          @click="refresh"
        >
          <svg class="h-4 w-4" :class="{ 'animate-spin': loading }" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
          </svg>
          <span class="ml-1">Refresh</span>
        </Button>
      </div>
    </template>

    <!-- Loading State -->
    <div v-if="loading && logs.length === 0" class="flex flex-col items-center justify-center py-12">
      <LoadingSpinner size="lg" />
      <p class="mt-4 text-sm text-gray-600 dark:text-gray-400">
        Loading activity logs...
      </p>
    </div>

    <!-- Error State -->
    <div v-else-if="error" class="rounded-md bg-danger-50 p-4 dark:bg-danger-900/20">
      <div class="flex">
        <div class="flex-shrink-0">
          <svg class="h-5 w-5 text-danger-400" viewBox="0 0 20 20" fill="currentColor">
            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
          </svg>
        </div>
        <div class="ml-3">
          <p class="text-sm text-danger-800 dark:text-danger-200">
            {{ error.message }}
          </p>
        </div>
      </div>
    </div>

    <!-- Empty State -->
    <div v-else-if="logs.length === 0" class="text-center py-12">
      <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
      </svg>
      <h3 class="mt-2 text-sm font-medium text-gray-900 dark:text-white">
        No activity yet
      </h3>
      <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">
        Your security activity will appear here.
      </p>
    </div>

    <!-- Audit Logs List -->
    <div v-else class="space-y-4">
      <!-- Filters (optional) -->
      <div v-if="showFilters" class="flex flex-wrap gap-2">
        <input
          v-model="filters.action"
          type="text"
          placeholder="Filter by action..."
          class="rounded-md border-gray-300 text-sm shadow-sm focus:border-primary-500 focus:ring-primary-500 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
        />
        <select
          v-model="filters.sort_order"
          class="rounded-md border-gray-300 text-sm shadow-sm focus:border-primary-500 focus:ring-primary-500 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
          @change="applyFilters"
        >
          <option value="desc">Newest first</option>
          <option value="asc">Oldest first</option>
        </select>
      </div>

      <!-- Log entries -->
      <div class="space-y-3">
        <div
          v-for="log in logs"
          :key="log.id"
          class="rounded-lg border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800"
        >
          <div class="flex items-start justify-between">
            <div class="flex-1">
              <div class="flex items-center gap-2">
                <span class="font-medium text-gray-900 dark:text-white">
                  {{ formatActionLabel(log.message) }}
                </span>
                <span
                  class="inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium"
                  :class="getActionBadgeClass(log.message)"
                >
                  {{ getActionType(log.message) }}
                </span>
              </div>
              <p class="mt-1 text-sm text-gray-600 dark:text-gray-400">
                {{ formatRelativeTime(log.timestamp) }}
              </p>
            </div>
            <button
              type="button"
              class="ml-4 text-gray-400 hover:text-gray-500 dark:hover:text-gray-300"
              @click="toggleExpanded(log.id)"
            >
              <svg
                class="h-5 w-5 transition-transform"
                :class="{ 'rotate-180': expandedLogs.has(log.id) }"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
              </svg>
            </button>
          </div>

          <!-- Expanded Details -->
          <Transition
            enter-active-class="transition-all duration-200 ease-out"
            enter-from-class="opacity-0 max-h-0"
            enter-to-class="opacity-100 max-h-96"
            leave-active-class="transition-all duration-200 ease-in"
            leave-from-class="opacity-100 max-h-96"
            leave-to-class="opacity-0 max-h-0"
          >
            <div v-if="expandedLogs.has(log.id)" class="mt-4 space-y-2 border-t border-gray-200 pt-4 dark:border-gray-700">
              <div class="grid grid-cols-2 gap-2 text-sm">
                <div>
                  <span class="text-gray-500 dark:text-gray-400">Timestamp:</span>
                  <span class="ml-2 text-gray-900 dark:text-white">{{ formatDate(log.timestamp) }}</span>
                </div>
                <div v-if="log.ip_address">
                  <span class="text-gray-500 dark:text-gray-400">IP Address:</span>
                  <span class="ml-2 font-mono text-gray-900 dark:text-white">{{ log.ip_address }}</span>
                </div>
                <div v-if="log.request_method && log.request_path" class="col-span-2">
                  <span class="text-gray-500 dark:text-gray-400">Request:</span>
                  <span class="ml-2 font-mono text-gray-900 dark:text-white">
                    {{ log.request_method }} {{ log.request_path }}
                  </span>
                </div>
                <div v-if="log.user_agent" class="col-span-2">
                  <span class="text-gray-500 dark:text-gray-400">User Agent:</span>
                  <p class="mt-1 font-mono text-xs text-gray-900 dark:text-white">
                    {{ truncate(log.user_agent, 100) }}
                  </p>
                </div>
              </div>

              <!-- Additional Metadata -->
              <details v-if="log.metadata && Object.keys(log.metadata).length > 0" class="mt-2">
                <summary class="cursor-pointer text-sm text-primary-600 hover:text-primary-500 dark:text-primary-400">
                  Show metadata
                </summary>
                <pre class="mt-2 overflow-x-auto rounded bg-gray-100 p-2 text-xs text-gray-900 dark:bg-gray-900 dark:text-white">{{ JSON.stringify(log.metadata, null, 2) }}</pre>
              </details>
            </div>
          </Transition>
        </div>
      </div>

      <!-- Pagination -->
      <div v-if="meta" class="flex items-center justify-between border-t border-gray-200 pt-4 dark:border-gray-700">
        <div class="text-sm text-gray-700 dark:text-gray-300">
          Showing {{ ((meta.page - 1) * meta.per_page) + 1 }} to {{ Math.min(meta.page * meta.per_page, meta.total_count) }} of {{ meta.total_count }} entries
        </div>
        <div class="flex gap-2">
          <Button
            variant="secondary"
            size="sm"
            :disabled="meta.page <= 1 || loading"
            @click="goToPage(meta.page - 1)"
          >
            Previous
          </Button>
          <Button
            variant="secondary"
            size="sm"
            :disabled="meta.page >= meta.total_pages || loading"
            @click="goToPage(meta.page + 1)"
          >
            Next
          </Button>
        </div>
      </div>
    </div>
  </Card>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted, watch } from 'vue'
import { auditLogsApi } from '@utils/api'
import { formatDate, formatRelativeTime, formatActionLabel, truncate } from '@utils/format'
import type { AuditLog, AuditLogsParams } from '@types/index'
import Card from './shared/Card.vue'
import Button from './shared/Button.vue'
import LoadingSpinner from './shared/LoadingSpinner.vue'

interface Props {
  perPage?: number
  showFilters?: boolean
  autoLoad?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  perPage: 25,
  showFilters: false,
  autoLoad: true,
})

const emit = defineEmits<{
  loaded: [logs: AuditLog[]]
  error: [error: Error]
}>()

// State
const logs = ref<AuditLog[]>([])
const meta = ref<any>(null)
const loading = ref(false)
const error = ref<Error | null>(null)
const expandedLogs = ref(new Set<number>())

// Filters
const filters = reactive<AuditLogsParams>({
  page: 1,
  per_page: props.perPage,
  sort_order: 'desc',
  action: '',
})

async function loadLogs() {
  loading.value = true
  error.value = null

  try {
    const response = await auditLogsApi.list(filters)

    if (response.error) {
      throw new Error(response.error)
    }

    if (response.data) {
      logs.value = response.data.data
      meta.value = response.data.meta
      emit('loaded', logs.value)
    }
  } catch (err) {
    error.value = err instanceof Error ? err : new Error('Failed to load audit logs')
    emit('error', error.value)
  } finally {
    loading.value = false
  }
}

function toggleExpanded(logId: number) {
  if (expandedLogs.value.has(logId)) {
    expandedLogs.value.delete(logId)
  } else {
    expandedLogs.value.add(logId)
  }
}

function goToPage(page: number) {
  filters.page = page
  loadLogs()
}

function applyFilters() {
  filters.page = 1 // Reset to first page when filters change
  loadLogs()
}

function refresh() {
  loadLogs()
}

function getActionType(message: string): string {
  if (message.includes('login') || message.includes('sign in')) return 'Auth'
  if (message.includes('logout') || message.includes('sign out')) return 'Auth'
  if (message.includes('password')) return 'Security'
  if (message.includes('otp') || message.includes('two-factor')) return 'MFA'
  if (message.includes('account')) return 'Account'
  return 'Activity'
}

function getActionBadgeClass(message: string): string {
  const type = getActionType(message)
  const classes = {
    'Auth': 'bg-primary-100 text-primary-800 dark:bg-primary-900/20 dark:text-primary-400',
    'Security': 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900/20 dark:text-yellow-400',
    'MFA': 'bg-purple-100 text-purple-800 dark:bg-purple-900/20 dark:text-purple-400',
    'Account': 'bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-400',
    'Activity': 'bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-400',
  }
  return classes[type as keyof typeof classes] || classes.Activity
}

// Watch filters for changes
watch(() => filters.action, () => {
  applyFilters()
})

onMounted(() => {
  if (props.autoLoad) {
    loadLogs()
  }
})

// Expose for external control
defineExpose({
  loadLogs,
  refresh,
})
</script>
