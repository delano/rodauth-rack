# Quick Start Guide - Hanami Demo

Get up and running with the Hanami + Rodauth demo in 5 minutes.

## Prerequisites

- Ruby 3.1+
- Bundler 2.x
- SQLite3

## Setup (One-time)

```bash
# 1. Install dependencies
bundle install

# 2. Create database directory (if needed)
mkdir -p db

# 3. Run migration
bundle exec sequel -m db/migrate sqlite://db/hanami_demo.db

# 4. Start server
bundle exec rackup -p 2300
```

Visit <http://localhost:2300>

## Quick Feature Tour

### 1. Create Account (30 seconds)

1. Go to <http://localhost:2300>
2. Click "Create Account"
3. Email: `demo@example.com`
4. Password: `password123`
5. Submit
6. Check server console for verification link
7. Copy/paste link in browser
8. Account verified

### 2. Email Authentication (1 minute)

1. Visit <http://localhost:2300/email-auth-demo>
2. Click "Request Email Login Link"
3. Enter: `demo@example.com`
4. Check server console for link
5. Copy/paste link in browser
6. Logged in without password

### 3. Setup Two-Factor Auth (2 minutes)

1. Log in first (if not already)
2. Visit <http://localhost:2300/otp-demo>
3. Click "Setup Two-Factor Authentication"
4. Open Google Authenticator app (or similar)
5. Scan QR code OR enter secret key manually
6. Enter 6-digit code from app
7. Save recovery codes shown
8. OTP enabled

### 4. View Audit Log (30 seconds)

1. Visit <http://localhost:2300/security>
2. See all your authentication events
3. Check IP addresses, timestamps, actions

## Test JSON API

```bash
# Save session cookie
curl -X POST http://localhost:2300/login \
  -H "Content-Type: application/json" \
  -d '{"login": "demo@example.com", "password": "password123"}' \
  -c cookies.txt

# Get audit logs
curl http://localhost:2300/api/audit-logs \
  -b cookies.txt | jq .

# Request email auth
curl -X POST http://localhost:2300/email-auth-request \
  -H "Content-Type: application/json" \
  -d '{"login": "demo@example.com"}'
```

## Common Issues

### Database Error

```bash
# Recreate database
rm db/hanami_demo.db
bundle exec sequel -m db/migrate sqlite://db/hanami_demo.db
```

### Can't See Email Links

Check server console output - emails are printed there, not actually sent.

### OTP Not Working

- Make sure you're using a TOTP app (Google Authenticator, Authy, 1Password)
- Check that device time is synchronized
- Try scanning QR code again

### Port Already in Use

```bash
# Use different port
bundle exec rackup -p 3000
```

## All Demo Pages

### Public

- `/` - Home
- `/email-auth-demo` - Email auth info
- `/create-account` - Sign up
- `/login` - Log in
- `/email-auth` - Request passwordless login

### Authenticated

- `/dashboard` - Dashboard
- `/security` - Audit log
- `/otp-demo` - OTP info
- `/otp-setup` - Setup 2FA
- `/recovery-codes` - View codes

### API

- `GET /api/audit-logs` - Audit logs

## What's Included

- Email Authentication (passwordless)
- OTP/MFA (Google Authenticator)
- Recovery Codes (backup)
- Audit Logging (all events)
- JSON API (all features)

## Learn More

- [FEATURES.md](FEATURES.md) - Complete feature documentation
- [SETUP.md](SETUP.md) - Detailed setup guide
- [Rodauth Documentation](https://rodauth.jeremyevans.net)

## Support

Found a bug? Have questions?

- Check [FEATURES.md](FEATURES.md) for detailed docs
- Check [SETUP.md](SETUP.md) for troubleshooting
- Review server console for error messages
