# Development Guide - rodauth-rack

**Last Updated:** 2025-10-26
**Branch:** `feature/3-rails-adapter`
**Status:** Rails adapter core migration complete, testing phase needed

## Critical Architectural Discovery

### The Feature-Based Pattern (NOT Adapter Delegation)

**❌ WRONG ASSUMPTION (Original Plan):**
We initially assumed Rodauth integrations should use an adapter delegation pattern:

```ruby
# This is NOT how rodauth-rails works!
class Rodauth::Rack::Adapter::Rails
  def render_view(template, locals: {})
    # Delegate to ActionView
  end

  def csrf_token
    # Delegate to ActionController
  end

  # 20+ delegation methods...
end
```

**✅ CORRECT PATTERN (Actual Implementation):**
rodauth-rails uses a **feature-based architecture** where modules mix into Rodauth instances:

```ruby
# This IS how rodauth-rails works!
Rodauth::Feature.define(:rails) do
  auth_class_eval do
    # Methods defined here mix into the Rodauth auth instance
  end
end

# Feature modules in lib/rodauth/rack/rails/feature/
module Rodauth::Rack::Rails::Feature
  module Base
    # Core integration methods that become part of Rodauth
  end

  module Render
    def view_layout(template)
      # Override Rodauth's rendering with Rails rendering
    end
  end

  module CSRF
    def csrf_token
      # Rails CSRF token, mixed into Rodauth instance
    end
  end
end
```

### Why This Matters

1. **Framework-Specific Classes**: `App`, `Auth`, and `Middleware` are NOT extracted to a framework-agnostic core. Each framework has its own:
   - `Rodauth::Rack::Rails::App` (Roda app with Rails-specific plugins)
   - `Rodauth::Rack::Rails::Auth` (Rodauth::Auth subclass with Rails defaults)
   - `Rodauth::Rack::Rails::Middleware` (Rails middleware wrapper)

2. **Feature Modules, Not Adapters**: Integration happens through feature modules that mix into Rodauth, following Rodauth's designed extension pattern.

3. **No Delegation Overhead**: Methods are directly available on the Rodauth instance, not delegated through a wrapper.

## Current Project State

### What's Been Completed ✅

