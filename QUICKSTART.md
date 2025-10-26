# Quick Start for New Developers

**Read DEVELOPMENT.md for full context. This is a TL;DR.**

## Critical: Feature-Based Pattern, NOT Adapter Delegation

**WRONG (don't do this):**

```ruby
class Rodauth::Rack::Adapter::Framework
  def method
    # Delegate to framework
  end
end
```

**RIGHT (do this):**

```ruby
Rodauth::Feature.define(:framework) do
  auth_class_eval do
    # Methods mix into Rodauth instance
  end
end
```

## Current Status

Branch: `feature/3-rails-adapter`

✅ **Done:**

- Rails adapter core migrated (77 files)
- All feature modules implemented
- All generators migrated
- Namespace transformations complete

⏳ **TODO (Priority Order):**

1. Migrate test suite: `../../rodauth-rails/test/` → `test/rails/` (2-3 days)
2. Integration test with real Rails app (1 day)
3. Update documentation (1 day)

## File Structure

```
lib/rodauth/rack/rails/
├── module.rb              # Main Rails module
├── app.rb                 # Roda app (Rails-specific)
├── auth.rb                # Auth defaults (Rails-specific)
├── middleware.rb          # Rails middleware wrapper
├── feature.rb             # Feature definition
└── feature/               # Feature modules (mix into Rodauth)
    ├── base.rb
    ├── render.rb
    ├── csrf.rb
    ├── email.rb
    ├── callbacks.rb
    ├── instrumentation.rb
    └── internal_request.rb
```

## Immediate Next Steps

### Continue Rails Adapter (Issue #3)

```bash
# 1. Migrate test suite
cp -r ../../rodauth-rails/test/* test/rails/

# 2. Update test_helper.rb
# Change: require "rodauth-rails"
# To: require "rodauth/rack/rails"

# 3. Update namespaces in tests
# Rodauth::Rails → Rodauth::Rack::Rails

# 4. Run tests
bundle exec rake test

# 5. Fix failures (mostly namespace issues)

# 6. Integration test
rails new test_app
cd test_app
# Add to Gemfile: gem 'rodauth-rack', path: '../rodauth-rack'
rails generate rodauth:install
rails s
```

### Start Hanami Adapter (Issue #4)

```bash
# 1. Study Rails adapter
cat lib/rodauth/rack/rails/{module,app,auth,feature}.rb

# 2. Create structure
mkdir -p lib/rodauth/rack/hanami/feature
touch lib/rodauth/rack/hanami/{module,app,auth,middleware,feature}.rb
touch lib/rodauth/rack/hanami/feature/{base,render,csrf,email}.rb

# 3. Follow feature-based pattern (see DEVELOPMENT.md)
```

## Key References

- `lib/rodauth/rack/rails/` - Working Rails adapter (your reference)
- `../../rodauth-rails/` - Original implementation (for comparison)
- `DEVELOPMENT.md` - Complete guide
- Issue #3, #4, #5, #6 - All updated with architectural context

## One-Minute Architecture Lesson

**How it works:**

1. Rails loads Railtie → adds middleware
2. Middleware creates Roda app with Rodauth
3. Roda app enables `:rails` feature
4. Feature modules mix into Rodauth instance
5. Rodauth methods now use Rails (views, CSRF, email, etc.)

**Example:**

```ruby
# lib/rodauth/rack/rails/feature/csrf.rb
module Rodauth::Rack::Rails::Feature::CSRF
  def csrf_token
    # This method mixes into Rodauth instance
    rails_controller.send(:form_authenticity_token)
  end
end

# When Rodauth calls csrf_token:
# 1. Method exists on Rodauth instance (via mixin)
# 2. Returns Rails CSRF token
# 3. No delegation, direct access
```

## Common Mistakes to Avoid

1. ❌ Don't create adapter classes
2. ❌ Don't try to extract App/Auth/Middleware to core (they're framework-specific)
3. ❌ Don't recreate migration templates (reuse `lib/rodauth/rack/generators/migration/`)
4. ✅ DO follow the Rails adapter pattern
5. ✅ DO use feature modules that mix in
6. ✅ DO read DEVELOPMENT.md for details

## Need Help?

1. Read `DEVELOPMENT.md` (comprehensive guide)
2. Check issue comments (#3, #4, #5, #6)
3. Study `lib/rodauth/rack/rails/` (working example)
4. Read Rodauth docs: <https://github.com/jeremyevans/rodauth>

## Success = Tests Pass

Your work is done when:

- [ ] All tests pass
- [ ] Real Rails app works with `rails generate rodauth:install`
- [ ] Can authenticate (login, logout, password reset, etc.)
- [ ] No errors in logs

That's it. Now go read `DEVELOPMENT.md` for the full story.
