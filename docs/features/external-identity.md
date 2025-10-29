# External Identity Feature

Eliminate boilerplate when managing external service identifiers by declaring columns once and getting automatic helper methods and account_select integration.

## Installation

```ruby
enable :external_identity
external_identity_column :stripe_customer_id
external_identity_column :redis_uuid
```

## Configuration

### `external_identity_column(column, **options)`

Declare an external identity column.

**Parameters:**

- `column` - Database column name (used as-is, no automatic suffixes)
- `options`:
  - `:method_name` - Custom helper method name (default: same as column)
  - `:include_in_select` - Add to account_select (default: `true`)

**Examples:**

```ruby
# Simple - column name used for both column and method
external_identity_column :stripe_customer_id
# => column: :stripe_customer_id, method: :stripe_customer_id

external_identity_column :id_supabase
# => column: :id_supabase, method: :id_supabase

# Custom method name
external_identity_column :redis_key, method_name: :redis_session_key
# => column: :redis_key, method: :redis_session_key

# Exclude from account_select (lazy load pattern)
external_identity_column :heavy_data, include_in_select: false
```

### `external_identity_on_conflict`

Conflict resolution strategy when generated method name already exists.

**Values:** `:error` (default), `:warn`, `:skip`

```ruby
external_identity_on_conflict :warn
```

Use `external_identity_on_conflict` instead of the removed `:override` option.

### `external_identity_check_columns`

Column existence validation mode.

**Values:** `true` (default), `false`, `:autocreate`

- `true` - Validate columns exist, raise error if missing
- `false` - Skip validation entirely
- `:autocreate` - Generate Sequel migration code when columns missing

**Examples:**

```ruby
# Default - validates columns exist
external_identity_check_columns true

# Skip validation (useful during initial development)
external_identity_check_columns false

# Generate migration code for missing columns
external_identity_check_columns :autocreate
```

When `:autocreate` mode detects missing columns, it provides:

- Complete Sequel migration code
- Integration with table_guard if enabled
- Helpful error messages with exact `add_column` statements

## Usage

```ruby
class RodauthApp < Roda
  plugin :rodauth do
    enable :login, :external_identity

    external_identity_column :stripe_customer_id
    external_identity_column :redis_session_key
  end

  route do |r|
    rodauth.check

    # Generated helper methods (match column names)
    stripe_id = rodauth.stripe_customer_id
    redis_key = rodauth.redis_session_key
  end
end
```

## Introspection Methods

```ruby
# List declared columns
rodauth.external_identity_column_list  # => [:stripe_customer_id, :redis_session_key]

# Get column configuration
rodauth.external_identity_column_config(:stripe_customer_id)
# => {column: :stripe_customer_id, method_name: :stripe_customer_id, ...}

# List generated helper methods
rodauth.external_identity_helper_methods  # => [:stripe_customer_id, :redis_session_key]

# Check if column declared
rodauth.external_identity_column?(:stripe_customer_id)  # => true

# Complete status (for debugging)
rodauth.external_identity_status
# => [{name: :stripe_customer_id, column: :stripe_customer_id, value: "cus_123", ...}]
```

## Anti-Patterns

**Don't use external_identity for:**

- Join table replacements (use proper foreign key tables)
- One-to-many relationships (one account, many external records)
- Frequently changing data (denormalization penalty)
- Primary query keys (use indexed tables)
- Sensitive data requiring separate encryption

**Good pattern - simple foreign key references:**

```ruby
external_identity_column :stripe_customer_id

# Lazy load external data
def stripe_customer
  @stripe_customer ||= Stripe::Customer.retrieve(stripe_customer_id)
end
```

## Autocreate Mode

When `external_identity_check_columns` is set to `:autocreate`, missing columns trigger helpful error messages with complete migration code:

```ruby
plugin :rodauth do
  enable :external_identity
  external_identity_check_columns :autocreate

  external_identity_column :stripe_customer_id
  external_identity_column :redis_uuid
end
```

If columns are missing, you'll get:

```text
ArgumentError: External identity columns not found in accounts table: :stripe_customer_id, :redis_uuid

Sequel.migration do
  up do
    alter_table :accounts do
      add_column :stripe_customer_id, String
      add_column :redis_uuid, String
    end
  end

  down do
    alter_table :accounts do
      drop_column :stripe_customer_id
      drop_column :redis_uuid
    end
  end
end
```

