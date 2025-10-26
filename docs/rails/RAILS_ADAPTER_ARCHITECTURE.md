# Rodauth-Rack-Rails: Architectural Design

**Version**: 1.0.0
**Date**: 2025-10-26
**Status**: Design Phase

## Executive Summary

This document outlines the architecture for `rodauth-rack-rails`, a Rails-specific adapter that builds on the framework-agnostic `rodauth-rack` core gem. The design prioritizes Rails conventions while maintaining compatibility with the proven patterns from `rodauth-rails` by Janko Marohnić.

## Design Goals

1. **Seamless Rails Integration**: Native Rails middleware, controllers, mailers, and views
2. **Convention over Configuration**: Sensible defaults following Rails patterns
3. **Backward Compatibility**: Familiar API for existing rodauth-rails users
4. **Framework Agnostic Core**: Clean separation via adapter pattern
5. **Full Feature Parity**: Support all 19 Rodauth database features
6. **Production Ready**: Battle-tested patterns from rodauth-rails

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     Rails Application                       │
│  • Controllers (ActionController::Base/API)                 │
│  • Views (ActionView templates)                             │
│  • Mailers (ActionMailer)                                   │
│  • Models (ActiveRecord/Sequel)                             │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────┐
│              Rodauth::Rack::Rails (New Gem)                 │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Railtie (Auto-configuration & Initialization)      │   │
│  │  • Middleware injection                              │   │
│  │  • Controller method mixing                          │   │
│  │  • Test helpers                                      │   │
│  │  • Rake tasks                                        │   │
│  └─────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Rails::Adapter (Implements Base Adapter)           │   │
│  │  • render()          - ActionView integration        │   │
│  │  • csrf_*()          - RequestForgeryProtection      │   │
│  │  • flash()           - ActionDispatch::Flash         │   │
│  │  • deliver_email()   - ActionMailer                  │   │
│  │  • account_model()   - ActiveRecord/Sequel           │   │
│  │  • url_for()         - Rails routing                 │   │
│  └─────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Rails::App (Roda middleware subclass)              │   │
│  │  • Wraps Rodauth in Roda app                         │   │
│  │  • Handles routing to auth endpoints                 │   │
│  │  • Integrates with Rails session/flash               │   │
│  └─────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Rails::Auth (Rodauth configuration)                │   │
│  │  • Rails-specific feature modules                    │   │
│  │  • Default configuration values                      │   │
│  └─────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Rails::ControllerMethods (Mixin)                   │   │
│  │  • rodauth()         - Access Rodauth instance       │   │
│  │  • rodauth_response()- Handle Rodauth redirects      │   │
│  └─────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Generators (Rails::Generators::Base)               │   │
│  │  • InstallGenerator  - Setup Rodauth in Rails        │   │
│  │  • MigrationGenerator- Database migrations           │   │
│  │  • MailerGenerator   - Email templates               │   │
│  │  • ViewsGenerator    - View templates                │   │
│  └─────────────────────────────────────────────────────┘   │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────┐
│              Rodauth::Rack (Core Framework)                 │
│  • Adapter::Base (interface contract)                       │
│  • Middleware (request routing)                             │
│  • Generators::Migration (template rendering)               │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────┐
│                   Rodauth (Auth Logic)                      │
│  • 19 database features                                     │
│  • Authentication logic                                     │
│  • Security features                                        │
└─────────────────────────────────────────────────────────────┘
```

## Adapter Interface Implementation

The `Rodauth::Rack::Adapter::Base` class defines 20 methods across 6 categories:

### 1. View Rendering (2 methods)
- `render(template, locals)` - Render view templates
- `view_path` - Path to template directory

### 2. CSRF Protection (3 methods)
- `csrf_token` - Get CSRF token value
- `csrf_field` - Get CSRF field name
- `valid_csrf_token?(token)` - Validate token

### 3. Session Management (2 methods)
- `session` - Get session hash (inherited from base)
- `clear_session` - Clear session (inherited from base)

### 4. Flash Messages (2 methods)
- `flash` - Get flash hash
- `flash_now(key, message)` - Set flash message (inherited from base)

### 5. URL Generation (2 methods)
- `url_for(path, **options)` - Generate full URL
- `request_path` - Get current path (inherited from base)

### 6. Email Delivery (1 method)
- `deliver_email(mailer, *args)` - Send email

### 7. Model Integration (2 methods)
- `account_model` - Get account model class
- `find_account(id)` - Find account by ID (inherited from base)

### 8. Configuration (2 methods)
- `rodauth_config` - Get Rodauth configuration
- `db` - Get database connection

### 9. Request/Response (4 methods inherited)
- `params` - Request parameters
- `env` - Rack environment
- `redirect(path, status:)` - Redirect response
- `status=(status)` - Set response status

**Total**: 20 methods (14 must implement, 6 inherited)

## Core Components

### 1. Rails Adapter

**File**: `lib/rodauth/rack/rails/adapter.rb`

Implements all 14 required adapter methods:

```ruby
class Adapter < Rodauth::Rack::Adapter::Base
  # View Rendering
  def render(template, locals = {})
    # Try Rails templates, fallback to Rodauth built-ins
  end

  def view_path
    Rails.root.join("app/views/rodauth").to_s
  end

  # CSRF Protection
  def csrf_token
    controller_instance.send(:form_authenticity_token)
  end

  def csrf_field
    ActionController::Base.request_forgery_protection_token.to_s
  end

  def valid_csrf_token?(token)
    controller_instance.send(:valid_authenticity_token?, session, token)
  end

  # Flash Messages
  def flash
    rails_request.flash
  end

  # URL Generation
  def url_for(path, **options)
    Rails.application.routes.url_helpers.url_for(...)
  end

  # Email Delivery
  def deliver_email(mailer_method, *args)
    RodauthMailer.public_send(mailer_method, *args).deliver_now
  end

  # Model Integration
  def account_model
    @account_model ||= infer_account_model
  end

  # Configuration
  def rodauth_config
    @rodauth_config ||= Rails.application.config.rodauth
  end

  def db
    @db ||= configure_sequel_connection
  end
