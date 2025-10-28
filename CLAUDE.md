# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Purpose

Framework-agnostic utilities for Rodauth authentication:

1. **External Rodauth Features** - Like `table_guard` for database validation
2. **Sequel Migration Generator** - Generate migrations for 19 Rodauth features

**Not a framework adapter.** For Rails integration, use rodauth-rails. This project demonstrates Rodauth's extensibility and provides reference implementations.

**Status:** Experimental learning project. Not published to RubyGems.

## Development Commands

```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/rodauth/rack/generators/migration_spec.rb

# Run specific test
bundle exec rspec spec/rodauth/rack/generators/migration_spec.rb:50

# Interactive console with helpers
bin/console
```

## Architecture Overview

### Core Components

**lib/rodauth/features/table_guard.rb** - External Rodauth feature

- Uses `Rodauth::Feature.define(:table_guard, :TableGuard)` pattern
- Validates database tables exist for enabled features at `post_configure` time
- Provides introspection methods: `missing_tables`, `table_status`, `list_all_required_tables`
- Configurable modes: `:warn`, `:error`, `:silent`, or custom block handler
- Demonstrates proper feature lifecycle hooks and configuration DSL

**lib/rodauth/rack/generators/migration.rb** - Sequel migration generator

- Generates database migrations for 19 Rodauth features
- Uses ERB templates in `lib/rodauth/rack/generators/migration/sequel/`
- Maps features to table configurations via `CONFIGURATION` hash
- Provides `generate()` for migration content and `configuration()` for Rodauth config
- Mock database adapter pattern when no real DB connection provided

### How Rodauth Features Work

Rodauth features are modules that mix into `Rodauth::Auth` instances:

```ruby
Feature.define(:feature_name, :FeatureName) do
  # Configuration methods (overridable by users)
  auth_value_method :setting_name, 'default_value'

  # Public methods (overridable by users)
  auth_methods :public_method

  # Private methods (not overridable)
  auth_private_methods :internal_helper

  # Lifecycle hook - runs after configuration
  def post_configure
    super if defined?(super)
    # Initialization code
  end
end
```

**Key Pattern:** Methods defined in features become part of the Rodauth instance. Users override them in configuration blocks:

```ruby
plugin :rodauth do
  enable :feature_name

  setting_name 'custom_value'  # Override auth_value_method

  public_method do             # Override auth_methods
    # Custom implementation
  end
end
```

### Table Guard Implementation Details

**Configuration Storage:** Uses instance variables set by `auth_value_method`:

- Block configs stored as Procs in `@table_guard_mode`
- Symbol configs stored directly as `:warn`, `:error`, `:silent`

**Check Strategy:**

1. `should_check_tables?` examines `@table_guard_mode` to decide if checking is needed
2. Returns `true` if mode is a Proc (block), enabling custom handlers
3. Returns `true` if mode is `:warn` or `:error`, `false` for `:silent`

**Execution Flow:**

1. `post_configure` hook calls `check_required_tables!` if `should_check_tables?` returns true
2. `check_required_tables!` gets missing tables via `missing_tables`
3. For symbol modes (`:warn`, `:error`), handles directly
4. For block modes, calls block with missing tables, handles return value (`:error`, `:continue`, String)

**Introspection Methods:**

- `all_table_methods` - Finds all methods ending in `_table` using Ruby reflection
- `missing_tables` - Checks each table method against `db.table_exists?`
- `table_status` - Returns array of hashes with method, table name, and existence status

### Migration Generator Architecture

**Template System:**

- Each feature has ERB template in `lib/rodauth/rack/generators/migration/sequel/`
- Templates use binding from Migration instance for variables like `table_prefix`
- `generate()` loads, evaluates, and concatenates all feature templates

**Configuration Mapping:**

- `CONFIGURATION` hash maps feature names to Rodauth config method names
- Uses `%<plural>s` and `%<singular>s` format strings for table naming
- `configuration()` method interpolates prefix and returns Rodauth config hash

**Database Adapter Pattern:**

- `MockSequelDatabase` simulates database when no real connection provided
- Allows template generation without active database
- Real `Sequel::Database` object can be passed for actual migrations

## Testing Patterns

**RSpec Structure:**

- `spec/spec_helper.rb` - Minimal configuration, loads `rodauth/rack`
- Feature specs test both behavior and configuration
- Migration generator specs verify template output and configuration

**Console Helpers:**

- `setup_test_db` - Creates in-memory SQLite database with tables
- `create_app(db, features: [...])` - Creates Roda app with Rodauth configured
- Useful for interactive testing of table_guard and migration generator

## Documentation Reference

**docs/rodauth-features-api.md** - Complete reference for feature development DSL methods

**docs/rodauth-internals.rdoc** - Object model explanation:

- `Rodauth::Auth` - Authentication class (where features mix in)
- `Rodauth::Configuration` - Configuration DSL class
- `Rodauth::Feature` - Module subclass for feature definitions
- `Rodauth::FeatureConfiguration` - Configuration module for features

**docs/rodauth-mail.md** - Email/SMTP configuration patterns

**DEVELOPMENT.md** - Architectural decisions, standard Rack integration pattern

## Integration Pattern

Rodauth integrates with any Rack app via Roda middleware (NOT via this library):

```ruby
# Create Roda app with Rodauth
class RodauthApp < Roda
  plugin :middleware
  plugin :rodauth do
    enable :login, :logout
    enable :table_guard  # ← Feature from this library
    db DB
  end

  route do |r|
    r.rodauth
    env['rodauth'] = rodauth
  end
end

# Mount as Rack middleware
use RodauthApp
run MyApp
```

Access in your app: `request.env['rodauth']` provides all authentication methods.
