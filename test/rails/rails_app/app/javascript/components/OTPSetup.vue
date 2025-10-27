<template>
  <Card>
    <template #header>
      <h2 class="text-lg font-semibold text-gray-900 dark:text-white">
        Set Up Two-Factor Authentication
      </h2>
    </template>

    <!-- Loading State -->
    <div v-if="loading" class="flex flex-col items-center justify-center py-8">
      <LoadingSpinner size="lg" />
      <p class="mt-4 text-sm text-gray-600 dark:text-gray-400">
        Generating your authenticator setup...
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
      <div class="mt-4">
        <Button variant="secondary" @click="initSetup">
          Try again
        </Button>
      </div>
    </div>

    <!-- Success: Recovery Codes Display -->
    <div v-else-if="setupComplete && recoveryCodes.length > 0" class="space-y-4">
      <div class="rounded-md bg-success-50 p-4 dark:bg-success-900/20">
        <div class="flex">
          <div class="flex-shrink-0">
            <svg class="h-5 w-5 text-success-400" viewBox="0 0 20 20" fill="currentColor">
              <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
            </svg>
          </div>
          <div class="ml-3">
            <h3 class="text-sm font-medium text-success-800 dark:text-success-200">
              Two-factor authentication enabled
            </h3>
            <p class="mt-2 text-sm text-success-700 dark:text-success-300">
              Save these recovery codes in a safe place. You can use them to access your account if you lose your authenticator device.
            </p>
          </div>
        </div>
      </div>

      <div class="rounded-lg border border-gray-300 bg-gray-50 p-4 dark:border-gray-600 dark:bg-gray-800">
        <div class="mb-3 flex items-center justify-between">
          <h4 class="text-sm font-medium text-gray-900 dark:text-white">
            Recovery Codes
          </h4>
          <Button
            variant="ghost"
            size="sm"
            @click="copyRecoveryCodes"
          >
            {{ copied ? 'Copied!' : 'Copy all' }}
          </Button>
        </div>
        <div class="grid grid-cols-2 gap-2">
          <code
            v-for="(code, index) in recoveryCodes"
            :key="index"
            class="block rounded bg-white px-3 py-2 text-center font-mono text-sm text-gray-900 dark:bg-gray-700 dark:text-white"
          >
            {{ code }}
          </code>
        </div>
      </div>

      <div class="rounded-md bg-yellow-50 p-4 dark:bg-yellow-900/20">
        <div class="flex">
          <div class="flex-shrink-0">
            <svg class="h-5 w-5 text-yellow-400" viewBox="0 0 20 20" fill="currentColor">
              <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
            </svg>
          </div>
          <div class="ml-3">
            <p class="text-sm text-yellow-800 dark:text-yellow-200">
              Each recovery code can only be used once. Make sure to save them securely.
            </p>
          </div>
        </div>
      </div>

      <div class="flex justify-end">
        <Button variant="primary" @click="handleComplete">
          Done
        </Button>
      </div>
    </div>

    <!-- Setup: QR Code & Verification -->
    <div v-else-if="otpData" class="space-y-6">
      <!-- Step 1: Scan QR Code -->
      <div class="space-y-3">
        <div class="flex items-center">
          <div class="flex h-8 w-8 flex-shrink-0 items-center justify-center rounded-full bg-primary-100 dark:bg-primary-900/20">
            <span class="text-sm font-medium text-primary-600 dark:text-primary-400">1</span>
          </div>
          <h3 class="ml-3 text-sm font-medium text-gray-900 dark:text-white">
            Scan QR code with your authenticator app
          </h3>
        </div>

        <div class="ml-11">
          <p class="mb-4 text-sm text-gray-600 dark:text-gray-400">
            Use an authenticator app like Google Authenticator, Authy, or 1Password to scan this QR code.
          </p>
          <div class="flex justify-center rounded-lg border-2 border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-800">
            <div v-html="otpData.qr_code" class="inline-block" />
          </div>
        </div>
      </div>

      <!-- Step 2: Manual Entry (Alternative) -->
      <div class="space-y-3">
        <div class="flex items-center">
          <div class="flex h-8 w-8 flex-shrink-0 items-center justify-center rounded-full bg-primary-100 dark:bg-primary-900/20">
            <span class="text-sm font-medium text-primary-600 dark:text-primary-400">2</span>
          </div>
          <h3 class="ml-3 text-sm font-medium text-gray-900 dark:text-white">
            Or enter this code manually
          </h3>
        </div>

        <div class="ml-11">
          <div class="flex items-center space-x-2">
            <code class="flex-1 rounded-md bg-gray-100 px-3 py-2 font-mono text-sm text-gray-900 dark:bg-gray-700 dark:text-white">
              {{ otpData.secret }}
            </code>
            <Button
              variant="ghost"
              size="sm"
              @click="copySecret"
            >
              {{ secretCopied ? 'Copied!' : 'Copy' }}
            </Button>
          </div>
        </div>
      </div>

      <!-- Step 3: Verify -->
      <div class="space-y-3">
        <div class="flex items-center">
          <div class="flex h-8 w-8 flex-shrink-0 items-center justify-center rounded-full bg-primary-100 dark:bg-primary-900/20">
            <span class="text-sm font-medium text-primary-600 dark:text-primary-400">3</span>
          </div>
          <h3 class="ml-3 text-sm font-medium text-gray-900 dark:text-white">
            Verify your authenticator
          </h3>
        </div>

        <form class="ml-11 space-y-4" @submit="verifyOtp">
          <FormField
            id="otp-code"
            label="Enter the 6-digit code from your authenticator app"
            :errors="verifyErrors.otp_code"
            :required="true"
          >
            <template #default="{ id, errorState }">
              <input
                :id="id"
                v-model="otpCode"
                type="text"
                inputmode="numeric"
                pattern="[0-9]{6}"
                maxlength="6"
                placeholder="000000"
                required
                :aria-invalid="errorState"
                :aria-describedby="errorState ? `${id}-error` : undefined"
                class="block w-full rounded-md border-gray-300 font-mono text-lg tracking-widest shadow-sm focus:border-primary-500 focus:ring-primary-500 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
                :class="{ 'border-danger-500 focus:border-danger-500 focus:ring-danger-500': errorState }"
              />
            </template>
          </FormField>

          <div v-if="verifyError" class="rounded-md bg-danger-50 p-4 dark:bg-danger-900/20">
            <p class="text-sm text-danger-800 dark:text-danger-200">
              {{ verifyError }}
            </p>
          </div>

          <div class="flex justify-end space-x-3">
            <Button
              type="button"
              variant="secondary"
              @click="handleCancel"
            >
              Cancel
            </Button>
            <Button
              type="submit"
              variant="primary"
              :loading="verifying"
              :disabled="otpCode.length !== 6 || verifying"
            >
              {{ verifying ? 'Verifying...' : 'Verify and enable' }}
            </Button>
          </div>
        </form>
      </div>
    </div>
  </Card>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { otpApi } from '@utils/api'
