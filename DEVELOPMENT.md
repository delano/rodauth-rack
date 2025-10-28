# Development Guide - rodauth-rack

**Last Updated:** 2025-10-27
**Branch:** `feature/22-simplify`
**Status:** Simplified to framework-agnostic utilities

## Project Overview

This project provides **framework-agnostic utilities** for Rodauth:

1. **External Rodauth Features** - Like `table_guard` for database validation
2. **Sequel Migration Generator** - Generate migrations for Rodauth features

This is NOT a framework adapter or integration layer. For framework integration:

- **Rails**: Use [rodauth-rails](https://github.com/janko/rodauth-rails)
- **Other frameworks**: Use Rodauth's standard Rack integration pattern (documented below)

## Architectural Decision: Simplification

### What We Removed (commit 20941b7)

Previously, this project attempted to create framework adapters (Rails, Hanami, Sinatra). We removed all of this because:

1. **Maintenance burden** - Each adapter required framework-specific code
2. **Duplication** - rodauth-rails already exists and is mature
3. **Unnecessary complexity** - Rodauth works with any Rack app without custom adapters

### Current Architecture

```text
rodauth-rack/
├── lib/
│   ├── rodauth/
│   │   └── features/
│   │       └── table_guard.rb          # External feature
│   └── rodauth/rack/
│       ├── generators/
│       │   └── migration.rb            # Migration generator
│       └── version.rb
```

## How Rodauth Integration Actually Works

Rodauth is built on Roda. When you load Roda's `:middleware` plugin, Roda can act as Rack middleware. The official pattern is:

### Standard Rack Integration Pattern

```ruby
# config.ru
require 'roda'
require 'rodauth'

# Create a Roda app with Rodauth configured
class RodauthApp < Roda
  plugin :middleware
  plugin :rodauth do
    enable :login, :logout, :create_account

    # Database
    db DB

    # Configuration
    accounts_table :users
    login_redirect '/dashboard'
  end

  route do |r|
    r.rodauth
    rodauth.require_authentication
    env['rodauth'] = rodauth  # Make available to main app
  end
end

# Mount Rodauth as Rack middleware
use RodauthApp

# Run your main application
run MyApp
```

### Accessing Rodauth in Your Application

The `env['rodauth']` object provides all authentication methods:

```ruby
# In your Sinatra app
class MyApp < Sinatra::Base
  helpers do
    def rodauth
      request.env['rodauth']
    end
  end

  get '/dashboard' do
    rodauth.require_authentication
    erb :dashboard, locals: { user_id: rodauth.account_id }
  end
end

# In plain Rack
class MyApp
  def call(env)
    @rodauth = env['rodauth']

    return @rodauth.require_authentication unless @rodauth.logged_in?

    [200, {}, ["Welcome, user #{@rodauth.account_id}"]]
  end
end
```

## Rodauth Feature Development Pattern

When creating external Rodauth features (like `table_guard`), follow this pattern:

```ruby
# lib/rodauth/features/my_feature.rb
module Rodauth
  Feature.define(:my_feature, :MyFeature) do
    # Configuration methods (can be overridden by users)
    auth_value_method :my_setting, 'default_value'

    # Public methods (can be overridden by users)
    auth_methods(
      :public_method,
      :another_public_method
    )

    # Private methods (cannot be overridden)
    auth_private_methods(
      :internal_helper
    )

    # Lifecycle hook
    def post_configure
      super if defined?(super)
      # Initialization code
    end

    # Public method implementation
    def public_method
      # Feature logic
    end

    private

    def internal_helper
      # Internal implementation
    end
  end
end
```

### Key Points

1. **Feature modules mix into Rodauth instances** - Methods become part of the auth object
2. **Use auth_methods/auth_value_methods** - Makes methods configurable
3. **Private methods use auth_private_methods** - Cannot be overridden
4. **post_configure for initialization** - Runs after configuration is complete

## Migration Generator

The migration generator creates Sequel migrations for Rodauth features:

```ruby
require 'rodauth/rack'

generator = Rodauth::Rack::Generators::Migration.new(
  features: [:base, :verify_account, :reset_password],
  prefix: 'account'
)

# Generate migration SQL
puts generator.generate

# Get configuration
config = generator.configuration
# => {
#   accounts_table: :accounts,
#   verify_account_table: :account_verification_keys,
#   reset_password_table: :account_password_reset_keys
# }
```

## Testing

Run the test suite:

```bash
bundle exec rspec
```

Interactive console for testing:

```bash
bin/console
```

## Common Patterns

### Framework Integration Documentation

Instead of building adapters, we document how to integrate Rodauth with different frameworks:

**Sinatra:**

```ruby
# config.ru
use RodauthApp
run Sinatra::Application
```

**Hanami:**

```ruby
# config.ru
use RodauthApp
run Hanami.app
```

**Rails:**

Use the [rodauth-rails](https://github.com/janko/rodauth-rails) gem - it provides deep Rails integration.

### Creating External Features

External features can:

- Validate configuration (like `table_guard`)
- Add utility methods to Rodauth
- Integrate with external services
- Provide debugging/introspection

They should NOT:

- Require framework-specific code
- Modify Rodauth's core behavior
- Break compatibility with standard Rodauth

## Why Not Framework Adapters?

We experimented with framework adapters but found:

1. **rodauth-rails already exists** - Mature, well-maintained Rails integration
2. **Standard pattern works fine** - Mounting Roda middleware is straightforward
3. **Each framework is different** - Generic adapters don't provide enough value
4. **Maintenance burden** - Keeping up with framework changes is expensive

Instead, we provide:

- **External features** - Work with any Rodauth setup
- **Migration generators** - Framework-agnostic database setup
- **Documentation** - How to integrate Rodauth with popular frameworks

## Resources

- [Rodauth Documentation](https://rodauth.jeremyevans.net/documentation.html)
- [Rodauth Internals](docs/rodauth-internals.rdoc) - How Rodauth is built
- [Rodauth Feature API](docs/rodauth-features-api.md) - Feature development reference
- [rodauth-rails](https://github.com/janko/rodauth-rails) - Rails integration example
