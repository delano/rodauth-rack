# Hanami Demo - Features Overview

This demo application showcases comprehensive authentication features using Rodauth with Hanami 2.x.

## Enabled Features

### Core Authentication

- **Account Creation** - User registration with email verification
- **Login/Logout** - Standard username/password authentication
- **Remember Me** - Persistent sessions across browser sessions
- **Password Reset** - Secure password recovery via email
- **Change Password** - Update password while logged in
- **Change Email** - Update email address with verification
- **Close Account** - Self-service account deletion

### Advanced Features

#### 1. Email Authentication (Passwordless Login)

Allows users to log in without a password using time-limited email links.

**How it works:**

1. User enters their email address
2. System sends a unique login link
3. User clicks link to authenticate
4. Automatic login without password

**Security features:**

- Links expire after 2 hours
- Single-use links
- Rate limiting (5 minutes between emails)
- All attempts logged in audit trail

**Try it:**

- Visit `/email-auth-demo` for overview
- Visit `/email-auth` to request login link
- Check server console for the link (email not actually sent in demo)

**API Endpoints:**

```bash
# Request email auth link
POST /email-auth-request
Content-Type: application/json
{"login": "user@example.com"}

# Authenticate with key
POST /email-auth
Content-Type: application/json
{"key": "unique-key-from-email"}
```

#### 2. OTP/MFA (Two-Factor Authentication)

Time-based One-Time Password (TOTP) for enhanced security.

**How it works:**

1. User sets up OTP by scanning QR code
2. Authenticator app generates 6-digit codes
3. After password login, OTP code is required
4. Recovery codes provided for backup access

**Security features:**

- TOTP standard (RFC 6238)
- 30-second time window with drift tolerance
- 5 failed attempts lock out
- Recovery codes for emergency access
- Password required for OTP changes

**Try it:**

1. Create account and log in
2. Visit `/otp-demo` for overview
3. Visit `/otp-setup` to configure
4. Scan QR code with authenticator app
5. Enter 6-digit code to verify

**API Endpoints:**

```bash
# Setup OTP (returns QR code and secret)
POST /otp-setup

# Verify OTP during login
POST /otp-auth
Content-Type: application/json
{"otp_auth": "123456"}

# Disable OTP
POST /otp-disable

# View recovery codes
GET /recovery-codes

# Use recovery code
POST /recovery-auth
Content-Type: application/json
{"recovery_codes": "recovery-code-here"}
```

#### 3. Recovery Codes

Backup authentication codes for emergency account access.

**Features:**

- 16 single-use codes generated
- Automatically removed after use
- Viewable only once during setup
- Can be regenerated if needed

**Try it:**

- After setting up OTP, view `/recovery-codes`
- Save codes in a secure location
- Use during login if OTP app unavailable

#### 4. Audit Logging

Comprehensive tracking of all authentication events.

**What's logged:**

- Login attempts (successful and failed)
- Logout events
- Password changes
- Email changes
- OTP setup/disable
- Email auth attempts
- Account creation/deletion
- All security-related actions

**Metadata captured:**

- Timestamp
- IP address
- User agent
- Session ID
- Request method and path

**Try it:**

1. Log in and perform various actions
2. Visit `/security` to view your audit log
3. See last 50 events with full details

**API Endpoints:**

```bash
# Get audit logs (with pagination and filtering)
GET /api/audit-logs?page=1&per_page=25

# Filter examples
GET /api/audit-logs?start_date=2024-01-01&end_date=2024-12-31
GET /api/audit-logs?action=login
GET /api/audit-logs?sort_by=at&sort_order=desc

# Get specific log entry
GET /api/audit-logs/:id
```

**API Response:**

```json
{
  "data": [
    {
      "id": 123,
      "account_id": 1,
      "timestamp": "2024-01-15T10:30:00Z",
      "message": "login",
      "ip_address": "192.168.1.1",
      "user_agent": "Mozilla/5.0...",
      "session_id": "abc123",
      "request_method": "POST",
      "request_path": "/login",
      "metadata": {...}
    }
  ],
  "meta": {
    "page": 1,
    "per_page": 25,
    "total_count": 150,
    "total_pages": 6
  }
}
```

## Demo Pages

### Public Pages

- `/` - Home page with feature overview
- `/email-auth-demo` - Email authentication explanation
- `/create-account` - Account registration
- `/login` - Standard login
- `/email-auth` - Request passwordless login

### Authenticated Pages

- `/dashboard` - User dashboard
- `/security` - View audit log and manage security
- `/otp-demo` - OTP/MFA information and setup
- `/otp-setup` - Configure two-factor authentication
- `/otp-disable` - Disable two-factor authentication
- `/recovery-codes` - View/regenerate recovery codes
- `/change-password` - Update password
- `/change-login` - Change email address
- `/close-account` - Delete account

## JSON API Endpoints

All Rodauth endpoints support JSON requests with `Accept: application/json` or `Content-Type: application/json`.

### Authentication

- `POST /create-account` - Register new account
- `POST /login` - Standard login
- `POST /logout` - End session
- `POST /email-auth-request` - Request email login
- `POST /email-auth` - Authenticate via email key

