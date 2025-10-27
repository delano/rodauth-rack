# Testing Guide

This guide covers testing strategies for the Vue 3 components.

## Test Setup

The project uses:

- **Vitest** - Fast unit test framework
- **Vue Test Utils** - Official Vue testing library
- **jsdom** - DOM implementation for Node.js

## Running Tests

```bash
# Run all tests
npm run test

# Run tests in watch mode
npm run test:watch

# Run tests with UI
npm run test:ui

# Run tests with coverage
npm run test:coverage
```

## Writing Tests

### Component Tests

Test components in isolation using Vue Test Utils.

**Example: Button Component**

```typescript
// Button.spec.ts
import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import Button from '@components/shared/Button.vue'

describe('Button', () => {
  it('renders button text', () => {
    const wrapper = mount(Button, {
      slots: {
        default: 'Click me'
      }
    })
    expect(wrapper.text()).toBe('Click me')
  })

  it('emits click event', async () => {
    const wrapper = mount(Button)
    await wrapper.trigger('click')
    expect(wrapper.emitted('click')).toBeTruthy()
  })

  it('shows loading spinner when loading', () => {
    const wrapper = mount(Button, {
      props: { loading: true }
    })
    expect(wrapper.find('.animate-spin').exists()).toBe(true)
  })

  it('disables button when disabled prop is true', () => {
    const wrapper = mount(Button, {
      props: { disabled: true }
    })
    expect(wrapper.attributes('disabled')).toBeDefined()
  })
})
```

### Composable Tests

Test composables independently of components.

**Example: useForm Composable**

```typescript
// useForm.spec.ts
import { describe, it, expect, vi } from 'vitest'
import { useForm } from '@composables/useForm'
import { nextTick } from 'vue'

describe('useForm', () => {
  it('initializes with default values', () => {
    const { values } = useForm({
      initialValues: { email: 'test@example.com' },
      onSubmit: vi.fn()
    })
    expect(values.email).toBe('test@example.com')
  })

  it('validates form before submission', async () => {
    const onSubmit = vi.fn()
    const { handleSubmit, values } = useForm({
      initialValues: { email: '' },
      validationRules: {
        email: [{ required: true }]
      },
      onSubmit
    })

    await handleSubmit()
    expect(onSubmit).not.toHaveBeenCalled()
  })

  it('submits form when valid', async () => {
    const onSubmit = vi.fn()
    const { handleSubmit, values } = useForm({
      initialValues: { email: 'test@example.com' },
      validationRules: {
        email: [{ required: true }]
      },
      onSubmit
    })

    await handleSubmit()
    await nextTick()
    expect(onSubmit).toHaveBeenCalled()
  })
})
```

### API Client Tests

Test API interactions using mocked fetch.

**Example: API Client**

```typescript
// api.spec.ts
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { ApiClient } from '@utils/api'

describe('ApiClient', () => {
  let apiClient: ApiClient

  beforeEach(() => {
    apiClient = new ApiClient('/api')
    global.fetch = vi.fn()
  })

  it('makes GET request', async () => {
    const mockData = { data: 'test' }
    global.fetch.mockResolvedValueOnce({
      ok: true,
      json: async () => mockData
    })

    const response = await apiClient.get('/endpoint')
    expect(response.data).toEqual(mockData)
  })

  it('handles error responses', async () => {
    global.fetch.mockResolvedValueOnce({
      ok: false,
      status: 400,
      json: async () => ({ error: 'Bad request' })
    })

    const response = await apiClient.get('/endpoint')
    expect(response.error).toBe('Bad request')
  })
})
```

## Integration Tests

Test complete user flows combining multiple components.

**Example: Email Auth Flow**

```typescript
// EmailAuthFlow.spec.ts
import { describe, it, expect, vi } from 'vitest'
import { mount } from '@vue/test-utils'
import EmailAuth from '@components/EmailAuth.vue'

describe('Email Auth Flow', () => {
  it('completes email auth request', async () => {
    const onSuccess = vi.fn()
    const wrapper = mount(EmailAuth, {
      props: { onSuccess }
    })

    // Fill in email
    await wrapper.find('input[type="email"]').setValue('test@example.com')

    // Submit form
    await wrapper.find('form').trigger('submit')

    // Wait for async operations
    await wrapper.vm.$nextTick()

    // Verify success callback
    expect(onSuccess).toHaveBeenCalledWith('test@example.com')

    // Verify success message displayed
    expect(wrapper.text()).toContain('Check your email')
  })
})
```

