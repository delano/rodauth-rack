# Rodauth-Rack Vue 3 SPA Components

Production-grade Vue 3 + TypeScript + Tailwind CSS components for building single-page applications that consume the rodauth-rack JSON API.

## Overview

This collection provides ready-to-use, accessible, and customizable Vue components for common authentication and security features:

- **EmailAuth**: Passwordless authentication via email magic links
- **OTPSetup**: Two-factor authentication setup with QR codes
- **OTPVerify**: Two-factor authentication verification during login
- **AuditLogViewer**: Display and filter security activity logs

## Features

- Vue 3 Composition API with TypeScript
- Tailwind CSS 3 for styling (JIT mode)
- Fully typed with comprehensive TypeScript interfaces
- Accessible (WCAG 2.1 AA compliant)
- Responsive design (mobile-first)
- Dark mode support
- Reusable shared components and composables
- Comprehensive error handling
- Loading states and user feedback
- Zero external UI library dependencies

## Quick Start

### Installation

```bash
npm install
```

### Development

```bash
npm run dev
```

Vite will start a development server at `http://localhost:3036`.

### Build for Production

```bash
npm run build
```

Compiled assets will be in the `public/assets` directory.

## Component Documentation

### EmailAuth Component

Request a passwordless sign-in link via email.

**Props:**

- `initialEmail?: string` - Pre-fill email field
- `onSuccess?: (email: string) => void` - Callback on successful submission

**Events:**

- `success: (email: string)` - Emitted when email is sent successfully

**Usage:**

```vue
<template>
  <EmailAuth
    :initial-email="userEmail"
    @success="handleSuccess"
  >
    <template #footer>
      <a href="/login">Back to sign in</a>
    </template>
  </EmailAuth>
</template>

<script setup lang="ts">
import EmailAuth from '@components/EmailAuth.vue'

function handleSuccess(email: string) {
  console.log('Sign-in link sent to:', email)
}
</script>
```

**API Endpoint:**

- `POST /api/auth/email-auth-request`
- Body: `{ email: string }`

---

### OTPSetup Component

Set up two-factor authentication with QR code or manual secret entry.

**Props:**

- `autoInit?: boolean` - Auto-initialize setup on mount (default: true)

**Events:**

- `success: []` - Emitted when OTP is successfully configured
- `cancel: []` - Emitted when user cancels setup

**Usage:**

```vue
<template>
  <OTPSetup
    :auto-init="true"
    @success="handleSuccess"
    @cancel="handleCancel"
  />
</template>

<script setup lang="ts">
import OTPSetup from '@components/OTPSetup.vue'

function handleSuccess() {
  console.log('OTP setup complete')
  // Show success message, redirect, etc.
}

function handleCancel() {
  console.log('OTP setup cancelled')
  // Return to previous page
}
</script>
```

**API Endpoints:**

- `POST /api/mfa/otp/setup` - Initialize OTP setup
- `POST /api/mfa/otp/confirm` - Confirm and enable OTP

**Features:**

- QR code display for easy scanning
- Manual secret entry as fallback
- OTP code verification before enabling
- Recovery codes display and copy
- Step-by-step guided flow

---

### OTPVerify Component

Verify two-factor authentication code during login.

**Props:**

- `showTimer?: boolean` - Show countdown timer (default: true)
- `onSuccess?: (method: 'otp' | 'recovery') => void` - Success callback
- `redirectUrl?: string` - URL to redirect after verification

**Events:**

- `success: (method: 'otp' | 'recovery')` - Emitted on successful verification

**Usage:**

```vue
<template>
  <OTPVerify
    :show-timer="true"
    redirect-url="/dashboard"
    @success="handleSuccess"
  />
</template>

<script setup lang="ts">
import OTPVerify from '@components/OTPVerify.vue'

function handleSuccess(method: 'otp' | 'recovery') {
  console.log(`Verified via ${method}`)
}
</script>
```

**API Endpoint:**

- `POST /api/mfa/verify`
- Body: `{ otp_code?: string, recovery_code?: string }`

**Features:**

- Toggle between OTP code and recovery code
- Real-time countdown timer (30s)
- Remaining attempts display
- Auto-focus input fields
- Keyboard navigation support

---

