# Quick Start: Vue Components in Hanami

Get Vue 3 components running in the Hanami demo in 5 minutes.

## 1. Install Dependencies

```bash
cd examples/hanami-demo
npm install
```

## 2. Start Development Servers

```bash
# Terminal 1: Vite dev server (port 5173)
npm run dev

# Terminal 2: Hanami app (port 2300)
VITE_DEV_SERVER=true bundle exec hanami server
```

## 3. Create a Vue-Enabled Page

### Step A: Add Route

Edit `config/routes.rb`:

```ruby
get '/email-auth', to: 'vue_demos.email_auth'
```

### Step B: Create Action

Create `app/actions/vue_demos/email_auth.rb`:

```ruby
# frozen_string_literal: true

module HanamiDemo
  module Actions
    module VueDemos
      class EmailAuth < HanamiDemo::Action
        def handle(request, response)
          # Optional: Pass initial data to component
          response.render view, initial_email: request.params[:email]
        end
      end
    end
  end
end
```

### Step C: Create View

Create `app/views/vue_demos/email_auth.rb`:

```ruby
# frozen_string_literal: true

module HanamiDemo
  module Views
    module VueDemos
      class EmailAuth < HanamiDemo::View
        config.layout = 'app_vue'  # Use Vue-enabled layout

        expose :initial_email
      end
    end
  end
end
```

### Step D: Create Template

Create `app/templates/vue_demos/email_auth.html.erb`:

```erb
<div class="mx-auto max-w-md">
  <h2 class="text-2xl font-bold text-gray-900 dark:text-white mb-6">
    Email Authentication
  </h2>

  <!-- Vue component mount point -->
  <div id="email-auth-app" data-email="<%= initial_email %>"></div>
</div>
```

## 4. Visit Your Page

Open `http://localhost:2300/email-auth` in your browser.

The Vue component will automatically mount and be ready to use!

## Available Components

### EmailAuth

Mount point: `<div id="email-auth-app"></div>`

- Passwordless email authentication
- Data attributes: `data-email` (optional initial email)

### OTPSetup

Mount point: `<div id="otp-setup-app"></div>`

- TOTP/MFA enrollment with QR code
- Data attributes: `data-auto-init` (default: true)

### OTPVerify

Mount point: `<div id="otp-verify-app"></div>`

- MFA verification (TOTP codes + recovery codes)
- Data attributes:
  - `data-show-timer` (default: true)
  - `data-redirect-url` (post-verification redirect)

### AuditLogViewer

Mount point: `<div id="audit-log-viewer-app"></div>`

- Security activity log display
- Data attributes:
  - `data-per-page` (default: 25)
  - `data-show-filters` (default: false)

## Production Deployment

### 1. Build Assets

```bash
npm run build
```

### 2. Update Environment

Remove or set `VITE_DEV_SERVER=false`:

```bash
bundle exec hanami server
```

### 3. Serve Static Assets

Ensure your production server (Puma, Nginx, etc.) serves files from `public/assets/`.

The `app_vue.html.erb` layout automatically switches between dev and production asset loading.

## Component API Requirements

Each component expects JSON API endpoints. Here's the minimum setup:

### Email Auth

```ruby
# POST /api/auth/email-auth-request
{ "email": "user@example.com" }
# Returns: { "success": true } or { "error": "..." }
```

### OTP Setup

```ruby
# POST /api/mfa/otp/setup
# Returns: { "qr_code": "<svg>", "secret": "...", "provisioning_uri": "..." }

# POST /api/mfa/otp/confirm
{ "otp_code": "123456" }
# Returns: { "success": true, "recovery_codes": [...] }
```

### OTP Verify

```ruby
# POST /api/mfa/verify
{ "otp_code": "123456" }  # or { "recovery_code": "..." }
# Returns: { "success": true }
```

### Audit Logs

```ruby
# GET /api/audit_logs?page=1&per_page=25
# Returns: { "data": [...], "meta": { "page": 1, "total_count": 100, ... } }
```

## Troubleshooting

### Component not appearing?

1. Check browser console for errors
2. Verify Vite dev server is running (`npm run dev`)
3. Confirm `VITE_DEV_SERVER=true` is set
4. Check mount point ID matches exactly

### No styles?

1. Ensure using `app_vue` layout
2. Verify Tailwind CSS is processing
3. Clear browser cache

### API errors?

1. Check endpoint URLs in `app/assets/js/utils/api.ts`
2. Verify Rodauth JSON API is enabled
3. Check browser Network tab for details

## Next Steps

- Read [VUE_INTEGRATION.md](./VUE_INTEGRATION.md) for complete documentation
- Customize colors in `tailwind.config.ts`
- Add your own components in `app/assets/js/components/`
- Implement JSON API endpoints for Rodauth features

## Example: Complete Working Page

Here's everything you need for a working email auth page:

**Route** (`config/routes.rb`):

```ruby
get '/demo-email-auth', to: 'vue_demos.email_auth'
```

**Action** (`app/actions/vue_demos/email_auth.rb`):

```ruby
module HanamiDemo::Actions::VueDemos
  class EmailAuth < HanamiDemo::Action
    def handle(request, response)
      response.render view
    end
  end
end
```

**View** (`app/views/vue_demos/email_auth.rb`):

```ruby
module HanamiDemo::Views::VueDemos
  class EmailAuth < HanamiDemo::View
    config.layout = 'app_vue'
  end
end
```

**Template** (`app/templates/vue_demos/email_auth.html.erb`):

```erb
<div id="email-auth-app"></div>
```

That's it! The component will automatically mount when the page loads.
