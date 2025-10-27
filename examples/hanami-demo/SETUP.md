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
rr generate migration base reset_password verify_account
```

This creates a migration file at `db/migrate/TIMESTAMP_create_rodauth.rb`.

Run the migration:

```bash
# Option 1: Using Hanami CLI (if available)
bundle exec hanami db migrate

# Option 2: Using Sequel directly
bundle exec sequel -m db/migrate sqlite://db/hanami_demo.db
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

## Testing Features

### Email Authentication (Passwordless Login)

1. Visit `/email-auth-demo` to learn about the feature
2. Go to `/email-auth` and enter your email
3. Check the server console for the login link (emails not actually sent)
4. Copy the link and paste it in your browser
5. You'll be automatically logged in

### Two-Factor Authentication (OTP/MFA)

1. Create an account and log in
2. Visit `/otp-demo` for an overview
3. Click "Setup Two-Factor Authentication" or go to `/otp-setup`
4. Scan the QR code with an authenticator app (Google Authenticator, Authy, 1Password, etc.)
5. Enter the 6-digit code from your app to verify setup
6. Save your recovery codes in a secure location
7. Log out and log back in - you'll now be prompted for an OTP code

**Note:** You'll need an authenticator app on your phone or computer that supports TOTP (Time-based One-Time Password).

### Audit Logging

1. Log in to your account
2. Perform various actions (change password, update email, etc.)
3. Visit `/security` to view your complete audit log
4. See IP addresses, timestamps, and details of all authentication events

### JSON API Testing

All features are available via JSON API. Test with curl:

```bash
# Create account
curl -X POST http://localhost:2300/create-account \
  -H "Content-Type: application/json" \
  -d '{"login": "test@example.com", "password": "password123", "password-confirm": "password123"}'

# Login
curl -X POST http://localhost:2300/login \
  -H "Content-Type: application/json" \
  -d '{"login": "test@example.com", "password": "password123"}' \
  -c cookies.txt

# Request email auth
curl -X POST http://localhost:2300/email-auth-request \
  -H "Content-Type: application/json" \
  -d '{"login": "test@example.com"}'

# Get audit logs (requires session cookie)
curl http://localhost:2300/api/audit-logs \
  -H "Content-Type: application/json" \
  -b cookies.txt
```

## Feature Overview

This demo includes:

- **Email Authentication** - Passwordless login via email links
- **OTP/MFA** - Two-factor authentication with TOTP
- **Recovery Codes** - Backup authentication codes
- **Audit Logging** - Complete tracking of authentication events

See [FEATURES.md](FEATURES.md) for detailed documentation on all features.

## Demo Pages

### Public Pages

- `/` - Home with feature overview
- `/email-auth-demo` - Email authentication explanation
- `/create-account` - Register new account
- `/login` - Standard login
- `/email-auth` - Request passwordless login

### Authenticated Pages (requires login)

- `/dashboard` - User dashboard
- `/security` - Audit log and security settings
- `/otp-demo` - OTP/MFA information
- `/otp-setup` - Configure two-factor auth
- `/recovery-codes` - View backup codes

### API Endpoints

- `GET /api/audit-logs` - List audit logs (JSON)
- `GET /api/audit-logs/:id` - Get specific log entry (JSON)

## Configuration

Key configuration is in `lib/rodauth_main.rb`:

- Email auth link valid for 2 hours
- 5-minute cooldown between email requests
- 16 recovery codes generated
- Complete metadata logged for all events
- OTP drift tolerance of 30 seconds

## Next Steps

Once everything is running, explore:

- Creating and verifying accounts
- Logging in with password or email link
- Setting up two-factor authentication
- Viewing your security audit log
- Testing the JSON API endpoints

Check [FEATURES.md](FEATURES.md) for complete feature documentation and API examples.
