# Table Guard Feature

Catch missing database tables at startup instead of runtime with configurable validation modes and optional auto-creation in development.

## Installation

```ruby
enable :table_guard
table_guard_mode :raise  # Fail if tables missing (recommended for production)
```

## Configuration

### `table_guard_mode`

Validation behavior when required tables are missing.

**Values:**

- `:silent` / `:skip` / `nil` - Disable validation (debug log only)
- `:warn` - Log warning message and continue execution
- `:error` - Print distinctive message to error log but continue execution
- `:raise` - Log error and raise `Rodauth::ConfigurationError` (recommended for production)
- `:halt` / `:exit` - Log error and exit the process immediately
- Block - Custom handler (receives missing tables array)

**Block Example:**

```ruby
# Custom handler with environment-specific behavior
table_guard_mode do |missing|
  if ENV['RACK_ENV'] == 'production'
    Slack.notify("Missing tables: #{missing.map { |t| t[:table] }.join(', ')}")
    :raise  # Raise error
  else
    :continue  # Just log
  end
end
```

### `table_guard_sequel_mode`

Automatic table creation/management using Sequel migrations.

**Values:**

- `nil` - No automatic creation (default, recommended for production)
- `:create` - Create missing tables
- `:recreate` - Drop and recreate all tables (test environments only)
- `:log` - Output migration code to logs
- `:migration` - Generate migration file

**Examples:**

```ruby
# Development: auto-create for convenience
table_guard_sequel_mode :create

# Test: fresh schema each run
table_guard_sequel_mode :recreate
```

### `table_guard_skip_tables`

Tables to exclude from validation.

```ruby
table_guard_skip_tables [:deprecated_table, :legacy_accounts]
```

### `table_guard_check_columns?`

Validate column names in addition to table existence.

**Values:** `true` (default), `false`

```ruby
table_guard_check_columns? false
```

### `table_guard_migration_path`

Directory for generated migration files.

**Default:** `"db/migrate"`

```ruby
table_guard_migration_path 'db/migrations'
```

## Usage

```ruby
class RodauthApp < Roda
  plugin :rodauth do
    enable :login, :logout, :otp
    enable :table_guard

    case ENV['RACK_ENV']
    when 'production'
      table_guard_mode :raise  # Fail with exception
      table_guard_sequel_mode nil  # Never auto-create in production
    when 'test'
      table_guard_mode :silent  # Don't spam test output
      table_guard_sequel_mode :recreate  # Fresh schema each run
    else  # development
      table_guard_mode :warn  # Helpful warnings
      table_guard_sequel_mode :create  # Auto-create for convenience
    end
  end
end
```

## Introspection Methods

```ruby
# List all required tables
rodauth.list_all_required_tables
# => [:accounts, :account_password_hashes, :account_otp_keys]

# Check status of each table
rodauth.table_status
# => [
#   {method: :accounts_table, table: :accounts, exists: true},
#   {method: :account_password_hashes_table, table: :account_password_hashes, exists: true}
# ]

# Get missing tables
rodauth.missing_tables
# => [{method: :otp_keys_table, table: :account_otp_keys, feature: :otp}]

# Get all table methods (discovery)
rodauth.all_table_methods
# => [:accounts_table, :account_password_hashes_table, ...]

# Check specific table
rodauth.table_exists?(:accounts)  # => true
```

## Sequel Integration

### Idempotent Migrations

Generate migrations using `create_table?` to avoid conflicts:

```ruby
# db/migrate/001_create_rodauth_tables.rb
Sequel.migration do
  up do
    create_table?(:accounts) do
      primary_key :id, type: :Bignum
      String :email, null: false
      Integer :status_id, null: false, default: 1
      index :email, unique: true
    end

    create_table?(:account_password_hashes) do
      foreign_key :id, :accounts, primary_key: true, type: :Bignum
      String :password_hash, null: false
    end
  end

  down do
    drop_table?(:account_password_hashes)
    drop_table?(:accounts)
  end
end
```

### Workflow Pattern

**Development:**

```ruby
# Auto-create tables for fast iteration
table_guard_mode :warn
table_guard_sequel_mode :create
```

**Test:**

```ruby
# Fresh schema each run
table_guard_mode :silent
table_guard_sequel_mode :recreate
```

**Production:**

```ruby
# Validation only, fail fast
table_guard_mode :raise
table_guard_sequel_mode nil  # Never auto-create
```

## Logger Suppression

Table existence checks temporarily suppress Sequel's logger to prevent confusing error logs when checking non-existent tables.

```ruby
# Automatically handled by table_guard
def table_exists?(table_name)
  original_logger = db.loggers.dup
  db.loggers.clear
  db.table_exists?(table_name)
ensure
  db.loggers.clear
  original_logger.each { |logger| db.loggers << logger }
end
```

## Common Errors

```ruby
# Rodauth::ConfigurationError: Missing required database tables!
# - Table: account_otp_keys (feature: otp, method: otp_keys_table)
#
# Fix: Create table or disable feature
enable :login  # Don't enable :otp without table

# SQLite3::SQLException: no such table: accounts
# During migration check - this is expected and suppressed automatically

# Conflict between table_guard and migrations
# Fix: Use idempotent migrations with create_table? not create_table
```

## Database Engine Specificity

**Important**: Migration code generated by table_guard is specific to your currently connected database engine.

### Engine-Specific Features

**PostgreSQL:**

- Uses `citext` extension for case-insensitive email storage
- Adds email validation constraints
- Supports `jsonb` for metadata columns
- Uses partial indexes with WHERE clauses

**MySQL:**

- Uses standard `String` types
- Skips partial indexes (not supported)
- Uses `NULL` defaults for deadline columns (no date arithmetic)

**SQLite:**

- Uses standard `String` types
- Supports partial indexes
- Uses date arithmetic for deadline defaults

### Cross-Database Compatibility

If you generate migrations on one database type but deploy to another:

1. **Generate for your target database** - Connect to the same type as production when generating
2. **Manual adaptation required** - If types differ, review and adapt the generated migration:
   - Change `citext` to `String` when moving PostgreSQL → MySQL/SQLite
   - Remove partial index `WHERE` clauses when moving to MySQL
   - Adjust deadline defaults for MySQL

### Example: Database-Specific Migration

```ruby
# Generated on PostgreSQL
create_table(:accounts) do
  citext :email, null: false                                    # PostgreSQL
  constraint :valid_email, email: /^[^@]+@[^@]+\.[^@]+$/      # PostgreSQL
  index :email, unique: true, where: {status_id: [1, 2]}      # PostgreSQL/SQLite
end

# Adapted for MySQL
create_table(:accounts) do
  String :email, null: false                                    # MySQL
  # constraint removed - MySQL doesn't support CHECK constraints
  index :email, unique: true                                    # MySQL
end
```

### Preview Before Committing

Use `:log` mode to preview migration code before committing:

```ruby
table_guard_sequel_mode :log  # Output to logs
# Review the generated code
# Manually adjust for cross-database compatibility if needed
```
