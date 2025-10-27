<template>
  <div class="min-h-screen bg-gray-50 dark:bg-gray-900 py-12 px-4 sm:px-6 lg:px-8">
    <div class="mx-auto max-w-4xl space-y-8">
      <!-- Page Header -->
      <div>
        <h1 class="text-3xl font-bold text-gray-900 dark:text-white">
          Security Settings
        </h1>
        <p class="mt-2 text-sm text-gray-600 dark:text-gray-400">
          Manage your security preferences and view account activity
        </p>
      </div>

      <!-- Two-Factor Authentication -->
      <section>
        <h2 class="text-xl font-semibold text-gray-900 dark:text-white mb-4">
          Two-Factor Authentication
        </h2>

        <div v-if="!otpEnabled">
          <div class="mb-4 rounded-md bg-yellow-50 p-4 dark:bg-yellow-900/20">
            <div class="flex">
              <div class="flex-shrink-0">
                <svg class="h-5 w-5 text-yellow-400" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
                </svg>
              </div>
              <div class="ml-3">
                <p class="text-sm text-yellow-800 dark:text-yellow-200">
                  Two-factor authentication is not enabled. Enable it to add an extra layer of security to your account.
                </p>
              </div>
            </div>
          </div>

          <Button
            variant="primary"
            @click="showOtpSetup = true"
          >
            Enable Two-Factor Authentication
          </Button>
        </div>

        <div v-else class="rounded-md bg-success-50 p-4 dark:bg-success-900/20">
          <div class="flex items-center justify-between">
            <div class="flex">
              <div class="flex-shrink-0">
                <svg class="h-5 w-5 text-success-400" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                </svg>
              </div>
              <div class="ml-3">
                <p class="text-sm text-success-800 dark:text-success-200">
                  Two-factor authentication is enabled and protecting your account.
                </p>
              </div>
            </div>
            <Button
              variant="danger"
              size="sm"
              @click="disableOtp"
            >
              Disable
            </Button>
          </div>
        </div>

        <!-- OTP Setup Modal -->
        <div v-if="showOtpSetup" class="fixed inset-0 z-50 overflow-y-auto">
          <div class="flex min-h-screen items-center justify-center px-4">
            <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity" @click="showOtpSetup = false" />
            <div class="relative max-w-lg">
              <OTPSetup
                @success="handleOtpSetupSuccess"
                @cancel="showOtpSetup = false"
              />
            </div>
          </div>
        </div>
      </section>

      <!-- Security Activity -->
      <section>
        <h2 class="text-xl font-semibold text-gray-900 dark:text-white mb-4">
          Recent Activity
        </h2>
        <AuditLogViewer
          :per-page="10"
          :show-filters="true"
          @loaded="handleLogsLoaded"
        />
      </section>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import OTPSetup from '../components/OTPSetup.vue'
import AuditLogViewer from '../components/AuditLogViewer.vue'
import Button from '../components/shared/Button.vue'
import { useToast } from '../composables/useToast'
import type { AuditLog } from '../types'

const otpEnabled = ref(false)
const showOtpSetup = ref(false)
const { success, error } = useToast()

function handleOtpSetupSuccess() {
  showOtpSetup.value = false
  otpEnabled.value = true
  success('Two-factor authentication has been enabled')
}

function disableOtp() {
  // Implementation would call the API to disable OTP
  if (confirm('Are you sure you want to disable two-factor authentication?')) {
    otpEnabled.value = false
    success('Two-factor authentication has been disabled')
  }
}

function handleLogsLoaded(logs: AuditLog[]) {
  console.log(`Loaded ${logs.length} audit logs`)
}
</script>
