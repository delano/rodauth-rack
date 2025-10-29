# Sinatra table_guard Demo

Barebones Sinatra app demonstrating the `table_guard` feature with dynamic table discovery and validation.

## Quick Start

```bash
cd examples/sinatra-table-guard
bundle install
bundle exec rackup
# Visit: http://localhost:9292
```

Watch the console for table_guard logging!

## Interactive Console

```bash
bundle exec ruby console.rb
```

Helper methods:

- `config` - Get discovered table configuration
- `missing` - Get missing tables
- `show_status` - Pretty-print table status
- `create_tables!` - Create all missing tables
- `show_migration` - Display generated migration code

## Configuration Modes

Edit `app.rb` to try different modes:

```ruby
# Validation modes
table_guard_mode :warn       # Log warnings (default)
table_guard_mode :error      # Log errors
table_guard_mode :raise      # Raise exception
table_guard_mode :halt       # Exit process

# Sequel generation modes
table_guard_sequel_mode :log        # Log migration code
table_guard_sequel_mode :migration  # Generate file in db/migrate/
table_guard_sequel_mode :create     # Create tables immediately (JIT)
table_guard_sequel_mode :sync       # Drop and recreate (dev/test only)

# Custom handler
table_guard_mode do |missing, config|
  # Your logic here
  :continue
end
```

## What You'll See

```plain
[10:30:45] ERROR CRITICAL: Missing Rodauth tables - accounts, account_verification_keys, account_otp_keys

Migration hints:
  table_guard_sequel_mode :create     # Create tables now
```

## Database

Default: SQLite (`db/sinatra_table_guard.db`)

PostgreSQL: `DATABASE_URL=postgres://localhost/rodauth_demo bundle exec rackup`

MySQL: `DATABASE_URL=mysql2://localhost/rodauth_demo bundle exec rackup`