### AuditLogViewer Component

Display and filter user security activity logs.

**Props:**

- `perPage?: number` - Logs per page (default: 25)
- `showFilters?: boolean` - Show filter controls (default: false)
- `autoLoad?: boolean` - Auto-load on mount (default: true)

**Events:**

- `loaded: (logs: AuditLog[])` - Emitted when logs are loaded
- `error: (error: Error)` - Emitted on load error

**Usage:**

```vue
<template>
  <AuditLogViewer
    :per-page="10"
    :show-filters="true"
    @loaded="handleLoaded"
  />
</template>

<script setup lang="ts">
import AuditLogViewer from '@components/AuditLogViewer.vue'
import type { AuditLog } from '@types/index'

function handleLoaded(logs: AuditLog[]) {
  console.log(`Loaded ${logs.length} logs`)
}
</script>
```

**API Endpoint:**

- `GET /api/audit_logs`
- Query params: `page`, `per_page`, `sort_by`, `sort_order`, `action`, `ip`, `start_date`, `end_date`

**Features:**

- Expandable log details
- Pagination controls
- Filter by action/message
- Sort by date (asc/desc)
- Formatted timestamps (relative and absolute)
- User-friendly action labels
- Badge indicators by category
- Metadata display

---

## Shared Components

### Button

Customizable button with loading state.

```vue
<Button
  type="submit"
  variant="primary"
  size="md"
  :loading="isSubmitting"
  :disabled="!isValid"
  full-width
>
  Submit
</Button>
```

**Props:**

- `type?: 'button' | 'submit' | 'reset'`
- `variant?: 'primary' | 'secondary' | 'danger' | 'ghost'`
- `size?: 'sm' | 'md' | 'lg'`
- `loading?: boolean`
- `disabled?: boolean`
- `fullWidth?: boolean`

---

### Card

Container component with optional header and footer.

```vue
<Card bordered>
  <template #header>
    <h2>Card Title</h2>
  </template>

  <p>Card content goes here</p>

  <template #footer>
    <Button>Action</Button>
  </template>
</Card>
```

---

### FormField

Form field wrapper with label, error handling, and hint text.

```vue
<FormField
  id="email"
  label="Email address"
  :errors="errors.email"
  hint="We'll never share your email"
  :required="true"
>
  <template #default="{ id, errorState }">
    <input
      :id="id"
      v-model="email"
      type="email"
      :aria-invalid="errorState"
    />
  </template>
</FormField>
```

---

### LoadingSpinner

Animated loading indicator.

```vue
<LoadingSpinner
  size="lg"
  color="primary"
  text="Loading..."
/>
```

---

### Toast

Toast notification component.

```vue
<Toast
  type="success"
  message="Changes saved successfully"
  :duration="5000"
  @close="handleClose"
/>
```

---

## Composables

### useForm

Form state management with validation.

```typescript
import { useForm } from '@composables/useForm'
import { emailRules } from '@utils/validation'

const { values, state, errors, handleSubmit, reset } = useForm({
  initialValues: { email: '' },
  validationRules: { email: emailRules },
  onSubmit: async (formValues) => {
    await apiClient.post('/endpoint', formValues)
  },
})
```

---

### useToast

Global toast notification system.

```typescript
import { useToast } from '@composables/useToast'

const { success, error, warning, info } = useToast()

success('Operation completed')
error('Something went wrong')
```

---

### useAsync

Async operation state management.

```typescript
import { useAsync } from '@composables/useAsync'

const { data, error, loading, execute } = useAsync(fetchData)

await execute()
```

---

### useClipboard

Copy to clipboard with feedback.

```typescript
import { useClipboard } from '@composables/useClipboard'

const { copied, copy } = useClipboard()

await copy('Text to copy')
```

---

## TypeScript Types

All components are fully typed. Import types from `@types/index`:

```typescript
import type {
  AuditLog,
  AuditLogsParams,
  EmailAuthRequest,
  OTPSetupResponse,
  OTPVerifyRequest,
  User,
  Toast,
  FormState,
} from '@types/index'
```

---

## API Client

The `apiClient` utility handles all API communication:

