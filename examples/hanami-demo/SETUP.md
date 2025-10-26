# Quick Setup Guide

This is a step-by-step guide to get the Hanami + Rodauth demo running.

## Prerequisites

- Ruby 3.1 or higher
- Bundler 2.x

## Steps

### 1. Install Dependencies

```bash
bundle install
```

### 2. Set Up Database

Create the database directory:

```bash
mkdir -p db
```

### 3. Generate and Run Migration

The Rodauth migration command creates the necessary database tables:

```bash
rodauth generate migration base reset_password verify_account
```

This creates a migration file like `db/migrations/001_create_rodauth_base.rb`.

Run the migration:

```bash
# Option 1: Using Hanami CLI (if available)
bundle exec hanami db migrate

# Option 2: Using Sequel directly
bundle exec sequel -m db/migrations sqlite://db/hanami_demo.db
```

### 4. Start the Server

```bash
bundle exec hanami server
```

Or with rackup:

```bash
bundle exec rackup -p 2300
```

### 5. Open Your Browser

Navigate to <http://localhost:2300>

## Quick Test

1. Click "Create Account"
2. Enter email: `test@example.com`
3. Enter password: `password123`
4. Submit the form
5. Check the server console output for the verification link
6. Copy and paste the verification link into your browser
7. Login with the same credentials
8. You should be redirected to the dashboard

## Troubleshooting

### Migration Not Found

If `rodauth generate migration` doesn't work, create the migration manually:

```ruby
# db/migrations/001_create_rodauth_base.rb
Sequel.migration do
  up do
    create_table(:accounts) do
      primary_key :id, :type=>:Bignum
      String :email, :null=>false
      constraint :valid_email, :email=>/^[^,;@ \r\n]+@[^,@; \r\n]+\.[^,@; \r\n]+$/
      String :status, :null=>false, :default=>'unverified'
      DateTime :created_at, :null=>false, :default=>Sequel::CURRENT_TIMESTAMP
      index :email, :unique=>true, :where=>{:status=>%w'verified unverified'}
    end

    create_table(:account_password_hashes) do
      foreign_key :id, :accounts, :primary_key=>true, :type=>:Bignum
      String :password_hash, :null=>false
    end

    create_table(:account_verification_keys) do
      foreign_key :id, :accounts, :primary_key=>true, :type=>:Bignum
      String :key, :null=>false
      DateTime :requested_at, :null=>false, :default=>Sequel::CURRENT_TIMESTAMP
      DateTime :email_last_sent, :null=>false, :default=>Sequel::CURRENT_TIMESTAMP
    end

    create_table(:account_password_reset_keys) do
      foreign_key :id, :accounts, :primary_key=>true, :type=>:Bignum
      String :key, :null=>false
      DateTime :requested_at, :null=>false, :default=>Sequel::CURRENT_TIMESTAMP
      DateTime :email_last_sent, :null=>false, :default=>Sequel::CURRENT_TIMESTAMP
    end

    create_table(:account_remember_keys) do
      foreign_key :id, :accounts, :primary_key=>true, :type=>:Bignum
      String :key, :null=>false
      DateTime :deadline, :null=>false
    end
  end

  down do
    drop_table(:account_remember_keys)
    drop_table(:account_password_reset_keys)
    drop_table(:account_verification_keys)
    drop_table(:account_password_hashes)
    drop_table(:accounts)
  end
end
```

Then run:

```bash
bundle exec sequel -m db/migrations sqlite://db/hanami_demo.db
```

### Server Won't Start

Make sure all dependencies are installed:

```bash
bundle check || bundle install
```

### Can't Access Database

Check that the database file exists:

```bash
ls -la db/hanami_demo.db
```

If not, run the migration again.

## Next Steps

Once everything is running, explore:

- Creating and verifying accounts
- Logging in and out
- Visiting the protected dashboard
- Resetting passwords
- Changing email addresses

Check the main README.md for more details on customization and features.
