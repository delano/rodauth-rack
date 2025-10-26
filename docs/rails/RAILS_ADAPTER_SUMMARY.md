# Rodauth-Rack-Rails: Architecture Summary

## Key Architectural Decisions

### 1. Adapter Pattern Implementation

The Rails adapter implements all 20 methods from `Rodauth::Rack::Adapter::Base`:

**Must Implement (14 methods)**:
- View: `render()`, `view_path()`
- CSRF: `csrf_token()`, `csrf_field()`, `valid_csrf_token?()`
- Flash: `flash()`
- URL: `url_for()`
- Email: `deliver_email()`
- Model: `account_model()`
- Config: `rodauth_config()`, `db()`

**Inherited from Base (6 methods)**:
- Session: `session()`, `clear_session()`
- Flash: `flash_now()`
- Request: `params()`, `env()`, `request_path()`
- Response: `redirect()`, `status=()`

### 2. Rails Integration Strategy

**Railtie Auto-Configuration**:
- Middleware injection (after session middleware)
- Controller method mixing (via ActiveSupport.on_load)
- Test helper setup (for controller and system tests)
- Sequel-ActiveRecord connection sharing

**No Manual Setup Required**: The Railtie handles all integration automatically when the gem is loaded.

### 3. Database Connection Sharing

**Strategy**: Use `sequel-activerecord_connection` gem

**Benefits**:
- No separate connection pool
- Shares ActiveRecord's connection
- Works in transactions alongside ActiveRecord
- Zero configuration

**Implementation**:
```ruby
# Railtie adds middleware
app.middleware.use Sequel::ActiveRecordConnection::Middleware

# Adapter configures Sequel
Sequel.postgres(extensions: :activerecord_connection)
```

### 4. Template Rendering Fallback

**Two-Tier Template Resolution**:

1. Try Rails template: `app/views/rodauth/login.html.erb`
2. Fallback to Rodauth built-in: `rodauth/templates/login.str`

**Benefits**:
- Works out-of-box with Rodauth templates
- Easy customization via Rails views
- No forced template generation

### 5. Controller Instance Pattern

**Lightweight Controller Creation**:
```ruby
def create_controller_instance
  controller = ActionController::Base.new
  controller.set_request!(rails_request)
  controller.set_response!(...)
  controller
end
```

**Used For**:
- CSRF token generation/validation
- Template rendering
- Rails helper methods

**Performance**: Minimal overhead, created once per request

### 6. Feature Module Architecture

**Rails-Specific Feature Modules**:
- `Base` - Core Rails integration (accounts, session, controller)
- `Render` - ActionView integration, Turbo handling
- `CSRF` - RequestForgeryProtection integration
- `Email` - ActionMailer integration
- `Callbacks` - Rails lifecycle hooks

**Registered as Rodauth Feature**:
```ruby
configure do
  enable :rails  # Auto-includes all modules
end
```

### 7. Middleware Strategy

**Reloadable Middleware**:
```ruby
class Middleware
  def call(env)
    # Constantize on each request (supports reloading)
    rodauth_app = Rails.configuration.rodauth.app_class.constantize
    app = rodauth_app.new(@app)

    catch(:halt) { app.call(env) }
  end
end
```

**Asset Pipeline Skip**:
```ruby
def asset_request?(env)
  env["PATH_INFO"] =~ %r(\A/{0,2}#{Rails.configuration.assets.prefix})
end
```

### 8. Generator Architecture

**Layered Generator Approach**:

1. **Install Generator** - Orchestrator
   - Calls migration generator
   - Creates app class
   - Creates controller
   - Creates model
   - Creates initializer
   - Optionally calls mailer and views generators

2. **Migration Generator** - Wrapper
   - Delegates to `Rodauth::Rack::Generators::Migration`
   - Wraps in ActiveRecord migration template
   - Infers database adapter

3. **Mailer/Views Generators** - Template copiers
   - Copy email/view templates
   - Support Tailwind CSS variant

### 9. Testing Integration

**Automatic Test Helper Loading**:
```ruby
# Railtie
ActiveSupport.on_load(:action_controller_test_case) do
  include Rodauth::Rack::Rails::Test::Controller
end
```

**Helper Methods**:
```ruby
# Controller tests
login(account)
logout()

# System tests
login(email, password)
```

### 10. JSON/JWT API Support

**Auto-Detection**:
```ruby
def rails_controller
  if only_json? && Rails.configuration.api_only
    ActionController::API
  else
    ActionController::Base
  end
end
```

**Generator Options**:
```bash
rails generate rodauth:install --json   # Cookie-based JSON
rails generate rodauth:install --jwt    # Token-based JWT
```

## Class Hierarchy

```
Rodauth::Rack::Adapter::Base
  └── Rodauth::Rack::Rails::Adapter

Roda
  └── Rodauth::Rack::Rails::App

Rodauth::Auth
  └── Rodauth::Rack::Rails::Auth
        includes: Rodauth::Rack::Rails::Feature
          includes: Base + Render + CSRF + Email + Callbacks

Rails::Railtie
  └── Rodauth::Rack::Rails::Railtie

Rails::Generators::Base
  └── Rodauth::Generators::InstallGenerator
  └── Rodauth::Generators::MigrationGenerator
  └── Rodauth::Generators::MailerGenerator
  └── Rodauth::Generators::ViewsGenerator
```