Copy this migration code, save to `db/migrate/`, and run with `Sequel::Migrator.run(DB, 'db/migrate')`.

## Validation Errors

```ruby
# ArgumentError: external_identity_column :stripe_customer_id already declared
external_identity_column :stripe_customer_id
external_identity_column :stripe_customer_id  # Duplicate

# ArgumentError: Method name must be a valid Ruby identifier
external_identity_column :stripe_customer_id, method_name: :"123invalid"

# ArgumentError: External identity columns not found in accounts table: :stripe_customer_id
external_identity_check_columns true  # Default behavior
external_identity_column :stripe_customer_id  # Column doesn't exist in database
```

## Layer 2: Extended Features

Layer 2 adds lifecycle callbacks for advanced external identity management.

### Overview

```ruby
external_identity_column :stripe_customer_id,
  # Read-time normalization
  formatter: -> (v) { v.to_s.strip.downcase },

  # Format validation
  validator: -> (v) { v.start_with?('cus_') },

  # Auto-generation during account creation
  before_create_account: -> { Stripe::Customer.create(email: account[:email]).id },

  # Health checks (non-critical)
  verifier: -> (id) {
    customer = Stripe::Customer.retrieve(id)
    customer && !customer.deleted?
  },

  # Security verification (critical)
  handshake: -> (id, token) { session[:oauth_state] == token }
```

### Callback Execution Order

1. `before_create_account` - Generates value before account creation
2. `formatter` - Applied to generated value, then stored
3. `validator` - Validates formatted value (raises on failure)
4. Helper method returns formatted value
5. `verifier` - On-demand health check (returns false on failure)
6. `handshake` - Security verification (raises on failure)

### formatter

Normalizes values at read-time. Applied when accessing via helper method.

```ruby
external_identity_column :stripe_customer_id,
  formatter: -> (v) { v.to_s.strip.downcase }

account[:stripe_customer_id] = "  CUS_ABC123  "
rodauth.stripe_customer_id  # => "cus_abc123"
```

**Common patterns:**

- Strip whitespace: `-> (v) { v.to_s.strip }`
- Lowercase: `-> (v) { v.downcase }`
- Phone normalization: `-> (v) { v.gsub(/\D/, '') }`
- Nil safety: Formatter not called for nil values

### validator

Validates format. Applied during `validate_external_identity` and account creation.

```ruby
external_identity_column :stripe_customer_id,
  formatter: -> (v) { v.strip.downcase },
  validator: -> (v) { v.start_with?('cus_') }

# Validates successfully
rodauth.validate_external_identity(:stripe_customer_id, "  CUS_ABC  ")  # => true

# Raises ArgumentError
rodauth.validate_external_identity(:stripe_customer_id, "invalid")
# => ArgumentError: Invalid format for stripe_customer_id: "invalid"

# Validate all columns
rodauth.validate_all_external_identities
# => {stripe_customer_id: true, github_user_id: true}
```

**Validation rules:**

- Formatter applied before validator
- Nil values skipped
- Raises ArgumentError on failure
- `validate_all_external_identities` stops at first failure

### before_create_account

Generates value during account creation. Runs in `before_create_account` hook.

```ruby
external_identity_column :stripe_customer_id,
  before_create_account: -> {
    Stripe::Customer.create(email: account[:email]).id
  },
  formatter: -> (v) { v.strip.downcase },
  validator: -> (v) { v.start_with?('cus_') }

# During account creation:
# 1. Check if value already set (skip if present)
# 2. Execute generator callback
# 3. Apply formatter to generated value
# 4. Apply validator (raises if invalid)
# 5. Store in account column
```

**Behavior:**

- Skipped if value already set (manual override)
- Skipped if generator returns nil
- Formatter and validator applied to generated value
- Errors prevent account creation

**Example with multiple services:**

```ruby
external_identity_column :stripe_customer_id,
  before_create_account: -> {
    Stripe::Customer.create(email: account[:email]).id
  }

external_identity_column :redis_session_key,
  before_create_account: -> {
    SecureRandom.uuid
  }
```

### verifier

Health check for external record existence. Non-critical - returns false on failure.

```ruby
external_identity_column :stripe_customer_id,
  formatter: -> (v) { v.strip.downcase },
  verifier: -> (id) {
    customer = Stripe::Customer.retrieve(id)
    customer && !customer.deleted?
  }

# On-demand health check
rodauth.verify_external_identity(:stripe_customer_id)  # => true or false

# Verify all columns with verifiers
rodauth.verify_all_external_identities
# => {stripe_customer_id: true, github_user_id: false}
```

