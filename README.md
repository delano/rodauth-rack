# Rodauth::Tools

Framework-agnostic utilities for [Rodauth](http://rodauth.jeremyevans.net) authentication. Provides external Rodauth features and Sequel migration generators.

> [!WARNING]
> This project is in early alpha. APIs may change significantly. Not ready for prime time.

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

### 1. External Identity Feature

Track external service identifiers (Stripe customer IDs, Redis keys, NoSQL document IDs) in your Rodauth accounts table with automatic helper method generation.

```ruby
class RodauthApp < Roda
  plugin :rodauth do
    enable :login, :external_identity

    # Declare external identity columns
    external_identity_column :stripe, :stripe_customer_id
    external_identity_column :redis, :redis_session_key
    external_identity_column :elasticsearch, :es_document_id
  end

  route do |r|
    r.rodauth
    rodauth.check

    # Use generated helper methods
    stripe_id = rodauth.account_stripe_id        # => "cus_abc123"
    redis_key = rodauth.account_redis_id         # => "session:uuid"
    es_doc = rodauth.account_elasticsearch_id    # => "doc_456"
  end
end
```

**Key Features:**

- Automatic helper method generation (e.g., `account_stripe_id`)
- Auto-includes columns in `account_select` for eager loading
- Introspection API for debugging and testing
- Optional validation of column existence
- Graceful nil handling when account not loaded

**Common Use Cases:**

- Stripe customer ID for subscription management
- Redis session keys for distributed session tracking
- NoSQL document IDs (MongoDB, Elasticsearch, Cassandra)
- External service correlation IDs (Supabase, Firebase, other bases etc.)

**Documentation:** [docs/features/external-identity.md](docs/features/external-identity.md)

### 2. Table Guard External Feature

Validates that required database tables exist for enabled Rodauth features.

```ruby
class RodauthApp < Roda
  plugin :rodauth do
    enable :login, :logout, :otp
    enable :table_guard  # ← Add this

    table_guard_mode :raise  # or :warn, :error, :halt, :silent
  end
end
```

**Modes:**

- `:silent` / `:skip` / `nil` - Disable validation (debug log only)
- `:warn` - Log warning message and continue execution
- `:error` - Print distinctive message to error log but continue execution
- `:raise` - Log error and raise `Rodauth::ConfigurationError` (recommended for production)
- `:halt` / `:exit` - Log error and exit the process immediately
- Block - Custom handler (see below)

**Custom Handlers:**

```ruby
table_guard_mode do |missing|
  if Rails.env.production?
    Slack.notify("Missing tables: #{missing.map { |t| t[:table] }.join(', ')}")
    :raise  # Raise error
  else
    :continue  # Just log and continue
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

### 3. Sequel Migration Generator

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

- **[External Identity Feature](docs/features/external-identity.md)** - Track external service identifiers
- **[Table Guard Feature](docs/features/table-guard.md)** - Validate required database tables
- **[Sequel Migrations](docs/sequel-migrations.md)** - Integrating table_guard with Sequel migrations
- **[Rodauth Feature API](docs/rodauth-features-api.md)** - Complete DSL reference for feature development
- **[Rodauth Internals](docs/references/rodauth-internals.rdoc)** - Object model and metaprogramming patterns
- **[Mail Configuration](docs/rodauth-mail.md)** - Email and SMTP setup

## Related Projects

- [rodauth](https://github.com/jeremyevans/rodauth) - The authentication framework
- [rodauth-rails](https://github.com/janko/rodauth-rails) - Rails integration
- [roda](https://github.com/jeremyevans/roda) - Routing tree web toolkit

## Acknowledgments

- **Migration Templates**: Copied from [rodauth-rails](https://github.com/janko/rodauth-rails) by Janko Marohnić
- **Inspiration**: rodauth-rails' excellent Rails integration

## License

MIT License