end
```

**Key Features**:
- Creates lightweight controller instance for CSRF and rendering
- Falls back to Rodauth templates when Rails templates missing
- Uses sequel-activerecord_connection for database sharing
- Infers account model from table name

### 2. Railtie Integration

**File**: `lib/rodauth/rack/rails/railtie.rb`

Automatic Rails integration:

```ruby
class Railtie < ::Rails::Railtie
  # Inject middleware
  initializer "rodauth.middleware" do |app|
    app.middleware.use Rodauth::Rack::Rails::Middleware
  end

  # Add controller helpers
  initializer "rodauth.controller_methods" do
    ActiveSupport.on_load(:action_controller) do
      include Rodauth::Rack::Rails::ControllerMethods
    end
  end

  # Configure test helpers
  initializer "rodauth.test_helpers" do
    ENV["RACK_ENV"] = "test" if Rails.env.test?
    # Include test helpers
  end

  # Share ActiveRecord connection with Sequel
  initializer "rodauth.sequel_activerecord" do |app|
    require "sequel/extensions/activerecord_connection"
    app.middleware.use Sequel::ActiveRecordConnection::Middleware
  end

  # Expose rake tasks
  rake_tasks do
    load "rodauth/rack/rails/tasks.rake"
  end
end
```

### 3. Rails Feature Modules

Extend Rodauth features with Rails-specific behavior:

**Base Feature** (`lib/rodauth/rack/rails/feature/base.rb`):
- `rails_account` - Get ActiveRecord/Sequel instance
- `clear_session` - Reset session for security
- `rails_controller` - Determine controller class
- `rails_account_model` - Infer model from table

**Render Feature** (`lib/rodauth/rack/rails/feature/render.rb`):
- `view(page, title)` - Render with layout
- `render(page)` - Render without layout
- Disables Turbo on Rodauth forms
- Marks HTML as safe

**CSRF Feature** (`lib/rodauth/rack/rails/feature/csrf.rb`):
- `csrf_tag` - Generate hidden CSRF field
- `check_csrf` - Verify CSRF token
- Integrates with Rails RequestForgeryProtection

**Email Feature** (`lib/rodauth/rack/rails/feature/email.rb`):
- `create_email_to` - Use ActionMailer
- `send_email` - Deliver with ActionMailer

### 4. Controller Methods

**File**: `lib/rodauth/rack/rails/controller_methods.rb`

Helper methods for Rails controllers:

```ruby
module ControllerMethods
  # Access Rodauth instance
  def rodauth(name = nil)
    env_key = ["rodauth", name].compact.join(".")
    request.env.fetch(env_key)
  end

  # Execute Rodauth methods that redirect
  def rodauth_response(&block)
    res = catch(:halt) { return yield }
    self.status = res[0]
    self.headers.merge! res[1]
    self.response_body = res[2]
    res
  end
end
```

**Usage**:
```ruby
class AccountsController < ApplicationController
  def dashboard
    rodauth.require_account
    @account = rodauth.rails_account
  end

  def logout
    rodauth_response { rodauth.logout }
  end
