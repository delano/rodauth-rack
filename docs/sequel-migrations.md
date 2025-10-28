# Integrating table_guard with Sequel Migrations

This guide explains how to use table_guard alongside Sequel::Migrator without conflicts.

## TL;DR - Recommended Pattern

**Development:** table_guard auto-creates tables for convenience
**Production:** Sequel migrations are the source of truth, table_guard validates only

```ruby
# In your Rodauth configuration:
plugin :rodauth do
  enable :login, :table_guard

  if ENV['RACK_ENV'] == 'production'
    table_guard_mode :raise  # Fail if tables missing
    table_guard_sequel_mode nil  # Never auto-create
  else
    table_guard_mode :warn  # Helpful warnings
    table_guard_sequel_mode :create  # Auto-create in dev
  end
end
```

## The Problem

When you use both table_guard and Sequel::Migrator, you may encounter conflicts:

1. **table_guard** runs during Rodauth configuration (early in app startup)
2. **Sequel::Migrator** runs during app warmup (after configuration)
3. If table_guard creates tables, then migrations try to create the same tables → **ERROR**

## The Solution: Idempotent Migrations

Generate migrations using `create_table?` instead of `create_table`:

```ruby
# db/migrate/001_create_rodauth_tables.rb
Sequel.migration do
  up do
    # Use create_table? - skips if table already exists
    create_table?(:accounts) do
      primary_key :id, type: :Bignum
      String :email, null: false
      Integer :status, null: false, default: 1
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

**Benefits:**

- Safe to run multiple times
- Works whether tables exist or not
- No conflict between table_guard and migrations
- Production-safe

## Generating Migrations from table_guard

### Step 1: Configure table_guard to log migration code

```ruby
plugin :rodauth do
  enable :login, :verify_account
  enable :table_guard

  table_guard_mode :warn
  table_guard_sequel_mode :log  # Outputs migration code to logs
end
```

### Step 2: Start your app and copy the migration

```bash
bundle exec rackup
# Check logs for migration code
# Copy the generated Sequel.migration block
```

### Step 3: Save as a migration file

```bash
# Create migration file (use sequential numbering)
cat > db/migrate/001_create_rodauth_tables.rb <<'RUBY'
# frozen_string_literal: true

# Paste the migration code from logs here
Sequel.migration do
  up do
    create_table?(:accounts) do
      # ... generated code
    end
  end

  down do
    drop_table?(:accounts)
  end
end
RUBY
```

**Note:** table_guard generates idempotent migrations by default (using `create_table?`).

### Alternative: Generate migration file automatically

```ruby
plugin :rodauth do
  enable :table_guard

  table_guard_mode :warn
  table_guard_sequel_mode :migration  # Creates file in db/migrate/
  table_guard_migration_path 'db/migrate'
end
```

This creates: `db/migrate/20241027123456_create_rodauth_tables.rb`

## Environment-Specific Configuration

### Development: Convenience First

```ruby
if ENV['RACK_ENV'] == 'development'
  # Auto-create tables for fast iteration
  table_guard_mode :warn
  table_guard_sequel_mode :create

  # Optional: Skip if migrations directory has files
  # migrations_exist = Dir['db/migrate/*.rb'].any?
  # table_guard_sequel_mode migrations_exist ? nil : :create
end
```

### Test: Fresh Schema Each Run

```ruby
if ENV['RACK_ENV'] == 'test'
  table_guard_mode :silent
  table_guard_sequel_mode :recreate  # Drop and recreate everything
end
```

### Production: Validation Only

```ruby
if ENV['RACK_ENV'] == 'production'
  table_guard_mode :raise  # Fail loudly if tables missing
  table_guard_sequel_mode nil  # NEVER auto-create
end
```

### Complete Example

```ruby
plugin :rodauth do
  enable :login, :logout, :create_account
  enable :table_guard

  db DB

  # Environment-aware configuration
  case ENV['RACK_ENV']
  when 'production'
    table_guard_mode :raise  # Deployment fails if tables missing
    table_guard_sequel_mode nil  # Migrations handle creation

  when 'test'
    table_guard_mode :silent  # Don't spam test output
    table_guard_sequel_mode :recreate  # Fresh DB each run

  else # development
    table_guard_mode :warn  # Helpful feedback
    table_guard_sequel_mode :create  # Convenience
  end
end
```

## How Sequel Tracks Migrations

Sequel uses different tracking methods based on migration naming:

### Integer Migrations (Simple)

```bash
db/migrate/
  001_create_accounts.rb
  002_add_otp.rb
  003_add_webauthn.rb
