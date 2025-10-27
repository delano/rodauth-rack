<template>
  <Card>
    <template #header>
      <h2 class="text-lg font-semibold text-gray-900 dark:text-white">
        Sign In with Email Link
      </h2>
    </template>

    <div v-if="state.success" class="text-center">
      <div class="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-success-100 dark:bg-success-900/20">
        <svg class="h-6 w-6 text-success-600 dark:text-success-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
        </svg>
      </div>
      <h3 class="mt-4 text-lg font-medium text-gray-900 dark:text-white">
        Check your email
      </h3>
      <p class="mt-2 text-sm text-gray-600 dark:text-gray-400">
        We've sent a sign-in link to <strong>{{ values.email }}</strong>
      </p>
      <p class="mt-2 text-sm text-gray-500 dark:text-gray-500">
        Click the link in the email to complete your sign-in. The link will expire in 2 hours.
      </p>
      <Button
        variant="ghost"
        size="sm"
        class="mt-4"
        @click="reset"
      >
        Send another link
      </Button>
    </div>

    <form v-else @submit="handleSubmit">
      <div class="space-y-4">
        <p class="text-sm text-gray-600 dark:text-gray-400">
          Enter your email address and we'll send you a secure sign-in link.
        </p>

        <FormField
          id="email"
          label="Email address"
          :errors="errors.email"
          :required="true"
        >
          <template #default="{ id, errorState }">
            <input
              :id="id"
              v-model="values.email"
              type="email"
              name="email"
              autocomplete="email"
              placeholder="you@example.com"
              required
              :aria-invalid="errorState"
              :aria-describedby="errorState ? `${id}-error` : undefined"
              class="block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500 dark:border-gray-600 dark:bg-gray-700 dark:text-white sm:text-sm"
              :class="{ 'border-danger-500 focus:border-danger-500 focus:ring-danger-500': errorState }"
            />
          </template>
        </FormField>

        <div v-if="state.error" class="rounded-md bg-danger-50 p-4 dark:bg-danger-900/20">
          <div class="flex">
            <div class="flex-shrink-0">
              <svg class="h-5 w-5 text-danger-400" viewBox="0 0 20 20" fill="currentColor">
                <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
              </svg>
            </div>
            <div class="ml-3">
              <p class="text-sm text-danger-800 dark:text-danger-200">
                {{ state.error }}
              </p>
            </div>
          </div>
        </div>
      </div>

      <div class="mt-6">
        <Button
          type="submit"
          variant="primary"
          size="md"
          :loading="state.isSubmitting"
          :disabled="!values.email || state.isSubmitting"
          full-width
        >
          {{ state.isSubmitting ? 'Sending...' : 'Send sign-in link' }}
        </Button>
      </div>

      <div class="mt-4 text-center">
        <slot name="footer">
          <a
            href="/login"
            class="text-sm text-primary-600 hover:text-primary-500 dark:text-primary-400"
          >
            Back to sign in
          </a>
        </slot>
      </div>
    </form>
  </Card>
</template>

<script setup lang="ts">
import { emailAuthApi } from '@utils/api'
import { useForm } from '@composables/useForm'
import { emailRules } from '@utils/validation'
import Card from './shared/Card.vue'
import Button from './shared/Button.vue'
import FormField from './shared/FormField.vue'

interface Props {
  initialEmail?: string
  onSuccess?: (email: string) => void
}

const props = defineProps<Props>()
const emit = defineEmits<{
  success: [email: string]
}>()

const { values, state, errors, handleSubmit, reset } = useForm({
  initialValues: {
    email: props.initialEmail || '',
  },
  validationRules: {
    email: emailRules,
  },
  onSubmit: async (formValues) => {
    const response = await emailAuthApi.request(formValues.email)

    if (response.error) {
      throw new Error(response.error)
    }

    state.success = 'Email sent successfully'
    emit('success', formValues.email)
    props.onSuccess?.(formValues.email)
  },
})
</script>
