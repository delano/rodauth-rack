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

```
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