end
```

### 5. Generators

**Install Generator**: Sets up Rodauth in Rails app
- Creates migration
- Creates Rodauth app class
- Creates controller
- Creates account model
- Creates initializer
- Optionally creates mailer and views

**Migration Generator**: Wraps core migration generator
- Uses `Rodauth::Rack::Generators::Migration`
- Generates ActiveRecord migrations
- Supports all 19 database features

**Mailer Generator**: Creates ActionMailer templates
- Email templates for all features
- Text format

**Views Generator**: Creates view templates
- ERB templates for all Rodauth pages
- Optional Tailwind CSS styling

## Rails-Specific Integrations

### CSRF Protection
- Integrates with Rails `protect_from_forgery`
- Uses Rails CSRF tokens in forms
- Verifies tokens via Rails mechanism

### Flash Messages
- Uses ActionDispatch::Flash
- Default error key is `:alert`
- Commits flash properly on redirects

### ActionMailer
- Sends emails via ActionMailer
- Supports mailer previews
- Works with ActiveJob for background delivery

### Session Management
- Uses Rails session store
- Compatible with all session stores
- Session fixation protection

### URL Generation
- Uses Rails route helpers
- Respects default_url_options
- Proper URL generation for emails

### Database Connection
- Sequel shares ActiveRecord pool
- Uses sequel-activerecord_connection
- No separate connection overhead

### Asset Pipeline
- Middleware skips asset requests
- Compatible with Sprockets and Propshaft

### Turbo/Hotwire
- Disables Turbo on Rodauth forms
- Can integrate with Turbo Streams

### API-Only Mode
- Detects `Rails.configuration.api_only`
- Uses ActionController::API
- Skips view rendering in JSON mode

## File Structure

```
rodauth-rack-rails/
├── lib/
│   ├── rodauth/
│   │   └── rack/
│   │       └── rails/
│   │           ├── adapter.rb              # Rails adapter
│   │           ├── app.rb                  # Roda middleware
│   │           ├── auth.rb                 # Base config
│   │           ├── controller_methods.rb   # Helpers
│   │           ├── mailer.rb               # ActionMailer
│   │           ├── middleware.rb           # Middleware
│   │           ├── railtie.rb              # Integration
│   │           ├── test.rb                 # Test helpers
│   │           ├── version.rb              # Version
│   │           ├── feature/
│   │           │   ├── base.rb
│   │           │   ├── render.rb
│   │           │   ├── csrf.rb
│   │           │   ├── email.rb
│   │           │   └── callbacks.rb
│   │           └── feature.rb
│   ├── generators/
│   │   └── rodauth/
│   │       ├── install_generator.rb
│   │       ├── migration_generator.rb
│   │       ├── mailer_generator.rb
│   │       ├── views_generator.rb
│   │       └── templates/
│   └── rodauth-rack-rails.rb
├── spec/
├── rodauth-rack-rails.gemspec
├── README.md
└── CHANGELOG.md
```

## Dependencies

```ruby
spec.add_dependency "rails", ">= 6.1"
spec.add_dependency "rodauth-rack", "~> 1.0"
spec.add_dependency "rodauth", "~> 2.0"
spec.add_dependency "sequel", "~> 5.0"
spec.add_dependency "sequel-activerecord_connection", "~> 1.0"
spec.add_dependency "roda", "~> 3.0"
spec.add_dependency "tilt", "~> 2.0"
spec.add_dependency "bcrypt", "~> 3.1"
```

## Implementation Phases

### Phase 1: Core Adapter (Week 1)
- Create gem structure
- Implement Adapter class
- Implement Railtie
- Basic middleware
- RSpec setup

### Phase 2: Features (Week 2)
- Implement feature modules
- Implement App class
- Implement Auth class
- Controller methods
- Mailer integration

### Phase 3: Generators (Week 3)
- Install generator
- Migration generator
- Mailer generator
- Views generator

### Phase 4: Testing (Week 4)
- Integration tests
- Generator tests
- Test helpers
- Documentation

### Phase 5: Release (Week 5)
- Demo app
- Security audit
- Beta release
- 1.0 release

## Migration from rodauth-rails

Nearly identical API for easy migration:

```ruby
# Gemfile change
gem "rodauth-rack-rails"  # instead of "rodauth-rails"

# Configuration - minimal changes
class RodauthApp < Rodauth::Rack::Rails::App
  configure do
    # Same configuration
  end
end

# Controllers - no changes
rodauth.require_account
@account = rodauth.rails_account
```

## Security Considerations

1. CSRF protection via Rails built-in
2. Session fixation protection via reset_session
3. HMAC secrets via Rails secret_key_base
4. bcrypt password hashing
5. Sequel parameter binding for SQL injection protection
6. XSS protection via proper html_safe usage

## Success Criteria

1. Drop-in replacement for rodauth-rails
2. All 19 Rodauth features supported
3. Performance within 5% of rodauth-rails
4. Comprehensive documentation
5. Active community adoption

## References

- [Rodauth Documentation](http://rodauth.jeremyevans.net/)
- [rodauth-rails](https://github.com/janko/rodauth-rails)
- [Rodauth::Rack](https://github.com/delano/rodauth-rack)
- [Rails on Rack](https://guides.rubyonrails.org/rails_on_rack.html)
- [Sequel Documentation](https://sequel.jeremyevans.net/)