```

**Tracking:** Single `schema_info` table with version number

```sql
CREATE TABLE schema_info (version INTEGER DEFAULT 0 NOT NULL);
-- After running migration 003: version = 3
```

### Timestamp Migrations (Parallel-Safe)

```bash
db/migrate/
  20241027120000_create_accounts.rb
  20241027150000_add_otp.rb
  20241028100000_add_webauthn.rb
```

**Tracking:** `schema_migrations` table with individual filenames

```sql
CREATE TABLE schema_migrations (filename VARCHAR(255) PRIMARY KEY);
-- After running migrations:
-- INSERT INTO schema_migrations VALUES ('20241027120000_create_accounts.rb');
-- INSERT INTO schema_migrations VALUES ('20241027150000_add_otp.rb');
```

## Migration Workflow

### When Adding a New Rodauth Feature

```ruby
# 1. Enable the feature
plugin :rodauth do
  enable :login, :otp  # NEW: added :otp
  enable :table_guard

  table_guard_mode :warn
  table_guard_sequel_mode :log  # See what tables are needed
end

# 2. Start app - logs show OTP table schema
# 3. Create migration file: db/migrate/004_add_otp_tables.rb
# 4. Run migration: Sequel::Migrator.run(DB, 'db/migrate')
# 5. Commit both: config change + migration file
# 6. Deploy: migrations run automatically
```

### When Removing a Rodauth Feature

```ruby
# 1. Remove from config
plugin :rodauth do
  enable :login  # REMOVED: :otp
end

# 2. Create down migration to drop tables
# db/migrate/005_remove_otp_tables.rb
Sequel.migration do
  down do
    drop_table?(:account_otp_keys)
  end
end

# 3. Or keep tables but exclude from validation
table_guard_skip_tables [:account_otp_keys]
```

## Safety Checklist

Before deploying to production:

- [ ] All Rodauth tables have corresponding migrations
- [ ] Migrations use `create_table?` for idempotency
- [ ] Production config uses `table_guard_mode :raise`
- [ ] Production config has `table_guard_sequel_mode nil`
- [ ] Migrations tested in staging environment
- [ ] Down migrations work (for rollback)

## Troubleshooting

### Problem: "table already exists" error from migration

**Cause:** Migration uses `create_table` (not `create_table?`) and table exists

**Solution:** Change to `create_table?` in migration:

```ruby
# Before (fails if table exists)
create_table(:accounts) do
  # ...
end

# After (safe if table exists)
create_table?(:accounts) do
  # ...
end
```

### Problem: table_guard and migrations have different schemas

**Cause:** Migration was hand-written instead of generated from table_guard

**Solution:** Always generate migrations from table_guard:

```bash
# Set table_guard_sequel_mode :log
# Start app, copy output
# Or use table_guard_sequel_mode :migration to auto-generate
```

### Problem: Foreign key error when creating tables

**Cause:** Tables created in wrong order (feature table before accounts table)

**Solution:** table_guard automatically orders tables by dependency. Use its output:

```ruby
# table_guard creates in correct order:
# 1. accounts (primary table)
# 2. account_password_hashes (references accounts)
# 3. account_verification_keys (references accounts)
```

## Advanced: Skipping Migrations if Tables Exist

If you want migrations to only run when needed:

```ruby
# In your deployment script
def run_migrations
  return if all_tables_exist?

  Sequel::Migrator.run(DB, 'db/migrate', use_transactions: true)
end

def all_tables_exist?
  required = [:accounts, :account_password_hashes, :account_verification_keys]
  required.all? { |table| DB.table_exists?(table) }
end
```

**However:** This is NOT recommended. Migrations should always run - they're idempotent with `create_table?`.

## Best Practices

1. **Use idempotent migrations** - Always use `create_table?` and `drop_table?`
2. **Generate from table_guard** - Don't hand-write Rodauth table schemas
3. **Environment-specific config** - Auto-create in dev, validate in prod
4. **Sequential numbering** - Use `001_`, `002_`, etc. for clear ordering
5. **Commit migrations** - Always commit migration files with config changes
6. **Test migrations** - Run in staging before production
7. **Document dependencies** - Comment why tables are ordered a certain way

## Further Reading

- [Rodauth Documentation](https://rodauth.jeremyevans.net/documentation.html)
- [Sequel Migration Documentation](http://sequel.jeremyevans.net/rdoc/files/doc/migration_rdoc.html)
- [table_guard Feature Documentation](../lib/rodauth/features/table_guard.rb)