### Two-Factor Authentication

- `POST /otp-setup` - Initialize OTP
- `POST /otp-auth` - Verify OTP code
- `POST /otp-disable` - Disable OTP
- `GET /recovery-codes` - List recovery codes
- `POST /recovery-auth` - Use recovery code

### Account Management

- `POST /change-password` - Update password
- `POST /change-login` - Update email
- `POST /close-account` - Delete account
- `POST /reset-password-request` - Request password reset
- `POST /reset-password` - Complete password reset

### Audit Logs

- `GET /api/audit-logs` - List audit logs (paginated)
- `GET /api/audit-logs/:id` - Get specific log entry

## Database Schema

The demo uses SQLite with the following key tables:

- `accounts` - User accounts
- `account_password_reset_keys` - Password reset tokens
- `account_verification_keys` - Email verification tokens
- `account_login_change_keys` - Email change verification
- `account_remember_keys` - Persistent session tokens
- `account_email_auth_keys` - Passwordless login keys
- `account_otp_keys` - TOTP secrets
- `account_recovery_codes` - Backup authentication codes
- `account_authentication_audit_logs` - Event tracking

## Configuration Highlights

Key Rodauth configuration in `lib/rodauth_main.rb`:

```ruby
# Email auth settings
email_auth_deadline_interval { 2 * 60 * 60 }  # 2 hours
email_auth_skip_resend_email_within { 5 * 60 }  # 5 minutes

# OTP settings
recovery_codes_count 16
auto_remove_recovery_codes? true

# Audit logging
audit_logging_metadata_default do
  {
    ip: request.ip,
    user_agent: request.user_agent,
    session_id: session.id,
    request_method: request.request_method,
    request_path: request.path
  }
end
```

## Security Best Practices

This demo implements several security best practices:

1. **Password Hashing** - Using bcrypt for secure password storage
2. **CSRF Protection** - Built into Rodauth
3. **Rate Limiting** - Email auth rate limited to prevent abuse
4. **Session Security** - Secure session handling with proper timeouts
5. **Audit Trail** - Complete logging of security events
6. **Account Verification** - Email verification before account activation
7. **Two-Factor Auth** - Optional TOTP for enhanced security
8. **Recovery Codes** - Secure backup access method
9. **Account Lockout** - Protection against brute force attacks

## Use Cases

### Email Authentication

- Consumer apps where ease of use is priority
- Infrequent users who forget passwords
- Mobile apps where typing is inconvenient
- Temporary or guest access
- Account recovery option

### OTP/MFA

- High-security applications
- Financial services
- Healthcare applications
- Admin accounts
- Compliance requirements (PCI-DSS, HIPAA, etc.)

### Audit Logging

- Compliance and regulatory requirements
- Security monitoring
- User activity tracking
- Debugging authentication issues
- Forensic analysis

## Testing the Features

### Email Authentication Flow

```bash
# 1. Request login link
curl -X POST http://localhost:2300/email-auth-request \
  -H "Content-Type: application/json" \
  -d '{"login": "user@example.com"}'

# 2. Check server console for link
# 3. Use key from link
curl -X POST http://localhost:2300/email-auth \
  -H "Content-Type: application/json" \
  -d '{"key": "key-from-console"}'
```

### OTP Setup Flow

```bash
# 1. Setup OTP (while logged in)
curl -X POST http://localhost:2300/otp-setup \
  -H "Content-Type: application/json" \
  -H "Cookie: rack.session=..."

# Response includes QR code data and secret
# 2. Scan QR code or use secret in authenticator app
# 3. Verify with generated code
curl -X POST http://localhost:2300/otp-auth \
  -H "Content-Type: application/json" \
  -d '{"otp_auth": "123456"}'
```

### Audit Log Query

```bash
# Get recent activity
curl http://localhost:2300/api/audit-logs \
  -H "Cookie: rack.session=..."

# Filter by date range
curl "http://localhost:2300/api/audit-logs?start_date=2024-01-01&end_date=2024-12-31" \
  -H "Cookie: rack.session=..."

# Search for specific actions
curl "http://localhost:2300/api/audit-logs?action=login" \
  -H "Cookie: rack.session=..."
```

## Next Steps

1. **Email Integration** - Configure real email sending (currently logs to console)
2. **Redis Sessions** - Use Redis for session storage in production
3. **Rate Limiting** - Add Rack::Attack for additional rate limiting
4. **Monitoring** - Integrate with monitoring tools
5. **Customize Views** - Adapt templates to match your brand
6. **Add Features** - Enable additional Rodauth features as needed

## Resources

- [Rodauth Documentation](https://rodauth.jeremyevans.net/documentation.html)
- [Rodauth Features](https://rodauth.jeremyevans.net/features.html)
- [Hanami Documentation](https://hanamirb.org)
- [TOTP RFC 6238](https://tools.ietf.org/html/rfc6238)
- [Email Authentication Best Practices](https://rodauth.jeremyevans.net/rdoc/files/doc/email_auth_rdoc.html)
