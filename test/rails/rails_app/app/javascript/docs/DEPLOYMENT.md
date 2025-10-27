# Deployment Guide

Guide for deploying the Vue 3 SPA components to production.

## Build Process

### 1. Install Dependencies

```bash
npm ci  # Use ci for reproducible builds
```

### 2. Build Assets

```bash
npm run build
```

This will:

- Compile TypeScript to JavaScript
- Bundle components with Vite
- Optimize and minify code
- Generate source maps (optional)
- Output to `public/assets/` directory

### 3. Verify Build

```bash
# Check generated files
ls -lh public/assets/

# Preview production build locally
npm run preview
```

## Rails Integration

### Option 1: Vite Ruby Gem

**Recommended for Rails apps**

1. Add to Gemfile:

```ruby
gem 'vite_rails'
```

2. Install:

```bash
bundle install
bundle exec vite install
```

3. Update layout:

```erb
<!-- app/views/layouts/application.html.erb -->
<%= vite_client_tag %>
<%= vite_typescript_tag 'main' %>
```

4. Development:

```bash
# Terminal 1: Rails server
rails server

# Terminal 2: Vite dev server
bin/vite dev
```

5. Production:

```bash
# Build assets as part of deploy
bundle exec vite build
```

### Option 2: Manual Asset Pipeline

1. Build assets:

```bash
npm run build
```

2. Copy to Rails public:

```bash
cp -r public/assets/* public/
```

3. Include in layout:

```erb
<link rel="stylesheet" href="/assets/main.css">
<script type="module" src="/assets/main.js"></script>
```

### Option 3: CDN Hosting

1. Build assets:

```bash
npm run build
```

2. Upload to CDN (S3, CloudFront, etc.):

```bash
aws s3 sync public/assets/ s3://your-bucket/assets/
```

3. Update asset URLs:

```erb
<link rel="stylesheet" href="https://cdn.example.com/assets/main.css">
<script type="module" src="https://cdn.example.com/assets/main.js"></script>
```

## Environment Variables

Create `.env.production` file:

```bash
# API base URL
VITE_API_BASE_URL=/api

# Enable/disable features
VITE_ENABLE_DEBUG=false
VITE_ENABLE_SENTRY=true

# Sentry DSN (optional)
VITE_SENTRY_DSN=https://...
```

Access in code:

```typescript
const apiUrl = import.meta.env.VITE_API_BASE_URL
```

## Asset Optimization

### 1. Code Splitting

Vite automatically splits code by route/component. Ensure dynamic imports:

```typescript
// Good - lazy loaded
const EmailAuth = () => import('./components/EmailAuth.vue')

// Bad - bundled upfront
import EmailAuth from './components/EmailAuth.vue'
```

### 2. Tree Shaking

Remove unused code:

```typescript
// Good - imports only what's needed
import { ref, computed } from 'vue'

// Bad - imports entire module
import * as Vue from 'vue'
```

### 3. Image Optimization

Optimize images before bundling:

```bash
npm install -D vite-plugin-image-optimizer
```

```typescript
// vite.config.ts
import { ViteImageOptimizer } from 'vite-plugin-image-optimizer'

export default defineConfig({
  plugins: [
    ViteImageOptimizer({
      /* options */
    })
  ]
})
```

### 4. CSS Purging

Tailwind automatically purges unused CSS in production.

Verify purge paths in `tailwind.config.ts`:

```typescript
export default {
  content: [
    './app/javascript/**/*.{vue,js,ts}',
    './app/views/**/*.html.erb',
  ],
}
```

## Performance Monitoring

### 1. Bundle Analysis

Analyze bundle size:

```bash
npm run build -- --mode analyze
```

Or use vite-bundle-visualizer:

```bash
npm install -D vite-bundle-visualizer
```

### 2. Lighthouse Audit

Run Lighthouse on production:

```bash
lighthouse https://your-site.com --view
```

Target scores:

- Performance: 90+
- Accessibility: 95+
- Best Practices: 95+
- SEO: 90+

### 3. Web Vitals

Monitor Core Web Vitals:

- LCP (Largest Contentful Paint): < 2.5s
- FID (First Input Delay): < 100ms
- CLS (Cumulative Layout Shift): < 0.1

## Caching Strategy

### 1. Asset Versioning

Vite adds content hashes to filenames:

```
main.abc123.js
main.def456.css
```

### 2. Cache Headers

Configure server to cache assets:

**nginx:**

```nginx
location /assets/ {
  expires 1y;
  add_header Cache-Control "public, immutable";
}
```

**Apache:**

```apache
<LocationMatch "^/assets/">
  Header set Cache-Control "public, max-age=31536000, immutable"
</LocationMatch>
```

**Rails:**

```ruby
# config/environments/production.rb
config.public_file_server.headers = {
  'Cache-Control' => 'public, max-age=31536000, immutable'
}
```

### 3. Service Worker (Optional)

For offline support:

