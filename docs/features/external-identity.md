# External Identity Feature

## Table of Contents

- [Introduction](#introduction)
- [Quick Start](#quick-start)
- [Use Cases](#use-cases)
- [Configuration Reference](#configuration-reference)
- [Usage Examples](#usage-examples)
- [Introspection API](#introspection-api)
- [Database Setup](#database-setup)
- [Advanced Patterns](#advanced-patterns)
- [Troubleshooting](#troubleshooting)
- [API Reference](#api-reference)

## Introduction

The `external_identity` feature provides a clean, declarative way to integrate external service identifiers into your Rodauth authentication system. It automatically:

- Generates helper methods for accessing external IDs (e.g., `account_stripe_id`)
- Adds columns to `account_select` for automatic loading
- Provides introspection methods for debugging and testing
- Validates column existence in the database

### What This Feature Does

Store and access external service identifiers (Stripe customer IDs, Redis UUIDs, Elasticsearch document IDs, etc.) alongside your Rodauth account records without manual boilerplate.

**Before:**

```ruby
# Manual approach - lots of boilerplate
def stripe_customer_id
  account[:stripe_customer_id]
end

def account_select
  super + [:stripe_customer_id, :redis_uuid, :auth0_id]
end
```

**After:**

```ruby
# With external_identity - declarative and automatic
enable :external_identity
external_identity_column :stripe, :stripe_customer_id
external_identity_column :redis, :redis_uuid
external_identity_column :auth0, :auth0_id

# Helper methods generated automatically:
# - rodauth.account_stripe_id
# - rodauth.account_redis_id
# - rodauth.account_auth0_id
```

### When to Use This Feature

Use `external_identity` when you need to:

- Store foreign keys to external services (Stripe, Auth0, Firebase)
- Track UUIDs for distributed systems (Redis, Elasticsearch, Cassandra)
- Maintain correlation IDs between Rodauth (SQL) and NoSQL datastores
- Access external identifiers consistently across your application

### When NOT to Use This Feature

**Do NOT use** `external_identity` if:

1. **You need to JOIN on external identifiers** - Use a proper join table instead
2. **The relationship is one-to-many** - One account, many external records (use separate table)
3. **The data changes frequently** - Denormalized storage in accounts table is inefficient
4. **You need to query BY the external ID** - Add proper indexes and use direct database queries
5. **The external ID is sensitive** - Store in separate table with encryption at rest

### The Right Pattern: One-to-One Simple References

```ruby
# GOOD: One-to-one references for lazy loading
enable :external_identity
external_identity_column :stripe, :stripe_customer_id

# In your app - lazy load from Stripe
def stripe_customer
  @stripe_customer ||= Stripe::Customer.retrieve(account_stripe_id)
end
```

### The Wrong Pattern: Join Table Replacement

```ruby
# BAD: Don't replace proper join tables
# If you need to query subscriptions, use a real table!
create_table :stripe_subscriptions do
  foreign_key :account_id, :accounts
  String :stripe_subscription_id, null: false
  String :status
  DateTime :current_period_end
  index :stripe_subscription_id, unique: true
end
```

## Quick Start

### Minimal Working Example

```ruby
# 1. Enable feature
class RodauthApp < Roda
  plugin :rodauth do
    enable :login, :external_identity

    # 2. Declare external identity columns
    external_identity_column :stripe  # Default: column = :stripe_id
    external_identity_column :redis   # Default: column = :redis_id
  end

  route do |r|
    r.rodauth
    rodauth.check

    # 3. Use generated helper methods
    stripe_id = rodauth.account_stripe_id   # => "cus_abc123"
    redis_key = rodauth.account_redis_id    # => "550e8400-..."
  end
end
```

### Database Migration

```ruby
# db/migrate/002_add_external_identities.rb
Sequel.migration do
  up do
    alter_table(:accounts) do
      add_column :stripe_id, String
      add_column :redis_id, String

      add_index :stripe_id, unique: true
      add_index :redis_id, unique: true
    end
  end

  down do
    alter_table(:accounts) do
      drop_column :stripe_id
      drop_column :redis_id
    end
  end
end
```

## Use Cases

### 1. Stripe Integration

Store Stripe customer ID for subscription management:

```ruby
plugin :rodauth do
  enable :create_account, :external_identity

  external_identity_column :stripe, :stripe_customer_id

  after_create_account do
    # Create Stripe customer after account creation
    customer = Stripe::Customer.create(
      email: account[:email],
      metadata: { rodauth_id: account_id }
    )

    # Store Stripe ID in account
    db[:accounts].where(id: account_id).update(
      stripe_customer_id: customer.id
    )
  end
end

# In your app - lazy load Stripe customer
def stripe_customer
  @stripe_customer ||= begin
    return nil unless account_stripe_id
    Stripe::Customer.retrieve(account_stripe_id)
  end
end

def active_subscription?
  customer = stripe_customer
  return false unless customer

  customer.subscriptions.data.any? { |sub| sub.status == 'active' }
end
```

### 2. Multi-Datastore Session Sync

Synchronize Rodauth sessions with Redis:

```ruby
plugin :rodauth do
  enable :login, :active_sessions, :external_identity

  external_identity_column :redis, :redis_session_key

  after_login do
    # Create Redis session tracking
    redis_key = "session:#{account_id}:#{SecureRandom.uuid}"
    redis.setex(redis_key, 86400, {
      account_id: account_id,
      login_at: Time.now.to_i,
      ip_address: request.ip
    }.to_json)

    # Store Redis key in account
    db[:accounts].where(id: account_id).update(
      redis_session_key: redis_key
    )
  end

  after_logout do
    # Remove Redis session
    redis.del(account_redis_id) if account_redis_id

    # Clear from account
    db[:accounts].where(id: account_id).update(
      redis_session_key: nil
    )
  end
end

# Check active sessions across datastores
def active_session?
  # Check both SQL and Redis
  return false unless session_exists?  # Rodauth's active_sessions check
  return false unless account_redis_id

  redis.exists(account_redis_id)
end
```

### 3. Multiple External Services

Track identifiers for multiple external systems:

```ruby
plugin :rodauth do
  enable :external_identity

  # Payment processor
  external_identity_column :stripe, :stripe_customer_id

  # Search indexing
  external_identity_column :elasticsearch, :es_document_id

  # Authentication provider (federated auth)
  external_identity_column :auth0, :auth0_user_id

  # Analytics tracking
  external_identity_column :segment, :segment_anonymous_id

  # Customer support
  external_identity_column :zendesk, :zendesk_user_id
end

# Sync all external services after account update
after_update_account do
  sync_to_elasticsearch if account_elasticsearch_id
  sync_to_segment if account_segment_id
  notify_zendesk_of_update if account_zendesk_id
end
```

### 4. NoSQL Correlation IDs

Bridge between SQL (Rodauth) and NoSQL (application data):

```ruby
plugin :rodauth do
  enable :external_identity

  external_identity_column :mongodb, :mongo_user_id
  external_identity_column :cassandra, :cassandra_user_uuid

  after_create_account do
    # Create MongoDB user document
    mongo_id = MongoDB.users.insert_one(
      rodauth_account_id: account_id,
      email: account[:email],
      created_at: Time.now,
      preferences: {},
      activity_log: []
    ).inserted_id.to_s

    # Store correlation ID
    db[:accounts].where(id: account_id).update(
      mongo_user_id: mongo_id
    )
  end
end

# Access NoSQL data via correlation ID
def user_preferences
  return {} unless account_mongodb_id

  MongoDB.users.find_one(_id: BSON::ObjectId(account_mongodb_id))[:preferences]
end
```

## Configuration Reference

### `external_identity_column`

Declares an external identity column with automatic helper method generation.

```ruby
external_identity_column(name, column = nil, **options)
```

**Parameters:**

- `name` (Symbol) - Identity name (must be valid Ruby identifier)
- `column` (Symbol, optional) - Database column name (default: `"#{name}_id"`)
- `options` (Hash) - Configuration options

**Options:**

- `:method_name` (Symbol) - Custom helper method name (default: `"account_#{name}_id"`)
- `:include_in_select` (Boolean) - Add to `account_select` (default: `true`)
- `:override` (Boolean) - Override existing method (default: `false`)
- `:validate` (Boolean) - Validate column exists in database (default: `false`)

**Examples:**

```ruby
# Default naming: :stripe → :stripe_id → account_stripe_id
external_identity_column :stripe

# Explicit column name
external_identity_column :stripe, :stripe_customer_id

# Custom method name
external_identity_column :stripe, method_name: :stripe_customer_id

# Exclude from account_select (lazy load when needed)
external_identity_column :elasticsearch, include_in_select: false

# Validate column exists (fail at startup if missing)
external_identity_column :stripe, validate: true
```

**Validation:**

- Name must be a Symbol
- Name must be a valid Ruby identifier (`/^[a-z_][a-z0-9_]*$/i`)
- Method name must be a valid Ruby identifier (can include `?` `!` `=` at end)
- Cannot declare the same name twice
- Column validation only runs if `:validate` option is true OR `external_identity_validate_columns` is true

**Generated Methods:**

Each declaration creates a helper method:

```ruby
external_identity_column :stripe

# Generated method:
def account_stripe_id
  account ? account[:stripe_id] : nil
end
```

### `external_identity_on_conflict`

Defines conflict resolution strategy when helper method already exists.

```ruby
external_identity_on_conflict :error  # Default
```

**Values:**

- `:error` - Raise error if method exists (default, safest)
- `:warn` - Warn and skip method generation
- `:skip` - Silently skip method generation
- `:override` - Override existing method (dangerous)

**Example:**

```ruby
plugin :rodauth do
  enable :external_identity

  # Global policy: warn on conflicts
  external_identity_on_conflict :warn

  # Per-column override
  external_identity_column :stripe, override: true
end
```

### `external_identity_validate_columns`

Enable validation of all declared columns at startup.

```ruby
external_identity_validate_columns true
```

**Default:** `false` (validation disabled)

**When enabled:**

- Checks all declared columns exist in `accounts_table` during `post_configure`
- Raises `ArgumentError` if any columns are missing
- Provides helpful error message listing missing columns
- Recommended for production to fail fast on misconfiguration

**Example:**

```ruby
plugin :rodauth do
  enable :external_identity

  if ENV['RACK_ENV'] == 'production'
    # Validate in production - fail at startup if misconfigured
    external_identity_validate_columns true
  end

  external_identity_column :stripe
  external_identity_column :redis
end
```

**Error Message:**

```
ArgumentError: External identity columns not found in accounts table:
stripe (stripe_id), redis (redis_id). Add columns to database or set validate: false
```

## Usage Examples

### Example 1: Simple Single External ID

Track Redis session key:

```ruby
# Configuration
plugin :rodauth do
  enable :external_identity
  external_identity_column :redis, :redis_session_key
end

# After login - create Redis session
after_login do
  session_key = "session:#{account_id}:#{SecureRandom.uuid}"
  redis.setex(session_key, 86400, session_data.to_json)

  db[:accounts].where(id: account_id).update(
    redis_session_key: session_key
  )
end

# In your app - check Redis session
def redis_session_active?
  return false unless account_redis_id
  redis.exists(account_redis_id)
end
```

### Example 2: Multiple External IDs

Integrate with Stripe, Redis, and Elasticsearch:

```ruby
plugin :rodauth do
  enable :external_identity

  # Payment processing
  external_identity_column :stripe, :stripe_customer_id

  # Session management
  external_identity_column :redis, :redis_session_key

  # Search indexing (lazy load - not in account_select)
  external_identity_column :elasticsearch, :es_document_id,
                          include_in_select: false
end

# Access methods
rodauth.account_stripe_id          # Always loaded
rodauth.account_redis_id           # Always loaded
rodauth.account_elasticsearch_id   # Lazy loaded when accessed

# Helper methods for external service integration
def sync_to_elasticsearch
  return unless account_elasticsearch_id

  Elasticsearch.update_document(
    index: 'users',
    id: account_elasticsearch_id,
    body: { email: account[:email], updated_at: Time.now }
  )
end

def delete_from_elasticsearch
  return unless account_elasticsearch_id

  Elasticsearch.delete_document(
    index: 'users',
    id: account_elasticsearch_id
  )
end
```

### Example 3: Custom Method Names

Create domain-specific method names:

```ruby
plugin :rodauth do
  enable :external_identity

  external_identity_column :stripe, :stripe_customer_id,
                          method_name: :stripe_customer_id

  external_identity_column :stripe_connect, :stripe_connect_account_id,
                          method_name: :stripe_connect_id

  external_identity_column :redis, :redis_session_key,
                          method_name: :redis_session_key
end

# Usage with cleaner names
rodauth.stripe_customer_id    # Not account_stripe_id
rodauth.stripe_connect_id     # Not account_stripe_connect_id
rodauth.redis_session_key     # Not account_redis_id
```

### Example 4: Exclude from account_select

Lazy load expensive external data only when needed:

```ruby
plugin :rodauth do
  enable :external_identity

  # Always load (default)
  external_identity_column :stripe, :stripe_customer_id

  # Lazy load only when needed
  external_identity_column :elasticsearch, :es_document_id,
                          include_in_select: false

  external_identity_column :analytics, :segment_user_id,
                          include_in_select: false
end

# Helper to load when needed
def elasticsearch_document
  return @elasticsearch_document if defined?(@elasticsearch_document)

  # Load column from database on first access
  account_id = self.account_id
  es_id = db[:accounts].where(id: account_id).get(:es_document_id)

  @elasticsearch_document = if es_id
                              Elasticsearch.get_document('users', es_id)
                            end
end
```

### Example 5: Validation Patterns

Ensure data integrity with validation:

```ruby
plugin :rodauth do
  enable :external_identity

  # Development: No validation (tables might not exist yet)
  if ENV['RACK_ENV'] == 'development'
    external_identity_validate_columns false
  end

  # Production: Strict validation (fail fast)
  if ENV['RACK_ENV'] == 'production'
    external_identity_validate_columns true
  end

  external_identity_column :stripe, :stripe_customer_id
  external_identity_column :redis, :redis_session_key
end

# Manual validation in application code
def ensure_stripe_customer_exists!
  return if account_stripe_id

  # Create Stripe customer if missing
  customer = Stripe::Customer.create(
    email: account[:email],
    metadata: { rodauth_id: account_id }
  )

  db[:accounts].where(id: account_id).update(
    stripe_customer_id: customer.id
  )
end
```

### Example 6: Error Handling

Handle missing or invalid external IDs gracefully:

```ruby
# Safe access with nil checks
def stripe_customer
  return nil unless account_stripe_id

  @stripe_customer ||= begin
    Stripe::Customer.retrieve(account_stripe_id)
  rescue Stripe::InvalidRequestError => e
    # Handle deleted/invalid customer ID
    logger.error "Invalid Stripe customer ID: #{account_stripe_id} - #{e.message}"

    # Clear invalid ID
    db[:accounts].where(id: account_id).update(
      stripe_customer_id: nil
    )

    nil
  end
end

# Graceful degradation for Redis session
def redis_session_data
  return {} unless account_redis_id

  data = redis.get(account_redis_id)
  data ? JSON.parse(data) : {}
rescue Redis::BaseError => e
  logger.warn "Redis error for session #{account_redis_id}: #{e.message}"
  {}  # Fallback to empty session data
end
```

## Introspection API

The feature provides five introspection methods for debugging, testing, and runtime inspection.

### `external_identity_column_list`

Returns array of declared identity names.

```ruby
rodauth.external_identity_column_list
# => [:stripe, :redis, :elasticsearch]
```

**Use Cases:**

- List all external integrations
- Iterate over all external IDs
- Debugging configuration

**Example:**

```ruby
# Debug: Show all external IDs for account
def debug_external_identities
  rodauth.external_identity_column_list.map do |name|
    config = rodauth.external_identity_column_config(name)
    method_name = config[:method_name]
    value = rodauth.send(method_name)

    "#{name}: #{value || 'nil'}"
  end.join(", ")
end
# => "stripe: cus_abc123, redis: nil, elasticsearch: doc_456"
```

### `external_identity_column_config(name)`

Returns configuration hash for specific identity.

```ruby
rodauth.external_identity_column_config(:stripe)
# => {
#   column: :stripe_customer_id,
#   method_name: :account_stripe_id,
#   include_in_select: true,
#   override: false,
#   validate: false,
#   options: {...}
# }
```

**Returns:** `Hash` or `nil` if not found

**Use Cases:**

- Inspect configuration at runtime
- Conditional logic based on configuration
- Testing and validation

**Example:**

```ruby
# Check if column should be in select
def should_load_stripe_id?
  config = rodauth.external_identity_column_config(:stripe)
  config && config[:include_in_select]
end

# Get all auto-loaded external IDs
def auto_loaded_external_ids
  rodauth.external_identity_column_list.select do |name|
    config = rodauth.external_identity_column_config(name)
    config[:include_in_select]
  end
end
```

### `external_identity_helper_methods`

Returns array of all generated helper method names.

```ruby
rodauth.external_identity_helper_methods
# => [:account_stripe_id, :account_redis_id, :account_elasticsearch_id]
```

**Use Cases:**

- Check which methods are available
- Introspection for metaprogramming
- Testing helper method generation

**Example:**

```ruby
# Check if specific helper method exists
def stripe_integration_enabled?
  rodauth.external_identity_helper_methods.include?(:account_stripe_id)
end

# Call all helper methods dynamically
def all_external_ids
  rodauth.external_identity_helper_methods.map do |method|
    [method, rodauth.send(method)]
  end.to_h
end
# => {
#   account_stripe_id: "cus_abc123",
#   account_redis_id: "session:123:uuid",
#   account_elasticsearch_id: nil
# }
```

### `external_identity_column?(name)`

Check if an identity has been declared.

```ruby
rodauth.external_identity_column?(:stripe)      # => true (name)
rodauth.external_identity_column?(:stripe_id)   # => true (column)
rodauth.external_identity_column?(:unknown)     # => false
```

**Parameters:**

- `name` (Symbol) - Identity name OR column name

**Returns:** `Boolean`

**Use Cases:**

- Guard clauses in application logic
- Conditional feature enablement
- Testing

**Example:**

```ruby
# Conditional sync based on feature availability
def sync_to_stripe
  return unless rodauth.external_identity_column?(:stripe)
  return unless rodauth.account_stripe_id

  Stripe::Customer.update(
    rodauth.account_stripe_id,
    email: account[:email]
  )
end

# Guard against accessing undeclared identities
def safe_external_id(name)
  return nil unless rodauth.external_identity_column?(name)

  config = rodauth.external_identity_column_config(name)
  rodauth.send(config[:method_name])
end
```

### `external_identity_status`

Returns complete status information for all declared identities.

```ruby
rodauth.external_identity_status
# => [
#   {
#     name: :stripe,
#     column: :stripe_customer_id,
#     method: :account_stripe_id,
#     value: "cus_abc123",
#     present: true,
#     in_select: true,
#     in_account: true,
#     column_exists: true
#   },
#   {
#     name: :redis,
#     column: :redis_session_key,
#     method: :account_redis_id,
#     value: nil,
#     present: false,
#     in_select: true,
#     in_account: true,
#     column_exists: true
#   }
# ]
```

**Returns:** `Array<Hash>` with keys:

- `:name` - Identity name (Symbol)
- `:column` - Database column name (Symbol)
- `:method` - Helper method name (Symbol)
- `:value` - Current value (String or nil)
- `:present` - Boolean: value is not nil
- `:in_select` - Boolean: included in `account_select`
- `:in_account` - Boolean: key exists in loaded account hash
- `:column_exists` - Boolean: column exists in database schema

**Use Cases:**

- Debugging external identity configuration
- Health checks and monitoring
- Testing and validation
- Console interrogation

**Example:**

```ruby
# Console debugging
$ bin/console
> rodauth = MyApp.rodauth
> rodauth.external_identity_status.each do |status|
>   puts "#{status[:name]}: #{status[:value] || 'nil'} (column_exists: #{status[:column_exists]})"
> end
# stripe: cus_abc123 (column_exists: true)
# redis: nil (column_exists: true)
# elasticsearch: doc_456 (column_exists: false)

# Health check endpoint
get '/health/external_identities' do
  status = rodauth.external_identity_status

  missing_columns = status.reject { |s| s[:column_exists] }
  if missing_columns.any?
    halt 500, {
      error: "Missing columns",
      missing: missing_columns.map { |s| s[:column] }
    }.to_json
  end

  { status: 'ok', identities: status }.to_json
end

# Test helper
def assert_external_identities_configured!
  status = rodauth.external_identity_status

  status.each do |s|
    raise "Column missing: #{s[:column]}" unless s[:column_exists]
    raise "Not in select: #{s[:column]}" if s[:include_in_select] && !s[:in_select]
  end
end
```

## Database Setup

### Migration Examples

#### PostgreSQL

```ruby
# db/migrate/002_add_external_identities.rb
Sequel.migration do
  up do
    alter_table(:accounts) do
      # Stripe integration
      add_column :stripe_customer_id, String
      add_index :stripe_customer_id, unique: true

      # Redis session tracking
      add_column :redis_session_key, String
      add_index :redis_session_key, unique: true

      # Elasticsearch document ID
      add_column :es_document_id, String
      add_index :es_document_id, unique: true

      # Auth0 federated identity
      add_column :auth0_user_id, String
      add_index :auth0_user_id, unique: true
    end
  end

  down do
    alter_table(:accounts) do
      drop_column :stripe_customer_id
      drop_column :redis_session_key
      drop_column :es_document_id
      drop_column :auth0_user_id
    end
  end
end
```

#### MySQL

```ruby
Sequel.migration do
  up do
    alter_table(:accounts) do
      add_column :stripe_customer_id, String, size: 255
      add_column :redis_session_key, String, size: 255

      add_index :stripe_customer_id, unique: true
      add_index :redis_session_key, unique: true
    end
  end

  down do
    alter_table(:accounts) do
      drop_column :stripe_customer_id
      drop_column :redis_session_key
    end
  end
end
```

#### SQLite

```ruby
Sequel.migration do
  up do
    alter_table(:accounts) do
      add_column :stripe_customer_id, String
      add_column :redis_session_key, String
    end

    # SQLite requires separate statements for indexes
    run 'CREATE UNIQUE INDEX accounts_stripe_customer_id_idx ON accounts(stripe_customer_id)'
    run 'CREATE UNIQUE INDEX accounts_redis_session_key_idx ON accounts(redis_session_key)'
  end

  down do
    alter_table(:accounts) do
      drop_column :stripe_customer_id
      drop_column :redis_session_key
    end
  end
end
```

### Adding Columns to Existing Accounts Table

If your accounts table already exists:

```ruby
# Step 1: Add columns
Sequel.migration do
  up do
    alter_table(:accounts) do
      add_column :stripe_customer_id, String unless columns.include?(:stripe_customer_id)
      add_column :redis_session_key, String unless columns.include?(:redis_session_key)
    end

    # Add indexes if they don't exist
    alter_table(:accounts) do
      add_index :stripe_customer_id, unique: true unless indexes.key?(:accounts_stripe_customer_id_index)
      add_index :redis_session_key, unique: true unless indexes.key?(:accounts_redis_session_key_index)
    end
  end

  down do
    alter_table(:accounts) do
      drop_column :stripe_customer_id
      drop_column :redis_session_key
    end
  end
end
```

### Column Naming Conventions

**Recommended patterns:**

```ruby
# Service + type
:stripe_customer_id    # Stripe customer identifier
:stripe_connect_id     # Stripe Connect account identifier
:auth0_user_id         # Auth0 user identifier

# Service + purpose
:redis_session_key     # Redis session key
:es_document_id        # Elasticsearch document ID
:mongo_user_id         # MongoDB user document ID

# Generic + service
:external_id           # Generic external identifier
:correlation_id        # Cross-system correlation ID
```

**Avoid:**

```ruby
# Too generic
:external_id           # Which external system?
:uuid                  # UUID for what?

# Too specific (implementation details)
:stripe_cus_abc123     # This is a value, not a column name
```

### Indexing Strategy

**Always index external IDs:**

```ruby
# Unique indexes for one-to-one relationships
add_index :stripe_customer_id, unique: true

# Non-unique if same external ID can belong to multiple accounts
add_index :auth0_organization_id, unique: false

# Composite index for multi-tenant scenarios
add_index [:tenant_id, :external_user_id], unique: true
```

**Why index?**

- Query performance when looking up by external ID
- Data integrity (unique constraint prevents duplicates)
- Foreign key-like validation (ensure consistency)

## Advanced Patterns

### Pattern 1: Lazy Loading External Data

Only fetch external data when explicitly needed:

```ruby
plugin :rodauth do
  enable :external_identity

  # Don't auto-load expensive IDs
  external_identity_column :elasticsearch, :es_document_id,
                          include_in_select: false

  external_identity_column :stripe, :stripe_customer_id,
                          include_in_select: false
end

# Lazy load with memoization
def stripe_customer
  return @stripe_customer if defined?(@stripe_customer)
  return @stripe_customer = nil unless account_stripe_id

  @stripe_customer = Stripe::Customer.retrieve(account_stripe_id)
rescue Stripe::InvalidRequestError
  @stripe_customer = nil
end

def elasticsearch_document
  return @es_document if defined?(@es_document)

  # Load ID from database only when needed
  es_id = db[:accounts].where(id: account_id).get(:es_document_id)
  return @es_document = nil unless es_id

  @es_document = Elasticsearch.get_document('users', es_id)
end
```

### Pattern 2: Idempotent External ID Assignment

Ensure external IDs are set exactly once:

```ruby
def ensure_stripe_customer_id!
  return account_stripe_id if account_stripe_id

  # Create Stripe customer
  customer = Stripe::Customer.create(
    email: account[:email],
    metadata: { rodauth_id: account_id, created_at: Time.now.to_i }
  )

  # Store ID atomically (use UPDATE ... WHERE to prevent race conditions)
  updated = db[:accounts]
    .where(id: account_id, stripe_customer_id: nil)
    .update(stripe_customer_id: customer.id)

  if updated > 0
    # Successfully set
    account[:stripe_customer_id] = customer.id
    customer.id
  else
    # Another process already set it - fetch and return
    db[:accounts].where(id: account_id).get(:stripe_customer_id)
  end
end
```

### Pattern 3: Multi-Tenant External Identities

Handle per-tenant external service accounts:

```ruby
# accounts table schema:
# - tenant_id (integer)
# - stripe_customer_id (string)
# - stripe_connect_account_id (string, per-tenant Stripe Connect)

plugin :rodauth do
  enable :external_identity

  external_identity_column :stripe, :stripe_customer_id
  external_identity_column :stripe_connect, :stripe_connect_account_id
end

# Use tenant-scoped Stripe API key
def stripe_customer
  return nil unless account_stripe_id

  # Get tenant's Stripe Connect account
  connect_id = account_stripe_connect_id
  return nil unless connect_id

  Stripe::Customer.retrieve(
    account_stripe_id,
    stripe_account: connect_id  # Tenant-specific
  )
end
```

### Pattern 4: Correlation ID for Event Sourcing

Track account across event streams:

```ruby
plugin :rodauth do
  enable :external_identity

  external_identity_column :event_stream, :event_correlation_id

  after_create_account do
    # Generate correlation ID for event sourcing
    correlation_id = SecureRandom.uuid

    db[:accounts].where(id: account_id).update(
      event_correlation_id: correlation_id
    )

    # Publish account creation event
    EventBus.publish('account.created', {
      correlation_id: correlation_id,
      account_id: account_id,
      email: account[:email],
      created_at: Time.now
    })
  end
end

# Publish events with correlation ID
def publish_account_event(event_type, data = {})
  EventBus.publish(event_type, {
    correlation_id: account_event_stream_id,
    account_id: account_id,
    timestamp: Time.now.to_i
  }.merge(data))
end
```

### Pattern 5: When NOT to Use This Feature

**Use a join table instead** when you need:

```ruby
# BAD: One-to-many relationship stored in accounts table
external_identity_column :stripe_subscription  # Which subscription?

# GOOD: Proper join table
create_table :stripe_subscriptions do
  primary_key :id
  foreign_key :account_id, :accounts, null: false
  String :stripe_subscription_id, null: false, unique: true
  String :status, null: false
  DateTime :current_period_end

  index :account_id
  index :stripe_subscription_id, unique: true
end

# Query subscriptions properly
def active_subscriptions
  db[:stripe_subscriptions]
    .where(account_id: account_id, status: 'active')
    .all
end
```

**Use encrypted storage** for sensitive external IDs:

```ruby
# BAD: Sensitive API key in accounts table
external_identity_column :openai_api_key

# GOOD: Separate encrypted secrets table
create_table :account_secrets do
  primary_key :id
  foreign_key :account_id, :accounts, null: false, unique: true
  String :encrypted_openai_api_key
  String :openai_api_key_iv

  index :account_id, unique: true
end
```

### Pattern 6: Testing Recommendations

Test external identity integration:

```ruby
# RSpec example
RSpec.describe "External Identity Integration" do
  let(:db) { Sequel.sqlite }
  let(:app) { create_test_app(db) }
  let(:rodauth) { app.rodauth }

  before do
    # Create accounts table with external identity columns
    db.create_table :accounts do
      primary_key :id
      String :email, null: false, unique: true
      String :stripe_customer_id
      String :redis_session_key
    end
  end

  it "generates helper methods" do
    expect(rodauth).to respond_to(:account_stripe_id)
    expect(rodauth).to respond_to(:account_redis_id)
  end

  it "includes columns in account_select" do
    expect(rodauth.account_select).to include(:stripe_customer_id, :redis_session_key)
  end

  it "returns values when account is loaded" do
    db[:accounts].insert(
      email: 'test@example.com',
      stripe_customer_id: 'cus_abc123'
    )

    rodauth.instance_variable_set(:@account, db[:accounts].first)
    expect(rodauth.account_stripe_id).to eq('cus_abc123')
  end

  it "returns nil when account is not loaded" do
    expect(rodauth.account_stripe_id).to be_nil
  end

  describe "introspection" do
    it "provides complete status information" do
      status = rodauth.external_identity_status

      expect(status).to be_an(Array)
      expect(status.length).to eq(2)

      stripe_status = status.find { |s| s[:name] == :stripe }
      expect(stripe_status[:column]).to eq(:stripe_customer_id)
      expect(stripe_status[:column_exists]).to be true
    end
  end
end
```

### Pattern 7: Performance Considerations

**Minimize columns in account_select:**

```ruby
# BAD: Auto-load all external IDs (increases query size)
external_identity_column :stripe
external_identity_column :elasticsearch
external_identity_column :analytics
external_identity_column :zendesk
external_identity_column :intercom
# Result: SELECT id, email, stripe_id, es_id, analytics_id, zendesk_id, intercom_id FROM accounts

# GOOD: Only auto-load frequently used IDs
external_identity_column :stripe  # Used on every request

# Lazy load rarely used IDs
external_identity_column :elasticsearch, include_in_select: false
external_identity_column :analytics, include_in_select: false
external_identity_column :zendesk, include_in_select: false

# Result: SELECT id, email, stripe_id FROM accounts (smaller, faster)
```

**Index external IDs for query performance:**

```ruby
# If you query by external ID, always add an index
alter_table(:accounts) do
  add_index :stripe_customer_id, unique: true
  add_index :redis_session_key, unique: true
end

# Fast lookup by external ID
account = db[:accounts].where(stripe_customer_id: 'cus_abc123').first
```

## Troubleshooting

### Problem: Method name conflicts

**Error:**

```
WARNING: external_identity method :account_stripe_id conflicts with existing method
```

**Cause:** Helper method name already defined by another feature or custom code.

**Solution 1:** Use custom method name

```ruby
external_identity_column :stripe, method_name: :stripe_customer_id
```

**Solution 2:** Override conflict resolution

```ruby
external_identity_on_conflict :override
external_identity_column :stripe  # Will override existing method
```

### Problem: Column not found in database

**Error:**

```
ArgumentError: External identity columns not found in accounts table:
stripe (stripe_customer_id). Add columns to database or set validate: false
```

**Cause:** Column doesn't exist in database, but validation is enabled.

**Solution 1:** Add migration

```ruby
Sequel.migration do
  up do
    alter_table(:accounts) do
      add_column :stripe_customer_id, String
      add_index :stripe_customer_id, unique: true
    end
  end
end
```

**Solution 2:** Disable validation temporarily

```ruby
# Development: Disable validation
external_identity_validate_columns false
external_identity_column :stripe
```

### Problem: Helper method returns nil unexpectedly

**Symptom:** `rodauth.account_stripe_id` returns `nil` but column has value in database.

**Causes:**

1. Column not included in `account_select`
2. Account not loaded yet
3. Column excluded via `include_in_select: false`

**Solution:**

```ruby
# Check status
status = rodauth.external_identity_status.find { |s| s[:name] == :stripe }
puts "In select: #{status[:in_select]}"
puts "In account: #{status[:in_account]}"
puts "Column exists: #{status[:column_exists]}"

# Fix 1: Ensure column is in select
external_identity_column :stripe, include_in_select: true

# Fix 2: Manually load column if needed
def account_stripe_id
  return account[:stripe_customer_id] if account

  # Load from database if account not loaded
  db[:accounts].where(id: account_id).get(:stripe_customer_id)
end
```

### Problem: Feature load order issues

**Error:**

```
NoMethodError: undefined method `account_select' for #<Rodauth::Auth>
```

**Cause:** `external_identity` feature loaded before base features.

**Solution:** Enable base features first

```ruby
# BAD
enable :external_identity
enable :login

# GOOD
enable :login
enable :external_identity
```

### Problem: Missing columns warning on startup

**Warning:**

```
[external_identity] WARNING: Columns stripe (stripe_customer_id) marked for
inclusion but not in account_select. This may indicate a configuration order issue.
```

**Cause:** Another feature or custom code overriding `account_select` incorrectly.

**Solution:** Call super when overriding

```ruby
# BAD - loses external_identity columns
def account_select
  [:id, :email]  # Doesn't call super
end

# GOOD - preserves external_identity columns
def account_select
  super + [:custom_column]
end
```

## API Reference

### Configuration Methods

#### `external_identity_column(name, column = nil, **options)`

Declares an external identity column.

**Parameters:**

- `name` (Symbol) - Identity name
- `column` (Symbol, optional) - Database column name (default: `"#{name}_id"`)
- `options` (Hash) - Configuration options
  - `:method_name` (Symbol) - Helper method name (default: `"account_#{name}_id"`)
  - `:include_in_select` (Boolean) - Add to account_select (default: `true`)
  - `:override` (Boolean) - Override existing method (default: `false`)
  - `:validate` (Boolean) - Validate column exists (default: `false`)

**Returns:** `nil`

**Raises:**

- `ArgumentError` - Invalid name or duplicate declaration

#### `external_identity_on_conflict(value)`

Sets conflict resolution strategy.

**Parameters:**

- `value` (Symbol) - `:error`, `:warn`, `:skip`, or `:override`

**Default:** `:error`

#### `external_identity_validate_columns(value)`

Enables/disables column validation.

**Parameters:**

- `value` (Boolean)

**Default:** `false`

### Instance Methods

#### `external_identity_column_list`

Returns list of declared identity names.

**Returns:** `Array<Symbol>`

#### `external_identity_column_config(name)`

Returns configuration for specific identity.

**Parameters:**

- `name` (Symbol) - Identity name

**Returns:** `Hash` or `nil`

#### `external_identity_helper_methods`

Returns list of generated helper method names.

**Returns:** `Array<Symbol>`

#### `external_identity_column?(name)`

Checks if identity is declared.

**Parameters:**

- `name` (Symbol) - Identity name or column name

**Returns:** `Boolean`

#### `external_identity_status`

Returns complete status information.

**Returns:** `Array<Hash>` with keys:

- `:name` (Symbol) - Identity name
- `:column` (Symbol) - Database column name
- `:method` (Symbol) - Helper method name
- `:value` (String, nil) - Current value
- `:present` (Boolean) - Value is not nil
- `:in_select` (Boolean) - Included in account_select
- `:in_account` (Boolean) - Key exists in account hash
- `:column_exists` (Boolean) - Column exists in database

### Generated Helper Methods

For each declaration, a helper method is created:

```ruby
external_identity_column :stripe  # Creates: account_stripe_id

def account_stripe_id
  account ? account[:stripe_id] : nil
end
```

**Returns:** `String`, `nil`, or column value type

**Safe:** Always returns `nil` when account not loaded (no errors)
