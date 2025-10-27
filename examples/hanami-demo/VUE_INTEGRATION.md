# Vue 3 SPA Integration Guide for Hanami Demo

This document explains how to integrate and use the Vue 3 SPA components in the Hanami demo application.

## Overview

The Hanami demo includes pre-built Vue 3 components for common Rodauth authentication flows:

- **EmailAuth.vue** - Passwordless email authentication
- **OTPSetup.vue** - TOTP/MFA enrollment with QR code
- **OTPVerify.vue** - MFA verification (supports both TOTP codes and recovery codes)
- **AuditLogViewer.vue** - Security activity log display with pagination

## Architecture

### Component Structure

```
app/
├── assets/
│   ├── css/
│   │   └── main.css              # Tailwind CSS entry point
│   └── js/
│       ├── components/
│       │   ├── EmailAuth.vue     # Email auth component
│       │   ├── OTPSetup.vue      # MFA setup component
│       │   ├── OTPVerify.vue     # MFA verification component
│       │   ├── AuditLogViewer.vue # Audit log viewer
│       │   └── shared/
│       │       ├── Button.vue    # Reusable button component
│       │       ├── Card.vue      # Card container component
│       │       ├── FormField.vue # Form field wrapper with validation
│       │       └── LoadingSpinner.vue # Loading state indicator
│       ├── composables/
│       │   ├── useAsync.ts       # Async state management
│       │   ├── useClipboard.ts   # Clipboard utilities
│       │   ├── useForm.ts        # Form state and validation
│       │   └── useToast.ts       # Toast notifications
│       ├── types/
│       │   └── index.ts          # TypeScript type definitions
│       ├── utils/
│       │   ├── api.ts            # API client and endpoint definitions
│       │   ├── format.ts         # Formatting utilities
│       │   └── validation.ts     # Form validation rules
│       └── main.ts               # Vue initialization and component mounting
└── templates/
    ├── layouts/
    │   ├── app.html.erb          # Standard layout (no Vue)
    │   └── app_vue.html.erb      # Vue-enabled layout with Tailwind
    └── vue_demos/
        ├── email_auth.html.erb   # Email auth demo page
        ├── otp_setup.html.erb    # MFA setup demo page
        ├── otp_verify.html.erb   # MFA verify demo page
        └── audit_logs.html.erb   # Audit logs demo page
```

### Technology Stack

- **Vue 3** - Progressive JavaScript framework (Composition API)
- **TypeScript** - Type-safe JavaScript development
- **Tailwind CSS 3** - Utility-first CSS framework with JIT compiler
- **Vite** - Fast build tool and dev server with HMR
- **PostCSS** - CSS processing with Autoprefixer

## Setup Instructions

### 1. Install Node.js Dependencies

```bash
cd examples/hanami-demo
npm install
```

### 2. Development Mode

For development with hot module replacement:

```bash
# Terminal 1: Start Vite dev server
npm run dev

# Terminal 2: Start Hanami app with Vite integration
VITE_DEV_SERVER=true bundle exec hanami server
```

The Vite dev server runs on `http://localhost:5173` and provides:

- Hot Module Replacement (HMR) for instant updates
- Source maps for debugging
- Fast refresh for Vue components

### 3. Production Build

Build optimized assets for production:

```bash
npm run build
```

This generates:

- Minified JavaScript bundles in `public/assets/`
- Optimized CSS with Tailwind JIT compilation
- Source maps for debugging (optional)
- Asset manifest for cache busting

### 4. Type Checking

Verify TypeScript types without emitting files:

```bash
npm run type-check
```

## Using Vue Components in Hanami Templates

### Method 1: Using the Vue-Enabled Layout

Use the `app_vue.html.erb` layout which includes Vite assets and Tailwind styles:

```ruby
# app/views/vue_demos/email_auth.rb
module HanamiDemo
  module Views
    module VueDemos
      class EmailAuth < HanamiDemo::View
        config.layout = 'app_vue'

        expose :initial_email
      end
    end
  end
end
```

### Method 2: Individual Component Mounting

In your template, create a mount point with a specific ID:

```erb
<!-- app/templates/vue_demos/email_auth.html.erb -->
<div id="email-auth-app" data-email="<%= @initial_email %>"></div>
```

