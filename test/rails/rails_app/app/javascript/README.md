# Rodauth Vue 3 Components

Vue 3 + TypeScript + Tailwind CSS components for Rodauth authentication.

## Quick Start

```bash
npm install
npm run dev  # Development server at http://localhost:3036
npm run build  # Production build
```

## Components

### Core Components

#### EmailAuth

Passwordless authentication via email magic links.

**Props:**

- `initialEmail?: string` - Pre-fill email
- `onSuccess?: (email: string) => void` - Success callback

**API:** `POST /api/auth/email-auth-request`

#### OTPSetup

Two-factor authentication setup with QR code.

**Props:**

- `onComplete?: (recoveryCodes: string[]) => void` - Setup complete callback

**API:**

- `POST /api/auth/otp-setup` - Initialize
- `POST /api/auth/otp-auth` - Verify code

#### OTPVerify

Two-factor authentication verification during login.

**Props:**

- `requireAuth?: boolean` - Show recovery code option

**API:**

- `POST /api/auth/otp-auth` - Verify OTP
- `POST /api/auth/recovery-auth` - Use recovery code

#### AuditLogViewer

Display and filter security activity logs.

**Props:**

- `perPage?: number` - Logs per page (default: 25)

**API:** `GET /api/audit-logs?page={n}&per_page={n}`

### Shared Components

#### Button

Styled button with loading state.

**Props:** `variant?: 'primary' | 'secondary' | 'danger'`, `loading?: boolean`, `disabled?: boolean`

#### Card

Container with shadow and rounded corners.

**Slots:** `header`, `default`, `footer`

#### FormField

Form input with label and error handling.

**Props:** `label: string`, `type?: string`, `modelValue: string`, `error?: string`, `required?: boolean`

#### LoadingSpinner

Animated loading indicator.

**Props:** `size?: 'sm' | 'md' | 'lg'`

#### Toast

Notification message with auto-dismiss.

**Props:** `message: string`, `type?: 'success' | 'error' | 'warning' | 'info'`, `duration?: number`

#### ToastContainer

Container for managing multiple toast notifications.

## Composables

### useApi

HTTP API client with error handling.

```ts
const { get, post, loading, error } = useApi()
```

### useAuth

Authentication state management.

```ts
const { isAuthenticated, checkAuth, logout } = useAuth()
```

### useToast

Toast notification management.

```ts
const { showToast, showSuccess, showError } = useToast()
```

### useClipboard

Copy text to clipboard.

```ts
const { copy, copied } = useClipboard()
```

## Usage Example

```vue
<template>
  <EmailAuth
    :initial-email="email"
    @success="handleSuccess"
  />
</template>

<script setup lang="ts">
import EmailAuth from '@/components/EmailAuth.vue'

const email = ref('')

function handleSuccess(email: string) {
  console.log('Email sent to:', email)
}
</script>
```

## TypeScript Types

All components are fully typed. See `types.ts` for API response types:

- `EmailAuthRequest`
- `OTPSetupResponse`
- `AuditLog`
- `ApiError`

## Styling

Uses Tailwind CSS 3 with JIT mode. Dark mode supported via `dark:` variants.

Custom colors in `tailwind.config.js`:

- Primary: Blue
- Secondary: Gray
- Danger: Red
- Success: Green

## API Requirements

Components expect these Rodauth endpoints:

- `POST /api/auth/email-auth-request`
- `POST /api/auth/otp-setup`
- `POST /api/auth/otp-auth`
- `POST /api/auth/recovery-auth`
- `GET /api/audit-logs`

Configure in Rodauth with `enable :json` and appropriate features.

## Development

```bash
npm run dev          # Start dev server
npm run build        # Production build
npm run type-check   # TypeScript checking
npm run lint         # ESLint
```

## Tech Stack

- Vue 3 (Composition API)
- TypeScript 5
- Tailwind CSS 3
- Vite 5
- Pinia (state management)
