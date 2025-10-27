# Quick Start Guide

Get up and running with the Vue 3 SPA components in 5 minutes.

## Prerequisites

- Node.js 18+ installed
- npm or yarn
- Rails app with rodauth-rack configured

## Installation

```bash
# Navigate to the Rails app
cd test/rails/rails_app

# Install dependencies
npm install
```

## Development Mode

Start the Vite dev server:

```bash
npm run dev
```

This starts a development server at `http://localhost:3036` with:

- Hot module replacement (HMR)
- Source maps
- Fast refresh
- TypeScript checking

## Using Components

### 1. Import a Component

```vue
<script setup lang="ts">
import { EmailAuth } from '@components'
</script>

<template>
  <EmailAuth @success="handleSuccess" />
</template>
```

### 2. Or Mount to Existing DOM

Add to your Rails view:

```erb
<!-- app/views/auth/email_login.html.erb -->
<div id="email-auth-app"></div>
```

The component auto-mounts via `main.ts`.

### 3. Add Your Own Component

Create `MyComponent.vue`:

```vue
<template>
  <Card>
    <template #header>
      <h2>My Component</h2>
    </template>

    <p>Hello World</p>

    <Button @click="handleClick">
      Click me
    </Button>
  </Card>
</template>

<script setup lang="ts">
import { Card, Button } from '@components'

function handleClick() {
  console.log('Clicked!')
}
</script>
```

## Common Tasks

### Add a New API Endpoint

1. Define types in `types/index.ts`:

```typescript
export interface MyData {
  id: number
  name: string
}
```

2. Add to API client in `utils/api.ts`:

```typescript
export const myApi = {
  getData: () => apiClient.get<MyData[]>('/my-endpoint'),
  create: (data: MyData) => apiClient.post('/my-endpoint', data),
}
```

3. Use in component:

```vue
<script setup lang="ts">
import { useAsync } from '@composables/useAsync'
import { myApi } from '@utils/api'

const { data, loading, execute } = useAsync(myApi.getData)

onMounted(() => {
  execute()
})
</script>
```

### Add Form Validation

```vue
<script setup lang="ts">
import { useForm } from '@composables/useForm'

const { values, errors, handleSubmit } = useForm({
  initialValues: { email: '' },
  validationRules: {
    email: [
      { required: true, message: 'Email is required' },
      { pattern: /^.+@.+\..+$/, message: 'Invalid email' },
    ]
  },
  onSubmit: async (formValues) => {
    // Submit logic
  }
})
</script>
```

### Show Toast Notification

```vue
<script setup lang="ts">
import { useToast } from '@composables/useToast'

const { success, error } = useToast()

function doSomething() {
  try {
    // Action
    success('Operation completed')
  } catch (err) {
    error('Something went wrong')
  }
}
</script>
```

### Copy to Clipboard

```vue
<script setup lang="ts">
import { useClipboard } from '@composables/useClipboard'

const { copied, copy } = useClipboard()

function copyCode() {
  copy('text to copy')
}
</script>

<template>
  <Button @click="copyCode">
    {{ copied ? 'Copied!' : 'Copy' }}
  </Button>
</template>
```

## Styling

All components use Tailwind CSS. Customize the theme in `tailwind.config.ts`:

```typescript
export default {
  theme: {
    extend: {
      colors: {
        primary: {
          500: '#your-color',
          // ... other shades
        }
      }
    }
  }
}
```

Or add custom CSS in `assets/styles/main.css`:

```css
@layer components {
  .my-custom-class {
    @apply bg-blue-500 text-white rounded;
  }
}
```

## Dark Mode

Enable dark mode by adding the `dark` class:

```html
<html class="dark">
  <!-- Your app -->
</html>
```

Toggle programmatically:

```typescript
document.documentElement.classList.toggle('dark')
```

## TypeScript

All components are fully typed. Get autocomplete in your editor:

```typescript
import type { AuditLog, EmailAuthRequest } from '@types'

const log: AuditLog = {
  id: 1,
  timestamp: '2024-01-01',
  // ... TypeScript will suggest all fields
}
```

## Testing

Run tests:

```bash
npm run test
```

Write a test:

```typescript
import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import MyComponent from './MyComponent.vue'

describe('MyComponent', () => {
  it('renders correctly', () => {
    const wrapper = mount(MyComponent)
    expect(wrapper.text()).toContain('Expected text')
  })
})
```

## Building for Production

```bash
npm run build
```

Output goes to `public/assets/`.

## Troubleshooting

### Port 3036 already in use

Change port in `vite.config.ts`:

```typescript
export default defineConfig({
  server: {
    port: 3037,
  }
})
```

### TypeScript errors

Check types:

```bash
npm run type-check
```

### Component not mounting

Check:

1. Element exists: `document.getElementById('your-id')`
2. Script tag present: `<%= vite_typescript_tag 'main' %>`
3. Console for errors: Check browser DevTools

### Styles not applying

Check:

1. Tailwind config `content` paths
2. `@tailwind` directives in `main.css`
3. Purge not removing used classes

## Common Patterns

### Conditional Rendering

```vue
<template>
  <div v-if="loading">Loading...</div>
  <div v-else-if="error">Error: {{ error }}</div>
  <div v-else>{{ data }}</div>
</template>
```

### Lists

```vue
<template>
  <ul>
    <li v-for="item in items" :key="item.id">
      {{ item.name }}
    </li>
  </ul>
</template>
```

### Forms

```vue
<template>
  <form @submit.prevent="handleSubmit">
    <input v-model="email" type="email" />
    <button type="submit">Submit</button>
  </form>
</template>
```

### Async Data

```vue
<script setup lang="ts">
import { ref, onMounted } from 'vue'

const data = ref(null)
const loading = ref(false)

async function loadData() {
  loading.value = true
  const response = await fetch('/api/data')
  data.value = await response.json()
  loading.value = false
}

onMounted(loadData)
</script>
```

## Next Steps

1. Read the [full README](README.md)
2. Check out [examples](examples/)
3. Review [API documentation](docs/API.md)
4. Explore [component source code](components/)
5. Join the discussion on GitHub

## Getting Help

- **Documentation:** Start with README.md
- **Examples:** See examples/ directory
- **API Specs:** See docs/API.md
- **Issues:** GitHub Issues
- **Discord:** [Link to Discord if available]

## Useful Commands

```bash
# Development
npm run dev              # Start dev server
npm run build            # Build for production
npm run preview          # Preview production build

# Testing
npm run test             # Run tests
npm run test:watch       # Run tests in watch mode
npm run test:coverage    # Generate coverage report
npm run type-check       # Check TypeScript types

# Maintenance
npm run lint             # Lint code (if configured)
npm run format           # Format code (if configured)
npm outdated             # Check for outdated packages
```

## Resources

- [Vue 3 Guide](https://vuejs.org/guide/)
- [Tailwind Docs](https://tailwindcss.com/docs)
- [TypeScript Handbook](https://www.typescriptlang.org/docs/)
- [Vite Guide](https://vitejs.dev/guide/)
- [Vitest Docs](https://vitest.dev/)

---

**Happy coding!**

If you get stuck, check the full documentation in README.md or open an issue on GitHub.