The Vue initialization script (`main.ts`) automatically detects these mount points and loads the corresponding components.

### Supported Mount Points

| Mount Point ID | Component | Data Attributes |
|---------------|-----------|-----------------|
| `email-auth-app` | EmailAuth | `data-email` - Initial email value |
| `otp-setup-app` | OTPSetup | `data-auto-init` - Auto-initialize setup (default: true) |
| `otp-verify-app` | OTPVerify | `data-show-timer` - Show countdown timer<br>`data-redirect-url` - Post-verification redirect |
| `audit-log-viewer-app` | AuditLogViewer | `data-per-page` - Items per page (default: 25)<br>`data-show-filters` - Enable filtering (default: false) |

## API Endpoint Requirements

The Vue components expect JSON API endpoints following these conventions:

### Email Authentication

**POST** `/api/auth/email-auth-request`

Request:

```json
{
  "email": "user@example.com"
}
```

Response (success):

```json
{
  "success": true,
  "message": "Email sent successfully"
}
```

Response (error):

```json
{
  "error": "Invalid email address",
  "field_errors": {
    "email": ["must be a valid email"]
  }
}
```

### OTP Setup

**POST** `/api/mfa/otp/setup`

Response:

```json
{
  "qr_code": "<svg>...</svg>",
  "secret": "JBSWY3DPEHPK3PXP",
  "provisioning_uri": "otpauth://totp/..."
}
```

**POST** `/api/mfa/otp/confirm`

Request:

```json
{
  "otp_code": "123456"
}
```

Response:

```json
{
  "success": true,
  "recovery_codes": [
    "abcd-1234-efgh-5678",
    "ijkl-9012-mnop-3456",
    ...
  ]
}
```

### OTP Verification

**POST** `/api/mfa/verify`

Request (with OTP code):

```json
{
  "otp_code": "123456"
}
```

Request (with recovery code):

```json
{
  "recovery_code": "abcd-1234-efgh-5678"
}
```

Response:

```json
{
  "success": true
}
```

### Audit Logs

**GET** `/api/audit_logs?page=1&per_page=25&sort_order=desc`

Response:

```json
{
  "data": [
    {
      "id": 1,
      "account_id": 123,
      "timestamp": "2025-10-26T12:34:56Z",
      "message": "User logged in",
      "ip_address": "192.168.1.1",
      "user_agent": "Mozilla/5.0...",
      "session_id": "abc123",
      "request_method": "POST",
      "request_path": "/login",
      "metadata": {}
    }
  ],
  "meta": {
    "page": 1,
    "per_page": 25,
    "total_count": 100,
    "total_pages": 4
  }
}
```

## Component Customization

### Styling with Tailwind

All components use Tailwind CSS utility classes. The theme is configured in `tailwind.config.ts`:

```typescript
export default {
  theme: {
    extend: {
      colors: {
        primary: { /* blue shades */ },
        danger: { /* red shades */ },
        success: { /* green shades */ },
      },
    },
  },
}
```

To customize colors, update the theme configuration and rebuild.

### Dark Mode Support

Dark mode is enabled via the `class` strategy. Toggle with:

```javascript
document.documentElement.classList.toggle('dark')
```

The main.ts includes a dark mode toggle handler:

```javascript
const darkModeToggle = document.getElementById('dark-mode-toggle')
if (darkModeToggle) {
  darkModeToggle.addEventListener('click', () => {
    document.documentElement.classList.toggle('dark')
    localStorage.setItem('darkMode',
      document.documentElement.classList.contains('dark').toString())
  })
}
```

### Component Props

All components accept props that can be passed via data attributes or when mounting programmatically:

```javascript
import { createApp } from 'vue'
import EmailAuth from './components/EmailAuth.vue'

createApp(EmailAuth, {
  initialEmail: 'user@example.com',
  onSuccess: (email) => {
    console.log('Email sent to:', email)
  }
}).mount('#email-auth-app')
```

## TypeScript Support

All code is written in TypeScript with strict type checking enabled. Type definitions are in `app/assets/js/types/index.ts`.

### Adding New Types

```typescript
// app/assets/js/types/index.ts
export interface MyCustomType {
  id: number
  name: string
}
```

### Using Types in Components