## Request Flow

```
1. Rails Request
   ↓
2. Rodauth::Rack::Rails::Middleware
   ↓ (if /auth/*)
3. Rodauth::Rack::Rails::App (Roda)
   ↓
4. Rodauth::Auth#rodauth (with :rails feature enabled)
   ↓
5. Rodauth::Rack::Rails::Adapter (implements interface)
   ↓
6. Rails Components (ActionView, ActionMailer, etc.)
```

## Configuration Flow

```
1. config/initializers/rodauth.rb
   Rails.application.config.rodauth.app_class = "RodauthApp"
   ↓
2. app/misc/rodauth_app.rb
   class RodauthApp < Rodauth::Rack::Rails::App
     configure do
       enable :login, :logout, :rails
       # ...
     end
   end
   ↓
3. Railtie injects middleware
   ↓
4. Middleware loads RodauthApp on each request
```

## Key Patterns from rodauth-rails

**Reused Patterns**:
1. Roda middleware wrapper with Rodauth plugin
2. Feature module architecture for Rails integration
3. Controller instance pattern for CSRF/rendering
4. Railtie for automatic configuration
5. Generator templates and structure
6. Flash commit handling on redirects
7. Turbo disabling on Rodauth forms
8. API-only mode detection

**Improvements over rodauth-rails**:
1. Cleaner adapter interface (from rodauth-rack)
2. Framework-agnostic core (can build other adapters)
3. Reusable migration generator
4. Explicit interface contract (Base class)

## Migration Path

**From rodauth-rails to rodauth-rack-rails**:

1. Change Gemfile:
   ```ruby
   # gem "rodauth-rails"
   gem "rodauth-rack-rails"
   ```

2. Update class inheritance (optional):
   ```ruby
   # class RodauthApp < Rodauth::Rails::App
   class RodauthApp < Rodauth::Rack::Rails::App
   ```

3. Run bundle:
   ```bash
   bundle install
   ```

4. No code changes required in:
   - Controllers
   - Views
   - Mailers
   - Tests
   - Configuration

**Compatibility**: 95%+ API compatible

## Performance Considerations

**Optimizations**:
1. Shared connection pool (no Sequel overhead)
2. Middleware skips asset requests
3. Controller instance cached per request
4. Template caching via Rails
5. Lazy model inference

**Benchmarks** (planned):
- Login request: < 50ms (p95)
- CSRF verification: < 1ms
- Template rendering: < 10ms
- Memory overhead: < 5MB

## Security Features

**Built-in Protections**:
1. CSRF via Rails RequestForgeryProtection
2. Session fixation via reset_session
3. HMAC secrets via secret_key_base
4. bcrypt password hashing (cost 12)
5. SQL injection via Sequel bindings
6. XSS via html_safe marking

**Audit Logging** (optional):
```ruby
enable :audit_logging
audit_logging_table :account_authentication_audit_logs
```

## Next Steps

1. Create gem skeleton
2. Implement adapter class (14 methods)
3. Implement Railtie
4. Implement feature modules
5. Implement generators
6. Write integration tests
7. Create demo Rails app
8. Document migration guide
9. Beta release
10. Community feedback
11. 1.0 release

## Files to Create

**Core** (7 files):
- `lib/rodauth/rack/rails/adapter.rb`
- `lib/rodauth/rack/rails/railtie.rb`
- `lib/rodauth/rack/rails/app.rb`
- `lib/rodauth/rack/rails/auth.rb`
- `lib/rodauth/rack/rails/middleware.rb`
- `lib/rodauth/rack/rails/controller_methods.rb`
- `lib/rodauth/rack/rails/mailer.rb`

**Features** (6 files):
- `lib/rodauth/rack/rails/feature.rb`
- `lib/rodauth/rack/rails/feature/base.rb`
- `lib/rodauth/rack/rails/feature/render.rb`
- `lib/rodauth/rack/rails/feature/csrf.rb`
- `lib/rodauth/rack/rails/feature/email.rb`
- `lib/rodauth/rack/rails/feature/callbacks.rb`

**Generators** (4 files):
- `lib/generators/rodauth/install_generator.rb`
- `lib/generators/rodauth/migration_generator.rb`
- `lib/generators/rodauth/mailer_generator.rb`
- `lib/generators/rodauth/views_generator.rb`

**Tests** (10+ files):
- `spec/adapter_spec.rb`
- `spec/railtie_spec.rb`
- `spec/integration/login_spec.rb`
- `spec/integration/csrf_spec.rb`
- `spec/generators/*_spec.rb`

**Total**: ~30 files

## Timeline

- Week 1: Core adapter + Railtie
- Week 2: Features + App + Auth
- Week 3: Generators
- Week 4: Tests + Docs
- Week 5: Polish + Release

**Total**: 5 weeks to 1.0