```bash
npm install -D vite-plugin-pwa
```

```typescript
// vite.config.ts
import { VitePWA } from 'vite-plugin-pwa'

export default defineConfig({
  plugins: [
    VitePWA({
      registerType: 'autoUpdate',
      workbox: {
        globPatterns: ['**/*.{js,css,html,ico,png,svg}']
      }
    })
  ]
})
```

## Security

### 1. Content Security Policy

Add CSP headers:

```ruby
# config/initializers/content_security_policy.rb
Rails.application.config.content_security_policy do |policy|
  policy.default_src :self
  policy.script_src  :self, :unsafe_inline # For Vue
  policy.style_src   :self, :unsafe_inline # For Tailwind
  policy.connect_src :self
end
```

### 2. HTTPS

Enforce HTTPS in production:

```ruby
# config/environments/production.rb
config.force_ssl = true
```

### 3. Subresource Integrity (SRI)

Generate SRI hashes for CDN assets:

```bash
openssl dgst -sha384 -binary main.js | openssl base64 -A
```

```html
<script
  src="https://cdn.example.com/main.js"
  integrity="sha384-..."
  crossorigin="anonymous"
></script>
```

## Error Tracking

### Sentry Integration

1. Install:

```bash
npm install @sentry/vue
```

2. Configure:

```typescript
// main.ts
import * as Sentry from '@sentry/vue'

Sentry.init({
  app,
  dsn: import.meta.env.VITE_SENTRY_DSN,
  environment: import.meta.env.MODE,
  tracesSampleRate: 1.0,
})
```

## Deployment Checklist

- [ ] Run `npm run type-check` - No TypeScript errors
- [ ] Run `npm run test` - All tests pass
- [ ] Run `npm run build` - Build succeeds
- [ ] Check bundle size - Within acceptable limits
- [ ] Test on production-like environment
- [ ] Verify API endpoints work
- [ ] Test authentication flow
- [ ] Check browser console for errors
- [ ] Verify HTTPS is enforced
- [ ] Test responsive design on mobile
- [ ] Verify accessibility with screen reader
- [ ] Run Lighthouse audit
- [ ] Set up error tracking (Sentry)
- [ ] Configure cache headers
- [ ] Enable compression (gzip/brotli)
- [ ] Test dark mode
- [ ] Verify email/OTP flows
- [ ] Check audit log display

## Rollback Plan

1. Keep previous build artifacts:

```bash
# Before new deploy
cp -r public/assets public/assets.backup
```

2. Rollback if needed:

```bash
rm -rf public/assets
mv public/assets.backup public/assets
```

3. Use feature flags for gradual rollout:

```typescript
if (import.meta.env.VITE_ENABLE_NEW_FEATURE === 'true') {
  // New feature
}
```

## Monitoring

### 1. Application Metrics

Track key metrics:

- Page load time
- API response time
- Error rate
- User engagement

### 2. Real User Monitoring

Use tools like:

- Google Analytics
- New Relic
- DataDog
- CloudWatch

### 3. Alerts

Set up alerts for:

- High error rate (> 1%)
- Slow API responses (> 1s)
- Build failures
- Asset delivery issues

## Continuous Deployment

### GitHub Actions Example

```yaml
# .github/workflows/deploy.yml
name: Deploy

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Type check
        run: npm run type-check

      - name: Test
        run: npm run test

      - name: Build
        run: npm run build

      - name: Deploy to production
        run: |
          # Deploy to your hosting platform
          # e.g., rsync, S3 sync, Heroku, etc.
```

## Platform-Specific Guides

### Heroku

```bash
# Add Node.js buildpack
heroku buildpacks:add heroku/nodejs

# Set environment
heroku config:set NODE_ENV=production
```

### AWS Elastic Beanstalk

```yaml
# .ebextensions/nodecommands.config
commands:
  01_npm_install:
    command: npm ci
  02_build:
    command: npm run build
```

### Vercel

```json
// vercel.json
{
  "buildCommand": "npm run build",
  "outputDirectory": "public/assets",
  "framework": "vite"
}
```

## Troubleshooting

### Build fails with memory error

Increase Node.js memory:

```bash
NODE_OPTIONS="--max-old-space-size=4096" npm run build
```

### Assets not loading

Check:

1. Correct asset paths in HTML
2. CORS headers if using CDN
3. Content-Type headers
4. Cache invalidation

### TypeScript errors in production

```bash
# Skip type checking in build (not recommended)
npm run build -- --mode production --no-typecheck
```

### Slow build times

1. Use Vite's cache
2. Reduce bundle size
3. Use faster CI runners
4. Implement incremental builds

## Resources

- [Vite Production Build](https://vitejs.dev/guide/build.html)
- [Vue 3 Production Deployment](https://vuejs.org/guide/best-practices/production-deployment.html)
- [Tailwind CSS Optimization](https://tailwindcss.com/docs/optimizing-for-production)
- [Web.dev Performance](https://web.dev/fast/)
