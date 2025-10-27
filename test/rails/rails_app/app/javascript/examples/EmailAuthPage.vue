<template>
  <div class="min-h-screen bg-gray-50 dark:bg-gray-900 py-12 px-4 sm:px-6 lg:px-8">
    <div class="mx-auto max-w-md">
      <div class="text-center mb-8">
        <h1 class="text-3xl font-bold text-gray-900 dark:text-white">
          Welcome back
        </h1>
        <p class="mt-2 text-sm text-gray-600 dark:text-gray-400">
          Sign in with a magic link sent to your email
        </p>
      </div>

      <EmailAuth
        :initial-email="email"
        @success="handleSuccess"
      >
        <template #footer>
          <div class="space-y-2">
            <a
              href="/login"
              class="block text-sm text-primary-600 hover:text-primary-500 dark:text-primary-400"
            >
              Back to sign in
            </a>
            <span class="text-gray-500">or</span>
            <a
              href="/signup"
              class="block text-sm text-primary-600 hover:text-primary-500 dark:text-primary-400"
            >
              Create an account
            </a>
          </div>
        </template>
      </EmailAuth>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import EmailAuth from '../components/EmailAuth.vue'
import { useToast } from '../composables/useToast'

const email = ref('')
const { success } = useToast()

function handleSuccess(userEmail: string) {
  success(`Sign-in link sent to ${userEmail}`)
}
</script>