## Testing Best Practices

### 1. Test User Behavior

Focus on testing what users see and do, not implementation details.

```typescript
// Good - Tests user interaction
it('displays error when email is invalid', async () => {
  const wrapper = mount(EmailAuth)
  await wrapper.find('input').setValue('invalid-email')
  await wrapper.find('form').trigger('submit')
  expect(wrapper.text()).toContain('Invalid email format')
})

// Bad - Tests internal state
it('sets error state when email is invalid', () => {
  const wrapper = mount(EmailAuth)
  wrapper.vm.errors.email = ['Invalid']
  expect(wrapper.vm.errors.email).toHaveLength(1)
})
```

### 2. Use Data Test IDs

Add `data-testid` attributes for reliable element selection.

```vue
<button data-testid="submit-button">Submit</button>
```

```typescript
const button = wrapper.find('[data-testid="submit-button"]')
```

### 3. Mock External Dependencies

Mock API calls, timers, and other external dependencies.

```typescript
import { vi } from 'vitest'

vi.mock('@utils/api', () => ({
  apiClient: {
    post: vi.fn().mockResolvedValue({ data: {} })
  }
}))
```

### 4. Test Accessibility

Verify ARIA attributes and keyboard navigation.

```typescript
it('has proper ARIA attributes', () => {
  const wrapper = mount(Button, {
    props: { disabled: true }
  })
  expect(wrapper.attributes('aria-disabled')).toBe('true')
})

it('responds to keyboard events', async () => {
  const wrapper = mount(Modal)
  await wrapper.trigger('keydown.escape')
  expect(wrapper.emitted('close')).toBeTruthy()
})
```

### 5. Test Edge Cases

Cover error states, loading states, and boundary conditions.

```typescript
describe('Edge Cases', () => {
  it('handles network errors gracefully', async () => {
    global.fetch.mockRejectedValueOnce(new Error('Network error'))
    // Test error handling
  })

  it('handles empty data', () => {
    const wrapper = mount(AuditLogViewer, {
      props: { logs: [] }
    })
    expect(wrapper.text()).toContain('No activity yet')
  })
})
```

## Code Coverage

Aim for:

- **80%+ line coverage** - Most code paths executed
- **70%+ branch coverage** - Most conditions tested
- **80%+ function coverage** - Most functions called

View coverage report:

```bash
npm run test:coverage
open coverage/index.html
```

## Continuous Integration

Add to your CI pipeline:

```yaml
# .github/workflows/test.yml
name: Test

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: '18'
      - run: npm ci
      - run: npm run type-check
      - run: npm run test:coverage
```

## Snapshot Testing

Use snapshots for complex component output.

```typescript
it('matches snapshot', () => {
  const wrapper = mount(Card, {
    slots: {
      header: '<h2>Title</h2>',
      default: '<p>Content</p>'
    }
  })
  expect(wrapper.html()).toMatchSnapshot()
})
```

## Visual Regression Testing

For visual changes, consider tools like:

- **Playwright** - E2E testing with screenshots
- **Chromatic** - Visual regression service
- **Percy** - Visual testing platform

## Performance Testing

Test component performance with large datasets.

```typescript
it('renders 1000 logs efficiently', () => {
  const logs = Array.from({ length: 1000 }, (_, i) => ({
    id: i,
    message: `Log ${i}`,
    timestamp: new Date().toISOString()
  }))

  const start = performance.now()
  const wrapper = mount(AuditLogViewer, {
    props: { logs }
  })
  const duration = performance.now() - start

  expect(duration).toBeLessThan(1000) // Should render in < 1s
})
```

## Debugging Tests

### Console Output

```typescript
// Log component HTML
console.log(wrapper.html())

// Log component props
console.log(wrapper.props())

// Log emitted events
console.log(wrapper.emitted())
```

### Debug Mode

```bash
# Run single test in debug mode
npm run test -- --reporter=verbose Button.spec.ts
```

### Browser Debugging

```typescript
import { mount } from '@vue/test-utils'

it('debugs component', () => {
  const wrapper = mount(Button)
  debugger // Add breakpoint
  expect(wrapper.exists()).toBe(true)
})
```

Run with Chrome DevTools:

```bash
node --inspect-brk node_modules/.bin/vitest
```

## Resources

- [Vitest Documentation](https://vitest.dev/)
- [Vue Test Utils](https://test-utils.vuejs.org/)
- [Testing Library](https://testing-library.com/)
- [Vue Testing Handbook](https://lmiller1990.github.io/vue-testing-handbook/)
