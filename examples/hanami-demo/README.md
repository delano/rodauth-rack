# Hanami + Rodauth Demo

Demonstrates Rodauth integration with email auth, OTP/MFA, recovery codes, and audit logging.

## Quick Start

```bash
bundle install
bundle exec sequel -m db/migrate sqlite://db/hanami_demo.db
bundle exec rackup -p 2300
```

Visit <http://localhost:2300>

## Features Demonstrated

- Email authentication (passwordless login)
- OTP/MFA (two-factor authentication)
- Recovery codes
- Audit logging
- JSON API for all features

## Demo Pages

- `/` - Home
- `/email-auth-demo` - Email auth info
- `/otp-demo` - OTP/MFA info
- `/security` - Audit log viewer
- `/dashboard` - Protected page (requires login)

## Quick Test

1. Create account at `/create-account`
2. Check console for verification link, paste in browser
3. Login with credentials
4. Visit `/otp-setup` to configure 2FA (use Google Authenticator or similar)
5. View activity at `/security`

## API Examples

```bash
# Create account
curl -X POST http://localhost:2300/create-account \
  -H "Content-Type: application/json" \
  -d '{"login": "test@example.com", "password": "pass123", "password-confirm": "pass123"}'

# Get audit logs (requires session cookie)
curl http://localhost:2300/api/audit-logs \
  -H "Content-Type: application/json" \
  -b cookies.txt
```

Configuration: `lib/rodauth_main.rb`