import { useClipboard } from '@composables/useClipboard'
import type { OTPSetupResponse } from '@types/index'
import Card from './shared/Card.vue'
import Button from './shared/Button.vue'
import FormField from './shared/FormField.vue'
import LoadingSpinner from './shared/LoadingSpinner.vue'

interface Props {
  autoInit?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  autoInit: true,
})

const emit = defineEmits<{
  success: []
  cancel: []
}>()

// Setup state
const loading = ref(false)
const error = ref<Error | null>(null)
const otpData = ref<OTPSetupResponse | null>(null)

// Verification state
const otpCode = ref('')
const verifying = ref(false)
const verifyError = ref<string | null>(null)
const verifyErrors = ref<Record<string, string[]>>({})

// Completion state
const setupComplete = ref(false)
const recoveryCodes = ref<string[]>([])

// Clipboard
const { copied, copy } = useClipboard()
const { copied: secretCopied, copy: copySecretFn } = useClipboard()

async function initSetup() {
  loading.value = true
  error.value = null

  try {
    const response = await otpApi.setup()

    if (response.error) {
      throw new Error(response.error)
    }

    otpData.value = response.data as OTPSetupResponse
  } catch (err) {
    error.value = err instanceof Error ? err : new Error('Failed to initialize OTP setup')
  } finally {
    loading.value = false
  }
}

async function verifyOtp(event: Event) {
  event.preventDefault()

  verifying.value = true
  verifyError.value = null
  verifyErrors.value = {}

  try {
    const response = await otpApi.confirm(otpCode.value)

    if (response.error) {
      verifyError.value = response.error
      verifyErrors.value = { otp_code: [response.error] }
      return
    }

    // Setup successful, show recovery codes
    if (response.data && 'recovery_codes' in response.data) {
      recoveryCodes.value = response.data.recovery_codes || []
      setupComplete.value = true
    }
  } catch (err) {
    verifyError.value = err instanceof Error ? err.message : 'Verification failed'
  } finally {
    verifying.value = false
  }
}

function copySecret() {
  if (otpData.value) {
    copySecretFn(otpData.value.secret)
  }
}

function copyRecoveryCodes() {
  copy(recoveryCodes.value.join('\n'))
}

function handleCancel() {
  emit('cancel')
}

function handleComplete() {
  emit('success')
}

onMounted(() => {
  if (props.autoInit) {
    initSetup()
  }
})

// Expose for external control
defineExpose({
  initSetup,
})
</script>