**Rails Adapter Core Migration (Issue #3):**

- ✅ 77 files migrated from rodauth-rails
- ✅ All namespace transformations (`Rodauth::Rails` → `Rodauth::Rack::Rails`)
- ✅ 7 feature modules implemented (base, callbacks, csrf, email, instrumentation, internal_request, render)
- ✅ 4 Rails generators with 57 template files (install, migration, views, mailer)
- ✅ 38 migration templates for both ActiveRecord and Sequel
- ✅ Dependencies added to gemspec
- ✅ Comparison test framework created (`test/comparison/`)

**File Structure:**

```
lib/rodauth/rack/rails/
├── module.rb (104 LOC - main Rails module)
├── app.rb (93 LOC - Roda app with Rails integration)
├── auth.rb (22 LOC - Auth subclass with Rails defaults)
├── middleware.rb (30 LOC - Rails middleware wrapper)
├── railtie.rb (38 LOC - Rails initialization)
├── controller_methods.rb (37 LOC - Rails controller helpers)
├── mailer.rb (9 LOC - ActionMailer integration)
├── test.rb + test/controller.rb
├── feature.rb (23 LOC - feature definition)
├── feature/
│   ├── base.rb (85 LOC - core Rails integration)
│   ├── callbacks.rb (69 LOC - controller callbacks)
│   ├── csrf.rb (79 LOC - CSRF protection)
│   ├── email.rb (35 LOC - email delivery)
│   ├── instrumentation.rb (96 LOC - ActiveSupport notifications)
│   ├── internal_request.rb (67 LOC - internal requests)
│   └── render.rb (71 LOC - view rendering)
└── tasks/ (rake tasks)

lib/generators/rodauth/
├── install_generator.rb (131 LOC)
├── migration_generator.rb (209 LOC)
├── mailer_generator.rb (122 LOC)
├── views_generator.rb (127 LOC)
└── templates/ (53 template files)

lib/rodauth/rack/generators/
└── migration/ (38 .erb migration templates - framework-agnostic)
```

### What Needs to Be Done Next ⏳

**Priority 1: Test Suite Migration (2-3 days)**

```bash
# 41 test files need to be migrated:
../../rodauth-rails/test/ → test/rails/

Critical files to migrate:
- test_helper.rb (adapt for monorepo)
- controllers/ (controller integration tests)
- generators/ (generator tests - verify our generators work)
- integration/ (9+ integration test files)
- internal_request_test.rb
- model_mixin_test.rb
- rake_test.rb
- rodauth_test.rb
```

**Test Migration Checklist:**

- [ ] Copy test files from `../../rodauth-rails/test/` to `test/rails/`
- [ ] Update `test_helper.rb` to use `require "rodauth/rack/rails"` instead of `require "rodauth-rails"`
- [ ] Update namespace references in tests (`Rodauth::Rails` → `Rodauth::Rack::Rails`)
- [ ] Update require paths in tests
- [ ] Run test suite: `bundle exec rake test` or similar
- [ ] Fix any failures related to namespace changes
- [ ] Ensure all 41+ tests pass

**Priority 2: Integration Testing (1 day)**

```bash
# Create a real Rails app to verify generators work:
rails new test_app --database=postgresql
cd test_app

# Add rodauth-rack to Gemfile (local path)
gem 'rodauth-rack', path: '../rodauth-rack'

# Test generators:
rails generate rodauth:install
rails generate rodauth:views
rails generate rodauth:mailer

# Verify:
- Files are generated correctly
- No namespace errors
- App starts: rails s
- Authentication flows work
- Feature modules work (CSRF, flash, rendering, email)
```

**Integration Test Checklist:**

- [ ] Install generator creates all files correctly
- [ ] Migration generator creates valid migrations
- [ ] Views generator creates view templates
- [ ] Mailer generator creates mailer templates
- [ ] Rails app starts without errors
- [ ] Can register a new account
- [ ] Can login/logout
- [ ] Password reset flow works
- [ ] Email verification works
- [ ] CSRF protection works
- [ ] Flash messages work
- [ ] JSON API mode works
- [ ] JWT mode works

**Priority 3: Documentation (1 day)**

- [ ] Update main `README.md` with Rails adapter section
- [ ] Create `docs/rails-adapter.md` with detailed Rails usage
- [ ] Document migration from rodauth-rails to rodauth-rack
- [ ] Add code examples for common use cases
- [ ] Document breaking changes (if any)
- [ ] Update API documentation

## Key Files and Their Purposes

### Entry Points

- `lib/rodauth/rack/rails.rb` - Main entry point, requires Rails module and railtie
- `lib/rodauth/rack/rails/module.rb` - Core Rails module with configuration DSL
- `lib/rodauth/rack/rails/railtie.rb` - Rails initialization, auto-loads middleware

### Core Components

- `lib/rodauth/rack/rails/app.rb` - Roda app with Rails-specific plugins and methods
- `lib/rodauth/rack/rails/auth.rb` - Rodauth::Auth subclass with Rails defaults
- `lib/rodauth/rack/rails/middleware.rb` - Rails middleware that wraps the Roda app
- `lib/rodauth/rack/rails/feature.rb` - Feature definition (`Rodauth::Feature.define(:rails)`)

### Feature Modules (The Heart of Integration)

- `lib/rodauth/rack/rails/feature/base.rb` - Core integration (session, flash, controller access)
- `lib/rodauth/rack/rails/feature/render.rb` - ActionView rendering integration
- `lib/rodauth/rack/rails/feature/csrf.rb` - ActionController CSRF protection
- `lib/rodauth/rack/rails/feature/email.rb` - ActionMailer integration
- `lib/rodauth/rack/rails/feature/callbacks.rb` - Controller callback integration
- `lib/rodauth/rack/rails/feature/instrumentation.rb` - ActiveSupport::Notifications
- `lib/rodauth/rack/rails/feature/internal_request.rb` - Internal request handling

### Generators

- `lib/generators/rodauth/install_generator.rb` - Creates initializer, models, controllers
- `lib/generators/rodauth/migration_generator.rb` - Creates database migrations
- `lib/generators/rodauth/views_generator.rb` - Creates view templates
- `lib/generators/rodauth/mailer_generator.rb` - Creates mailer templates

### Migration Templates (Framework-Agnostic)

- `lib/rodauth/rack/generators/migration/active_record/*.erb` - ActiveRecord migrations
- `lib/rodauth/rack/generators/migration/sequel/*.erb` - Sequel migrations

## Understanding the Codebase

### How Rodauth Integration Works

1. **Rails loads the Railtie** (`lib/rodauth/rack/rails/railtie.rb`)
   - Adds middleware to Rails stack
   - Loads controller methods
   - Initializes configuration

2. **Middleware intercepts requests** (`lib/rodauth/rack/rails/middleware.rb`)
   - Creates Roda app instance with Rodauth
   - Processes authentication requests
   - Passes through to Rails app

3. **Roda app configures Rodauth** (`lib/rodauth/rack/rails/app.rb`)
   - Configures Rodauth with Rails-specific settings
   - Enables the `:rails` feature
   - Routes Rodauth endpoints

4. **Feature modules enhance Rodauth** (`lib/rodauth/rack/rails/feature/*.rb`)
   - Methods mix into Rodauth auth instance
   - Override Rodauth defaults with Rails-specific implementations
   - Provide Rails integrations (views, CSRF, email, etc.)

### Example: How View Rendering Works

```ruby
# In lib/rodauth/rack/rails/feature/render.rb
module Rodauth::Rack::Rails::Feature
  module Render
    def view_layout(template)
      # This method mixes into Rodauth instance
      # Overrides Rodauth's default rendering

      return super if rails_api_controller?

      # Use ActionView to render Rodauth templates
      rails_render(template: "rodauth/#{template}")
    end
  end
end

# When Rodauth calls view_layout("login"):
# 1. Method is defined on the Rodauth instance (via mixin)
# 2. ActionView renders app/views/rodauth/login.html.erb
# 3. Rails layout is applied automatically
```

### Example: How CSRF Protection Works

```ruby
# In lib/rodauth/rack/rails/feature/csrf.rb
module Rodauth::Rack::Rails::Feature
  module CSRF
    def csrf_token
      # Mixed into Rodauth instance
      # Returns Rails CSRF token
      rails_controller.send(:form_authenticity_token)
    end

    def check_csrf
      # Mixed into Rodauth instance
      # Uses Rails CSRF verification
      rails_controller.send(:verify_authenticity_token)
    end
  end
end
```

## Common Pitfalls and How to Avoid Them

### 1. Don't Create Adapter Classes

❌ **Wrong:**

```ruby
class Rodauth::Rack::Adapter::SomeFramework
  def some_method
    # Delegation
  end
end
```

✅ **Correct:**

```ruby
# Create feature modules that mix in
module Rodauth::Rack::SomeFramework::Feature
  module SomeModule
    def some_method
      # Direct implementation
    end
  end
end
```

### 2. Don't Extract Framework-Specific Code to Core

❌ **Wrong:**

```ruby
# lib/rodauth/rack/app.rb - trying to make it generic
class App < Roda
  # Generic code that all frameworks use
end
```

✅ **Correct:**

```ruby
# lib/rodauth/rack/rails/app.rb - Rails-specific
class App < Roda
  # Rails-specific Roda plugins and configuration
  def rails_routes
    ::Rails.application.routes.url_helpers
  end
end

# lib/rodauth/rack/hanami/app.rb - Hanami-specific
class App < Roda
  # Hanami-specific Roda plugins and configuration
  def hanami_routes
    ::Hanami.app.routes
  end
end
```

### 3. Remember Namespace Transformations

When migrating code from rodauth-rails:

- Replace `Rodauth::Rails` with `Rodauth::Rack::Rails`
- Replace `require "rodauth/rails/..."` with `require_relative "..."`
- Update generator class names: `Rodauth::Rails::Generators` → `Rodauth::Rack::Rails::Generators`

### 4. Reuse Migration Templates

Don't recreate migration templates. The ones in `lib/rodauth/rack/generators/migration/` are framework-agnostic:

```ruby
# In any framework generator:
template_path = Rodauth::Rack.root.join("lib/rodauth/rack/generators/migration")
# Use the same templates for Rails, Hanami, Roda, Sinatra
```

## Testing Strategy

### Test Types Needed

1. **Unit Tests** - Test feature modules in isolation

   ```ruby
   # test/rails/feature/render_test.rb
   test "view_layout renders Rails template" do
     # Test render feature module
   end
   ```

2. **Generator Tests** - Test that generators create correct files

   ```ruby
   # test/rails/generators/install_generator_test.rb
   test "creates rodauth initializer" do
     run_generator
     assert_file "config/initializers/rodauth.rb"
   end
   ```

3. **Integration Tests** - Test full authentication flows

   ```ruby
   # test/rails/integration/login_test.rb
   test "user can login" do
     post "/login", params: { login: "user@example.com", password: "secret" }
     assert_redirected_to "/"
   end
   ```

4. **Comparison Tests** - Verify output matches rodauth-rails

   ```ruby
   # test/comparison/compare_rails_adapters.rb
   # Already created, verifies generators produce same output
   ```

### Running Tests

```bash
# Run all tests
bundle exec rake test

# Run specific test file
bundle exec ruby -Itest test/rails/integration/login_test.rb

# Run comparison test
ruby test/comparison/compare_rails_adapters.rb

# With verbose output
VERBOSE=1 ruby test/comparison/compare_rails_adapters.rb
```

## How to Implement a New Framework Adapter

### Step-by-Step Guide (Using Hanami as Example)

**1. Study the Rails Adapter**

```bash
# Read these files in order:
lib/rodauth/rack/rails/module.rb      # Main module
lib/rodauth/rack/rails/app.rb         # Roda app
lib/rodauth/rack/rails/auth.rb        # Auth defaults
lib/rodauth/rack/rails/feature.rb     # Feature definition
lib/rodauth/rack/rails/feature/*.rb   # Feature modules
```

**2. Create Framework-Specific Structure**

```bash
# Create directory structure:
mkdir -p lib/rodauth/rack/hanami/feature
mkdir -p lib/rodauth/rack/hanami/tasks
mkdir -p lib/rodauth/rack/hanami/test
```

**3. Implement Core Classes**

```ruby
# lib/rodauth/rack/hanami/app.rb
module Rodauth::Rack::Hanami
  class App < Roda
    plugin :middleware
    plugin :hooks

    def self.configure(*args, render: true, **, &)
      auth_class = args.shift if args[0].is_a?(Class)
      auth_class ||= Rodauth::Rack::Hanami::Auth

      plugin :render, layout: false unless render == false
      plugin :rodauth, auth_class: auth_class, csrf: false, flash: false, **
    end

    # Hanami-specific helper methods
    def hanami_app
      ::Hanami.app
    end
  end
end

# lib/rodauth/rack/hanami/auth.rb
module Rodauth::Rack::Hanami
  class Auth < Rodauth::Auth
    configure do
      enable :hanami  # Enable the Hanami feature
      use_database_authentication_functions? false
      set_deadline_values? true
      hmac_secret { Hanami.app["settings"].secret_key_base }
    end
  end
end

# lib/rodauth/rack/hanami/middleware.rb
module Rodauth::Rack::Hanami
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      app = Rodauth::Rack::Hanami::App.new(@app)
      catch(:halt) { app.call(env) }
    end
  end
end
```

**4. Define the Feature**

```ruby
# lib/rodauth/rack/hanami/feature.rb
require "rodauth"
require_relative "feature/base"
require_relative "feature/render"
require_relative "feature/csrf"
require_relative "feature/email"

module Rodauth::Rack::Hanami
  Feature = Rodauth::Feature.define(:hanami) do
    auth_class_eval do
      include Feature::Base
      include Feature::Render
      include Feature::CSRF
      include Feature::Email
    end
  end
end
```

**5. Implement Feature Modules**

```ruby
# lib/rodauth/rack/hanami/feature/base.rb
module Rodauth::Rack::Hanami::Feature
  module Base
    def session
      hanami_request.session
    end

    def flash
      hanami_request.flash
    end

    private

    def hanami_request
      @hanami_request ||= ::Hanami::Request.new(env)
    end
  end
end

# lib/rodauth/rack/hanami/feature/render.rb
module Rodauth::Rack::Hanami::Feature
  module Render
    def view_layout(template)
      # Use Hanami::View for rendering
      hanami_render(template)
    end

    private

    def hanami_render(template)
      # Hanami-specific rendering logic
    end
  end
end
```

**6. Create Generators/CLI**

```ruby
# For Hanami, create CLI commands or generators
# Reuse migration templates from lib/rodauth/rack/generators/migration/
```

**7. Write Tests**

```ruby
# test/hanami/feature/base_test.rb
# test/hanami/integration/login_test.rb
```

## Reference Materials

### Code References

- **Rails adapter**: `lib/rodauth/rack/rails/` (completed implementation)
- **rodauth-rails source**: `../../rodauth-rails/` (original implementation)
- **Rodauth documentation**: <https://github.com/jeremyevans/rodauth>
- **roda-sequel-stack**: <https://github.com/jeremyevans/roda-sequel-stack> (Roda reference)

### Memory Files

Read these memory files for additional context:

```bash
# In Serena MCP:
1025-rodauth-rack-project-overview
1025-rodauth-rack-adapter-interface
1025-rodauth-rack-migration-generators
1026-rodauth-rails-refactoring-plan
1026-rails-migration-completion-report
```

### Issues

- Issue #3: Rails adapter (in progress - testing phase)
- Issue #4: Hanami adapter (needs architectural revision)
- Issue #5: CLI tool (can proceed with current plan)
- Issue #6: Demo applications (waiting on adapters)

## Getting Started - Immediate Next Steps

### If Continuing Rails Adapter (Issue #3)

1. **Migrate the test suite** (highest priority):

   ```bash
   # Copy test files
   cp -r ../../rodauth-rails/test/* test/rails/

   # Update test_helper.rb
   # Change: require "rodauth-rails"
   # To: require "rodauth/rack/rails"

   # Run tests
   bundle exec rake test
   ```

2. **Fix test failures**:
   - Most will be namespace issues (`Rodauth::Rails` → `Rodauth::Rack::Rails`)
   - Some may be require path issues
   - Check for hardcoded paths to rodauth-rails

3. **Integration test with real Rails app**:

   ```bash
   rails new test_app
   cd test_app
   # Add to Gemfile: gem 'rodauth-rack', path: '../rodauth-rack'
   bundle install
   rails generate rodauth:install
   rails s
   # Test authentication flows
   ```

### If Starting Hanami Adapter (Issue #4)

1. **Study the Rails adapter**:

   ```bash
   # Read these files to understand the pattern:
   cat lib/rodauth/rack/rails/module.rb
   cat lib/rodauth/rack/rails/app.rb
   cat lib/rodauth/rack/rails/feature.rb
   cat lib/rodauth/rack/rails/feature/base.rb
   ```

2. **Create Hanami structure**:

   ```bash
   mkdir -p lib/rodauth/rack/hanami/feature
   touch lib/rodauth/rack/hanami/{module,app,auth,middleware,feature}.rb
   touch lib/rodauth/rack/hanami/feature/{base,render,csrf,email}.rb
   ```

3. **Follow the implementation guide above**

## Questions to Ask

If you're stuck, ask yourself:

1. **Am I following the feature-based pattern?**
   - Features mix into Rodauth, don't delegate to it

2. **Am I looking at the right reference?**
   - Rails adapter in `lib/rodauth/rack/rails/` is the working example
   - rodauth-rails source in `../../rodauth-rails/` for comparison

3. **Do I understand how this integrates with Rodauth?**
   - Read Rodauth docs: <https://github.com/jeremyevans/rodauth#readme>
   - Understand Rodauth::Feature system

4. **Am I reusing what exists?**
   - Migration templates are framework-agnostic, reuse them
   - Don't recreate what rodauth-rails already solved

## Success Criteria

You'll know you're successful when:

### For Rails Adapter

- [ ] All 41+ tests pass from migrated test suite
- [ ] `rails generate rodauth:install` works in a new Rails app
- [ ] Can register, login, logout in a real Rails app
- [ ] All Rodauth features work (password reset, 2FA, etc.)
- [ ] No namespace errors in logs
- [ ] Documentation is complete

### For Hanami Adapter

- [ ] Feature modules implemented and tested
- [ ] Generators/CLI creates working Hanami app
- [ ] Can authenticate in a real Hanami 2.x app
- [ ] ROM and/or Sequel integration works
- [ ] Documentation is complete

## Getting Help

If you need help:

1. **Review this document** - Most answers are here
2. **Check the issue comments** - Lots of architectural discussion
3. **Read the Rails adapter code** - Working reference implementation
4. **Check Rodauth docs** - Understand the underlying system
5. **Ask specific questions** - Include what you've tried and what's not working

## Final Notes

This is a well-architected project with a clear pattern. The hard part (discovering the feature-based pattern) is done. Now it's execution:

1. **Test the Rails adapter** (make sure it works)
2. **Document it** (so others can use it)
3. **Replicate the pattern** (for Hanami and others)

The feature-based pattern is elegant and proven. Trust it. Follow the Rails adapter as your guide.

Good luck! 🚀
