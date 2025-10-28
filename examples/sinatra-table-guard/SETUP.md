# Setup Guide for table_guard Demo

This document provides a quick setup guide for running the demo application.

## Files in This Directory

```
sinatra-table-guard/
├── Gemfile              # Dependencies for this demo
├── config.ru            # Rack configuration
├── app.rb              # Main Sinatra application
├── console.rb          # Interactive console with helpers
├── README.md           # Full documentation
├── SETUP.md            # This file
└── .gitignore          # Excludes database and migrations
```

## Prerequisites

- Ruby 3.0+ (check: `ruby -v`)
- Bundler (check: `bundle -v`)

## Installation

### 1. Install Dependencies

```bash
cd examples/sinatra-table-guard
bundle install
```

This installs:

- Sinatra (web framework)
- Roda (Rodauth foundation)
- Sequel (database toolkit)
- Rodauth (authentication)
- SQLite3 (database)
- Puma (web server)

### 2. Choose Your Adventure

#### Option A: See Warnings (Default Behavior)

The demo is pre-configured to show warnings about missing tables:

```bash
bundle exec rackup
```

Visit: <http://localhost:9292>

**Expected console output:**

```
[10:30:45] WARN  Rodauth TableGuard: Missing required database tables!
  - Table: accounts (feature: base, method: accounts_table)
  - Table: account_verification_keys (feature: verify_account, method: verify_account_table)
  - Table: account_otp_keys (feature: otp, method: otp_keys_table)
```

#### Option B: Auto-Create Tables

Edit `app.rb` and uncomment:

```ruby
table_guard_sequel_mode :create
```

Then run:

```bash
bundle exec rackup
```

Tables will be created automatically!

#### Option C: Generate Migration

Edit `app.rb` and uncomment:

```ruby
table_guard_sequel_mode :migration
```

Then run:

```bash
bundle exec rackup
```

Check `db/migrate/` for the generated migration file.

## Console Exploration

### Quick Console

```bash
bundle exec ruby console.rb
```

This starts IRB with helper methods pre-loaded.

### Example Session

```ruby
$ bundle exec ruby console.rb

🚀 Rodauth table_guard Console
======================================================================

Quick start:
  rodauth = RodauthApp.rodauth.allocate
  rodauth.send(:initialize, {})
  rodauth.table_configuration
  rodauth.missing_tables
======================================================================

irb(main):001> rodauth = RodauthApp.rodauth.allocate
irb(main):002> rodauth.send(:initialize, {})
irb(main):003> rodauth.table_configuration.keys
=> [:accounts_table, :verify_account_table]

irb(main):004> rodauth.missing_tables.size
=> 2

irb(main):005> rodauth.missing_tables
=> [{:method=>:accounts_table, :table=>"accounts", :feature=>:base, :structure=>{...}},
    {:method=>:verify_account_table, :table=>"account_verification_keys", :feature=>:verify_account, :structure=>{...}}]

irb(main):006> rodauth.table_status
=> [{:method=>:accounts_table, :table=>"accounts", :feature=>:base, :exists=>false},
    {:method=>:verify_account_table, :table=>"account_verification_keys", :feature=>:verify_account, :exists=>false}]
```

## Testing Different Modes

### 1. Fresh Start (No Tables)

```bash
rm -f rodauth_demo.db
bundle exec rackup
```

You'll see warnings about all missing tables.

### 2. With Tables Already Created

```bash
# First time: creates tables
bundle exec ruby console.rb
> create_tables!

# Second time: no warnings
bundle exec rackup
```

### 3. Raise Exception Mode

Edit `app.rb`:

```ruby
table_guard_mode :raise
```

Run:

```bash
bundle exec rackup
```

App will fail to start with exception (as expected).

### 4. Custom Handler

Edit `app.rb` and uncomment the custom handler example, then run the app.

## Troubleshooting

### "Cannot load such file -- rodauth/features/table_guard"

The demo requires the rodauth-rack library. Make sure you're in the rodauth-rack project directory.

### "Database locked" (SQLite)

Stop any running instances of the app before starting a new one.

### Port 9292 already in use

```bash
# Use a different port
bundle exec rackup -p 9393
```

## Next Steps

- Try different `table_guard_mode` settings in `app.rb`
- Try different `table_guard_sequel_mode` settings
- Explore the console helpers
- Add/remove features to see table discovery in action
- Test with PostgreSQL or MySQL instead of SQLite

## Clean Up

To reset everything:

```bash
rm -f rodauth_demo.db
rm -rf db/migrate/
bundle exec rackup
```

This will give you a fresh start with warnings about missing tables.