**Usage in application:**

```ruby
before_process_payment do
  unless verify_external_identity(:stripe_customer_id)
    throw_error_status(422, :stripe_customer_id, "Customer no longer exists")
  end
end
```

**Error handling:**

- API errors caught and logged (returns false)
- Nil values skipped (returns true)
- Formatter applied before verification
- Returns true if no verifier configured

### handshake

Security-critical verification with token. MUST raise on failure.

```ruby
external_identity_column :github_user_id,
  formatter: -> (v) { v.to_s.strip },
  handshake: -> (github_id, state) {
    session[:oauth_state] == state
  }

# OAuth callback
def github_callback
  code = params['code']
  state = params['state']

  token = Github.exchange_code(code)
  user_info = Github.get_user(token)

  # Raises if state mismatch (CSRF protection)
  if verify_handshake(:github_user_id, user_info['id'], state)
    account[:github_user_id] = user_info['id']
    account.save
  end
end
```

**Security characteristics:**

- MUST raise on failure (secure by default)
- Two-parameter verification (value + token)
- Formatter applied to value before verification
- Returns true if no handshake configured

**Use cases:**

- OAuth state verification (CSRF protection)
- Team invitation token verification
- API signature verification
- Multi-factor authentication
- Any security-critical two-factor verification

**Example with team invites:**

```ruby
external_identity_column :team_id,
  handshake: -> (team_id, invite_token) {
    invite = DB[:team_invites]
      .where(team_id: team_id, token: invite_token, used: false)
      .first

    return false unless invite
    return false if invite[:expires_at] < Time.now

    # Mark invite as used
    DB[:team_invites].where(id: invite[:id]).update(used: true)
    true
  }

# In controller
def accept_invite
  team_id = params['team_id']
  token = params['token']

  # Raises if invalid/expired/used
  verify_handshake(:team_id, team_id, token)

  account[:team_id] = team_id
  account.save
end
```

## Complete Lifecycle Example

```ruby
external_identity_column :stripe_customer_id,
  # 1. Generate during account creation
  before_create_account: -> {
    Stripe::Customer.create(
      email: account[:email],
      metadata: { app: 'myapp' }
    ).id
  },

  # 2. Normalize format
  formatter: -> (v) { v.to_s.strip.downcase },

  # 3. Validate format
  validator: -> (v) { v.start_with?('cus_') && v.length >= 10 },

  # 4. Health check (non-critical)
  verifier: -> (id) {
    customer = Stripe::Customer.retrieve(id)
    customer && !customer.deleted?
  }

# Account creation flow:
create_account(email: 'user@example.com')
# 1. before_create_account generates "cus_ABC123xyz"
# 2. formatter normalizes to "cus_abc123xyz"
# 3. validator confirms format
# 4. Account created with stripe_customer_id = "cus_abc123xyz"

# Later usage:
rodauth.stripe_customer_id  # => "cus_abc123xyz" (formatted)

# Health check before payment:
unless rodauth.verify_external_identity(:stripe_customer_id)
  set_error_flash "Stripe customer deleted"
  redirect '/settings/billing'
end
```

## API Method Reference

### Validation Methods

```ruby
# Validate single column
rodauth.validate_external_identity(:stripe_customer_id, "cus_123")  # => true

# Validate all columns with validators
rodauth.validate_all_external_identities
# => {stripe_customer_id: true, redis_uuid: true}
```

### Verification Methods

```ruby
# Verify single column (health check)
rodauth.verify_external_identity(:stripe_customer_id)  # => true or false

# Verify all columns with verifiers
rodauth.verify_all_external_identities
# => {stripe_customer_id: true, github_user_id: false}
```

### Handshake Methods

```ruby
# Security-critical verification
rodauth.verify_handshake(:github_user_id, "12345", oauth_state)  # => true or raises
```

## Cleanup Patterns

For cleanup workflows (account deletion, GDPR compliance), see the dedicated cookbook:

**[External Identity Cleanup Cookbook](../cookbooks/external-identity-cleanup.md)**

Covers:

- Background job patterns with retries
- Nightly cron for eventual consistency
- GDPR compliance workflows
- Error handling and auditing
