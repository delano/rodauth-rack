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

Branch:

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
