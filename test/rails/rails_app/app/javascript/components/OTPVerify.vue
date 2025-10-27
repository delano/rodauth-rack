<template>
  <Card>
    <template #header>
      <h2 class="text-lg font-semibold text-gray-900 dark:text-white">
        Two-Factor Authentication
      </h2>
    </template>

    <div class="space-y-4">
      <p class="text-sm text-gray-600 dark:text-gray-400">
        Enter the 6-digit code from your authenticator app to continue.
      </p>

      <form @submit="handleSubmit">
        <div class="space-y-4">
          <!-- OTP Code Input (default) -->
          <div v-if="!useRecoveryCode">
            <FormField
              id="otp-code"
              label="Authentication code"
              :errors="errors.otp_code"
              :required="true"
            >
              <template #default="{ id, errorState }">
                <input
                  :id="id"
                  ref="otpInput"
                  v-model="values.otp_code"
                  type="text"
                  inputmode="numeric"
                  pattern="[0-9]{6}"
                  maxlength="6"
                  placeholder="000000"
                  required
                  autofocus
                  :aria-invalid="errorState"
                  :aria-describedby="errorState ? `${id}-error` : undefined"
                  class="block w-full rounded-md border-gray-300 font-mono text-lg tracking-widest shadow-sm focus:border-primary-500 focus:ring-primary-500 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
                  :class="{ 'border-danger-500 focus:border-danger-500 focus:ring-danger-500': errorState }"
                />
              </template>
            </FormField>

            <!-- Countdown timer (optional) -->
            <div v-if="showTimer && timeRemaining > 0" class="mt-2 text-xs text-gray-500 dark:text-gray-400">
              Code refreshes in {{ timeRemaining }}s
            </div>
          </div>

          <!-- Recovery Code Input (alternative) -->
          <div v-else>
            <FormField
              id="recovery-code"
              label="Recovery code"
              :errors="errors.recovery_code"
              hint="Enter one of your 16-character recovery codes"
              :required="true"
            >
              <template #default="{ id, errorState }">
                <input
                  :id="id"
                  ref="recoveryInput"
                  v-model="values.recovery_code"
                  type="text"
                  maxlength="16"
                  placeholder="xxxxxxxxxxxxxxxx"
                  required
                  autofocus
                  :aria-invalid="errorState"
                  :aria-describedby="errorState ? `${id}-error` : `${id}-hint`"
                  class="block w-full rounded-md border-gray-300 font-mono shadow-sm focus:border-primary-500 focus:ring-primary-500 dark:border-gray-600 dark:bg-gray-700 dark:text-white sm:text-sm"
                  :class="{ 'border-danger-500 focus:border-danger-500 focus:ring-danger-500': errorState }"
                />
              </template>
            </FormField>
          </div>

          <!-- Toggle between OTP and Recovery Code -->
          <div class="flex justify-center">
            <button
              type="button"
              class="text-sm text-primary-600 hover:text-primary-500 dark:text-primary-400"
              @click="toggleRecoveryMode"
            >
              {{ useRecoveryCode ? 'Use authenticator code instead' : 'Use recovery code instead' }}
            </button>
          </div>

          <!-- Error Display -->
          <div v-if="state.error" class="rounded-md bg-danger-50 p-4 dark:bg-danger-900/20">
            <div class="flex">
              <div class="flex-shrink-0">
                <svg class="h-5 w-5 text-danger-400" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
                </svg>
              </div>
              <div class="ml-3">
                <h3 class="text-sm font-medium text-danger-800 dark:text-danger-200">
                  {{ state.error }}
                </h3>
                <p v-if="attemptsRemaining !== null && attemptsRemaining > 0" class="mt-2 text-sm text-danger-700 dark:text-danger-300">
                  {{ attemptsRemaining }} {{ attemptsRemaining === 1 ? 'attempt' : 'attempts' }} remaining
                </p>
              </div>
            </div>
          </div>
        </div>

        <!-- Submit Button -->
        <div class="mt-6">
          <Button
            type="submit"
            variant="primary"
            size="md"
            :loading="state.isSubmitting"
            :disabled="!isValid || state.isSubmitting"
            full-width
          >
            {{ state.isSubmitting ? 'Verifying...' : 'Verify' }}
          </Button>
        </div>

        <!-- Footer Links -->
        <div class="mt-4 text-center">
          <slot name="footer">
            <a
              href="/logout"
              class="text-sm text-gray-600 hover:text-gray-500 dark:text-gray-400"
            >
              Sign out
            </a>
          </slot>
        </div>
      </form>
    </div>
  </Card>
