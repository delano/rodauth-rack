# Sinatra table_guard Demo

This is a barebones Sinatra application demonstrating the `table_guard` feature with various configuration modes.

## Quick Start

### Install Dependencies

```bash
cd examples/sinatra-table-guard
bundle install
```

### Run the Web Server

**Option 1: Using Rack (recommended)**

```bash
bundle exec rackup
# Visit: http://localhost:9292
```

**Option 2: Using Puma**

```bash
bundle exec puma
# Visit: http://localhost:9292
```

**Option 3: Direct Ruby execution**

```bash
ruby app.rb
# Visit: http://localhost:4567
```

The app will start and you'll see `table_guard` logging output in the console showing discovered tables and validation results.

### Interactive Console

**Option 1: Using the console helper**

```bash
bundle exec ruby console.rb
```

**Option 2: Using IRB**

```bash
bundle exec irb -r ./app.rb
```

**Option 3: From rodauth-rack root**

```bash
bin/console -r ./examples/sinatra-table-guard/app.rb
```

Then try these commands:

```ruby
# Create a Rodauth instance
rodauth = RodauthApp.rodauth.allocate
rodauth.send(:initialize, {})

# Get the discovered table configuration
rodauth.table_configuration
# => Hash with all discovered tables and their metadata

# Check which tables are missing
rodauth.missing_tables
# => Array of missing table info

# List all required table names
rodauth.list_all_required_tables
# => ["accounts", "account_verification_keys"]

# Get detailed status for each table
rodauth.table_status
# => Array of hashes with exists: true/false

# Access the database directly
DB.tables
# => List of existing tables

# Check if a specific table exists
rodauth.table_exists?(:accounts)
# => true or false
```

## Configuration Modes

Edit `app.rb` to uncomment different `table_guard_mode` settings and see how they behave:

### Validation Modes

```ruby
# Warn but continue (default in demo)
table_guard_mode :warn

# Error log but continue
table_guard_mode :error

# Raise exception (app won't start if tables missing)
table_guard_mode :raise

# Halt/exit the process
table_guard_mode :halt

# Silent - no logging
table_guard_mode :silent

# Custom handler
table_guard_mode do |missing, config|
  puts "Missing: #{missing.map { |t| t[:table] }.join(', ')}"
  :continue
end
```

### Sequel Generation Modes

```ruby
# Log migration code to console
table_guard_mode :warn
table_guard_sequel_mode :log

# Generate migration file in db/migrate/
table_guard_mode :warn
table_guard_sequel_mode :migration

# Create tables automatically (JIT - dev only!)
table_guard_mode :warn
table_guard_sequel_mode :create

# Drop and recreate (dev/test only!)
table_guard_mode :warn
table_guard_sequel_mode :sync
```

## What to Observe

### Console Output

When you start the app, watch for:

1. **Discovery phase** - table_guard discovers all required tables
2. **Validation phase** - checks which tables exist
3. **Action phase** - based on mode setting (warn, error, create, etc.)

Example output:

```
[10:30:45] DEBUG TableGuard: Discovered 5 required tables
[10:30:45] WARN  Rodauth TableGuard: Missing required database tables!

  - Table: accounts (feature: base, method: accounts_table)
  - Table: account_verification_keys (feature: verify_account, method: verify_account_table)
  - Table: account_otp_keys (feature: otp, method: otp_keys_table)

Migration hints:

Run migrations for these tables:
  - accounts
  - account_otp_keys
  - account_verification_keys

Or enable automatic Sequel generation:
  table_guard_sequel_mode :log        # Log to console
  table_guard_sequel_mode :migration  # Generate migration file
  table_guard_sequel_mode :create     # Create tables now
```

### Browser

The web interface shows:

- Database connection info
- Authentication status
- Links to try authentication flows
- Instructions for console usage
- Guide for trying different modes

## Database

By default, uses SQLite: `rodauth_demo.db` (in this directory)

### Using PostgreSQL

1. Update `Gemfile`:

   ```ruby
   gem "pg", "~> 1.5"
   ```

2. Run with DATABASE_URL:

   ```bash
   DATABASE_URL=postgres://localhost/rodauth_demo bundle exec rackup
   ```

### Using MySQL

1. Update `Gemfile`:

   ```ruby
   gem "mysql2", "~> 0.5"
   ```

2. Run with DATABASE_URL:

   ```bash
   DATABASE_URL=mysql2://localhost/rodauth_demo bundle exec rackup
   ```

## Enabled Features

The demo enables these Rodauth features:

- `:login`
- `:logout`
- `:create_account`
- `:verify_account`
- `:otp`
- `:table_guard`

This configuration creates 3 required tables:

1. `accounts` (from `:base`)
2. `account_verification_keys` (from `:verify_account`)
3. `account_otp_keys` (from `:otp`)

## Testing Different Scenarios

### Scenario 1: Fresh Start (No Tables)

```bash
rm -f rodauth_demo.db
bundle exec rackup
```

You'll see warnings about all missing tables.

### Scenario 2: Auto-Create Tables

Edit `app.rb`:

```ruby
table_guard_mode :warn
table_guard_sequel_mode :create
```

Run the app - tables will be created automatically!

### Scenario 3: Generate Migration

Edit `app.rb`:

```ruby
table_guard_mode :warn
table_guard_sequel_mode :migration
```

Run the app - check `db/migrate/` for generated migration file.

### Scenario 4: Raise on Missing Tables

Edit `app.rb`:

```ruby
table_guard_mode :raise
```

App will fail to start with clear error message.

## Multi-Tenant Use Case

The demo includes a commented example of custom handling for multi-tenant scenarios:

```ruby
table_guard_mode do |missing, config|
  # Log to tenant-specific logger
  TenantLogger.log_missing_tables(current_tenant, missing)

  # Return :continue to not raise, or :error/:raise to fail
  :continue
end
```

This is useful when different tenants might have different features enabled.
