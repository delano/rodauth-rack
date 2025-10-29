# External Identity Feature

Store external service identifiers (Stripe customer IDs, Redis keys, NoSQL document IDs) in your Rodauth accounts table with automatic helper method generation.

## Installation

```ruby
enable :external_identity
external_identity_column :stripe, :stripe_customer_id
external_identity_column :redis, :redis_uuid
```

## Configuration

### `external_identity_column(name, column = nil, **options)`

Declare an external identity column.

**Parameters:**

- `name` - Symbol identifier (`:stripe`, `:redis`, etc.)
- `column` - Database column name (defaults to `:"#{name}_id"`)
- `options`:
  - `:method_name` - Custom helper method name (default: `:"account_#{name}_id"`)
  - `:include_in_select` - Add to account_select (default: `true`)
  - `:validate` - Validate column exists (default: `false`)
  - `:override` - Allow method override (default: `false`)

**Examples:**

```ruby
# Default naming: :stripe → :stripe_id column → account_stripe_id method
external_identity_column :stripe

# Explicit column name
external_identity_column :stripe, :stripe_customer_id

# Custom method name
external_identity_column :redis, :redis_key, method_name: :redis_session_key

# Exclude from account_select (lazy load pattern)
external_identity_column :heavy_data, :large_json, include_in_select: false
```

### `external_identity_on_conflict`

Conflict resolution strategy when generated method name already exists.

**Values:** `:error` (default), `:warn`, `:skip`, `:override`

```ruby
external_identity_on_conflict :warn
```

### `external_identity_validate_columns`

Validate columns exist in database during `post_configure`.

**Values:** `true`, `false` (default)

```ruby
external_identity_validate_columns true
```

## Usage

```ruby
class RodauthApp < Roda
  plugin :rodauth do
    enable :login, :external_identity

    external_identity_column :stripe, :stripe_customer_id
    external_identity_column :redis, :redis_session_key
  end

  route do |r|
    rodauth.check

    # Generated helper methods
    stripe_id = rodauth.account_stripe_id
    redis_key = rodauth.account_redis_id
  end
end
```

## Introspection Methods

```ruby
# List declared columns
rodauth.external_identity_column_list  # => [:stripe, :redis]

# Get column configuration
rodauth.external_identity_column_config(:stripe)
# => {column: :stripe_customer_id, method_name: :account_stripe_id, ...}

# List generated helper methods
rodauth.external_identity_helper_methods  # => [:account_stripe_id, :account_redis_id]

# Check if column declared
rodauth.external_identity_column?(:stripe)  # => true

# Complete status (for debugging)
rodauth.external_identity_status
# => [{name: :stripe, column: :stripe_customer_id, value: "cus_123", ...}]
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
external_identity_column :stripe, :stripe_customer_id

# Lazy load external data
def stripe_customer
  @stripe_customer ||= Stripe::Customer.retrieve(account_stripe_id)
end
```

## Validation Errors

```ruby
# ArgumentError: external_identity_column :foo already declared
external_identity_column :foo
external_identity_column :foo  # Duplicate

# ArgumentError: Method name must be a valid Ruby identifier
external_identity_column :foo, method_name: :"123invalid"

# ArgumentError: External identity columns not found in accounts table: foo (foo_id)
external_identity_validate_columns true
external_identity_column :foo  # Column doesn't exist in database
```