```typescript
import type { MyCustomType } from '@types/index'

const data = ref<MyCustomType | null>(null)
```

## Testing

### Running Type Checks

```bash
npm run type-check
```

### Adding Vitest (Optional)

The package.json includes Vitest dependencies. To add tests:

1. Create test files: `*.spec.ts` or `*.test.ts`
2. Add test script: `"test": "vitest"`
3. Run tests: `npm test`

Example test:

```typescript
// app/assets/js/components/EmailAuth.spec.ts
import { mount } from '@vue/test-utils'
import EmailAuth from './EmailAuth.vue'

describe('EmailAuth', () => {
  it('renders email input', () => {
    const wrapper = mount(EmailAuth)
    expect(wrapper.find('input[type="email"]').exists()).toBe(true)
  })
})
```

## Troubleshooting

### Components Not Loading

1. Check that the Vite dev server is running (`npm run dev`)
2. Verify `VITE_DEV_SERVER=true` is set when running Hanami in development
3. Check browser console for errors
4. Ensure mount point IDs match exactly (e.g., `email-auth-app`)

### Styling Not Applied

1. Ensure Tailwind CSS is processing correctly
2. Check that `app/assets/css/main.css` includes Tailwind directives
3. Verify content paths in `tailwind.config.ts`
4. Clear the browser cache and rebuild

### TypeScript Errors

1. Run `npm run type-check` to see all errors
2. Check that path aliases are configured in both `tsconfig.json` and `vite.config.ts`
3. Restart the TypeScript server in your IDE

### API Errors

1. Check that Rodauth JSON API endpoints are enabled
2. Verify CORS configuration if API is on different domain
3. Check browser Network tab for actual request/response
4. Ensure `credentials: 'same-origin'` is set in API client

## Component Compatibility

### Pure Hanami Compatibility

The components are framework-agnostic and only require:

1. Valid JSON API endpoints matching the expected contract
2. A DOM element with the correct mount point ID
3. Vite build pipeline or equivalent module bundler

### No Rails Dependencies

Unlike the original Rails implementation, these components:

- Don't use Rails UJS or Turbolinks
- Don't require Rails asset pipeline
- Don't depend on Rails-specific helpers or middleware

### Adapting to Other Frameworks

To use these components in other Rack frameworks (Sinatra, Roda, etc.):

1. Copy the `app/assets/js` directory
2. Update `vite.config.ts` paths if needed
3. Create templates that include Vite assets
4. Implement the JSON API endpoints
5. Mount components using the documented IDs and data attributes

## Performance Considerations

### Bundle Optimization

- Components are loaded dynamically (code splitting)
- Tailwind CSS purges unused styles in production
- Vite tree-shakes unused code
- Use `npm run build -- --mode production` for maximum optimization

### Lazy Loading

Components are only loaded when their mount points are found:

```typescript
// main.ts
const emailAuthEl = document.getElementById('email-auth-app')
if (emailAuthEl) {
  const { default: EmailAuth } = await import('./components/EmailAuth.vue')
  // Component only loaded if mount point exists
}
```

### Caching Strategy

Production builds include content hashes in filenames:

- `main-[hash].js`
- `main-[hash].css`

This enables aggressive caching with cache-busting on updates.

## Further Customization

### Adding New Components

1. Create Vue component in `app/assets/js/components/`
2. Add mount point handling in `main.ts`
3. Create corresponding template in `app/templates/`
4. Define API endpoints if needed
5. Update this documentation

### Extending the API Client

```typescript
// app/assets/js/utils/api.ts
export const myApi = {
  doSomething: () => apiClient.post('/api/my-endpoint'),
}
```

### Adding Composables

Create reusable composition functions:

```typescript
// app/assets/js/composables/useMyFeature.ts
import { ref } from 'vue'

export function useMyFeature() {
  const value = ref(0)

  function increment() {
    value.value++
  }

  return { value, increment }
}
```

## Resources

- [Vue 3 Documentation](https://vuejs.org/)
- [Tailwind CSS Documentation](https://tailwindcss.com/)
- [Vite Documentation](https://vitejs.dev/)
- [TypeScript Documentation](https://www.typescriptlang.org/)
- [Hanami Documentation](https://guides.hanamirb.org/)
- [Rodauth Documentation](https://rodauth.jeremyevans.net/)