</template>

<script setup lang="ts">
import { ref, computed, nextTick, onMounted, onBeforeUnmount } from 'vue'
import { otpApi } from '@utils/api'
import { useForm } from '@composables/useForm'
import { otpRules, recoveryCodeRules } from '@utils/validation'
import Card from './shared/Card.vue'
import Button from './shared/Button.vue'
import FormField from './shared/FormField.vue'

interface Props {
  showTimer?: boolean
  onSuccess?: (method: 'otp' | 'recovery') => void
  redirectUrl?: string
}

const props = withDefaults(defineProps<Props>(), {
  showTimer: true,
})

const emit = defineEmits<{
  success: [method: 'otp' | 'recovery']
}>()

// Mode toggle
const useRecoveryCode = ref(false)
const attemptsRemaining = ref<number | null>(null)

// Timer for TOTP codes
const timeRemaining = ref(30)
let timerInterval: number | undefined

// Refs for autofocus
const otpInput = ref<HTMLInputElement>()
const recoveryInput = ref<HTMLInputElement>()

// Form
const { values, state, errors, handleSubmit } = useForm({
  initialValues: {
    otp_code: '',
    recovery_code: '',
  },
  validationRules: computed(() => {
    if (useRecoveryCode.value) {
      return { recovery_code: recoveryCodeRules }
    }
    return { otp_code: otpRules }
  }),
  onSubmit: async (formValues) => {
    const response = await otpApi.verify(
      useRecoveryCode.value ? undefined : formValues.otp_code,
      useRecoveryCode.value ? formValues.recovery_code : undefined
    )

    if (response.error) {
      // Parse attempts remaining from error message if available
      const match = response.error.match(/(\d+) attempts? remaining/i)
      if (match) {
        attemptsRemaining.value = parseInt(match[1], 10)
      }
      throw new Error(response.error)
    }

    const method = useRecoveryCode.value ? 'recovery' : 'otp'
    emit('success', method)
    props.onSuccess?.(method)

    // Redirect if URL provided
    if (props.redirectUrl) {
      window.location.href = props.redirectUrl
    }
  },
})

const isValid = computed(() => {
  if (useRecoveryCode.value) {
    return values.recovery_code.length === 16
  }
  return values.otp_code.length === 6
})

async function toggleRecoveryMode() {
  useRecoveryCode.value = !useRecoveryCode.value

  // Clear values and errors
  values.otp_code = ''
  values.recovery_code = ''
  errors.value = {}
  state.error = null
  attemptsRemaining.value = null

  // Focus the new input
  await nextTick()
  if (useRecoveryCode.value) {
    recoveryInput.value?.focus()
  } else {
    otpInput.value?.focus()
  }
}

function startTimer() {
  if (!props.showTimer) return

  // Calculate initial time remaining based on current time
  const now = Math.floor(Date.now() / 1000)
  timeRemaining.value = 30 - (now % 30)

  timerInterval = window.setInterval(() => {
    timeRemaining.value--
    if (timeRemaining.value <= 0) {
      timeRemaining.value = 30
    }
  }, 1000)
}

function stopTimer() {
  if (timerInterval) {
    clearInterval(timerInterval)
    timerInterval = undefined
  }
}

onMounted(() => {
  startTimer()
})

onBeforeUnmount(() => {
  stopTimer()
})
</script>
