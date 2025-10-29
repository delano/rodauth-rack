# Rodauth::Tools

Framework-agnostic utilities for [Rodauth](http://rodauth.jeremyevans.net) authentication. Provides external Rodauth features and Sequel migration generators.

**Project Status**: Experimental learning project. Not published to RubyGems.

## Overview

Rodauth::Tools provides utilities that work with any Rodauth setup, regardless of framework:

1. **External Rodauth Features** - Like `table_guard` for validating database table setup
2. **Sequel Migration Generator** - Generate Rodauth database migrations for 19 features

This is NOT a framework adapter. For framework integration, use:

- Rails: [rodauth-rails](https://github.com/janko/rodauth-rails)
- Others: Integrate Rodauth directly - [see integration guide](docs/integration.md)

## Installation

Clone this repository:

```bash
git clone https://github.com/delano/rodauth-tools
cd rodauth-tools
bundle install
```

## Features

### 1. Table Guard External Feature

Validates that required database tables exist for enabled Rodauth features.

```ruby
class RodauthApp < Roda
  plugin :rodauth do
    enable :login, :logout, :otp
    enable :table_guard  # ← Add this

    table_guard_mode :warn  # or :error, :silent
  end
end
```

**Modes:**

- `:warn` - Print warnings about missing tables
- `:error` - Raise error if tables are missing (good for production)
- `:silent` - Disable checking
- Block - Custom handler (see below)

**Custom Handlers:**

```ruby
table_guard_mode do |missing|
  if Rails.env.production?
    Slack.notify("Missing tables: #{missing.map { |t| t[:table] }.join(', ')}")
    :error  # Raise error
  else
    :continue  # Just continue
  end
end
```

**Introspection:**

```ruby
rodauth = MyApp.rodauth

# List all required tables
rodauth.list_all_required_tables
# => [:accounts, :account_password_hashes, :account_otp_keys, ...]

# Check status of each table
rodauth.table_status
# => [{method: :accounts_table, table: :accounts, exists: true}, ...]

# Get missing tables
rodauth.missing_tables
# => [{method: :otp_keys_table, table: :account_otp_keys}, ...]
```

### 2. Sequel Migration Generator

Generate database migrations for Rodauth features.

```ruby
require "rodauth/tools"

generator = Rodauth::Tools::Migration.new(
  features: [:base, :verify_account, :otp],
  prefix: "account"  # table prefix (default: "account")
)

# Get migration content
puts generator.generate

# Get Rodauth configuration
puts generator.configuration
# => {
#   accounts_table: :accounts,
#   verify_account_table: :account_verification_keys,
#   otp_keys_table: :account_otp_keys
# }
```

**Supported Features** (19 total):

- `base` - Core accounts table
- `remember` - Remember me functionality
- `verify_account` - Account verification
- `verify_login_change` - Login change verification
- `reset_password` - Password reset
- `email_auth` - Passwordless email authentication
- `otp` - TOTP multifactor authentication
- `otp_unlock` - OTP unlock
- `sms_codes` - SMS codes
- `recovery_codes` - Backup recovery codes
- `webauthn` - WebAuthn keys
- `lockout` - Account lockouts
- `active_sessions` - Session management
- `account_expiration` - Account expiration
- `password_expiration` - Password expiration
- `single_session` - Single session per account
- `audit_logging` - Authentication audit logs
- `disallow_password_reuse` - Password history
- `jwt_refresh` - JWT refresh tokens

## Console

Interactive console for testing:

```bash
bin/console
```

Example session:

```ruby
db = setup_test_db
app = create_app(db, features: [:login, :otp])
rodauth = app.rodauth

rodauth.list_all_required_tables
rodauth.table_status
rodauth.missing_tables
```

## Development

```bash
# Run tests
bundle exec rspec

# Run console
bin/console
```

## Architecture

**What this project is:**

- Collection of framework-agnostic Rodauth utilities
- External Rodauth features (using `Rodauth::Feature.define`)
- Migration generators for Sequel ORM

**What this project is NOT:**

- A framework adapter (use rodauth-rails for Rails)
- A replacement for Rodauth itself
- Published as a gem (it's a learning/reference project)

## Documentation

### Guides

- **[Multi-Datastore Authentication](docs/guides/multi-datastore-auth.md)** - Patterns for synchronizing Rodauth (SQL) with application datastores (Redis, NoSQL)
  - Simple sync, idempotent sync, and event-driven approaches
  - Decision flowchart and CAP theorem tradeoffs
  - Testing strategies and security considerations

- **[Sequel Migrations](docs/sequel-migrations.md)** - Integrating table_guard with Sequel migrations
  - Idempotent migration patterns
  - Environment-specific configuration
  - Using table_guard to validate external datastores

### Examples

- **[OneTimeSecret Sync Pattern](docs/examples/onetimesecret-sync-pattern.md)** - Production-grade session synchronization
  - Real-world implementation with idempotency, graceful degradation, and correlation tracking
  - Lessons learned and performance characteristics

### API Reference

- **[Rodauth Feature API](docs/rodauth-features-api.md)** - Complete DSL reference for feature development
- **[Rodauth Internals](docs/rodauth-internals.rdoc)** - Object model and metaprogramming patterns
- **[Mail Configuration](docs/rodauth-mail.md)** - Email and SMTP setup

### Architecture Decisions

- **[ADR 001: No session_glue Feature](docs/adr/001-no-session-glue-feature.md)** - Why multi-datastore sync is application-level, not framework-level

## Related Projects

- [rodauth](https://github.com/jeremyevans/rodauth) - The authentication framework
- [rodauth-rails](https://github.com/janko/rodauth-rails) - Rails integration
- [roda](https://github.com/jeremyevans/roda) - Routing tree web toolkit

## Acknowledgments

- **Migration Templates**: Copied from [rodauth-rails](https://github.com/janko/rodauth-rails) by Janko Marohnić
- **Inspiration**: rodauth-rails' excellent Rails integration

## License

MIT License