```typescript
import { apiClient, auditLogsApi, emailAuthApi, otpApi } from '@utils/api'

// General usage
const response = await apiClient.get('/endpoint')
const response = await apiClient.post('/endpoint', { data })

// Specific endpoints
const logs = await auditLogsApi.list({ page: 1, per_page: 25 })
const result = await emailAuthApi.request('user@example.com')
const setup = await otpApi.setup()
```

---

## Styling Customization

### Tailwind Theme

Customize colors, fonts, and spacing in `tailwind.config.ts`:

```typescript
export default {
  theme: {
    extend: {
      colors: {
        primary: { /* your brand colors */ },
        danger: { /* error colors */ },
        success: { /* success colors */ },
      },
    },
  },
}
```

### Component Customization

All components use Tailwind classes and can be customized via:

1. **Tailwind configuration** - Update theme colors, spacing, etc.
2. **CSS classes** - Add custom classes via props where available
3. **Slots** - Override component sections with custom content
4. **CSS variables** - Define in `main.css` for global changes

---

## Dark Mode

Dark mode is supported via Tailwind's `dark:` variant. Enable it by adding the `dark` class to a parent element:

```html
<html class="dark">
  <!-- App content -->
</html>
```

Or use JavaScript to toggle:

```javascript
document.documentElement.classList.toggle('dark')
```

---

## Accessibility

All components follow WCAG 2.1 AA guidelines:

- Semantic HTML elements
- Proper ARIA attributes
- Keyboard navigation support
- Focus management
- Screen reader compatibility
- Color contrast compliance
- Form labels and error associations

---

## Browser Support

- Chrome/Edge (last 2 versions)
- Firefox (last 2 versions)
- Safari (last 2 versions)
- iOS Safari (last 2 versions)
- Chrome Android (last 2 versions)

---

## Integration Examples

### Mounting Components in Rails Views

**1. Add mount point in ERB template:**

```erb
<!-- app/views/auth/email_auth.html.erb -->
<div id="email-auth-app"></div>
```

**2. Import Vite assets in layout:**

```erb
<!-- app/views/layouts/application.html.erb -->
<%= vite_client_tag %>
<%= vite_typescript_tag 'main' %>
```

**3. Component auto-mounts** (see `main.ts`)

---

### Full SPA Example

See `examples/SecuritySettingsPage.vue` for a complete page combining multiple components.

---

## Testing

### Unit Tests (Vitest)

```bash
npm run test
```

### Type Checking

```bash
npm run type-check
```

---

## Project Structure

```
app/javascript/
├── assets/
│   └── styles/
│       └── main.css           # Global styles + Tailwind
├── components/
│   ├── EmailAuth.vue          # Email authentication
│   ├── OTPSetup.vue           # OTP setup
│   ├── OTPVerify.vue          # OTP verification
│   ├── AuditLogViewer.vue     # Audit logs
│   └── shared/                # Shared components
│       ├── Button.vue
│       ├── Card.vue
│       ├── FormField.vue
│       ├── LoadingSpinner.vue
│       ├── Toast.vue
│       └── ToastContainer.vue
├── composables/               # Vue composables
│   ├── useAsync.ts
│   ├── useClipboard.ts
│   ├── useForm.ts
│   └── useToast.ts
├── examples/                  # Usage examples
│   ├── EmailAuthPage.vue
│   └── SecuritySettingsPage.vue
├── types/                     # TypeScript types
│   └── index.ts
├── utils/                     # Utilities
│   ├── api.ts                 # API client
│   ├── format.ts              # Formatting helpers
│   └── validation.ts          # Form validation
├── main.ts                    # Entry point
└── README.md                  # This file
```

---

## Contributing

When adding new components:

1. Follow Vue 3 Composition API patterns
2. Use TypeScript for all code
3. Apply Tailwind CSS utility classes
4. Ensure WCAG 2.1 AA compliance
5. Add comprehensive prop documentation
6. Include usage examples
7. Write unit tests (Vitest + Testing Library)

---

## License

MIT License - See project root for details.

---

## Resources

- [Vue 3 Documentation](https://vuejs.org/)
- [Tailwind CSS Documentation](https://tailwindcss.com/)
- [Vite Documentation](https://vitejs.dev/)
- [Rodauth Documentation](http://rodauth.jeremyevans.net/)
- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
