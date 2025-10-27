# Rodauth-Rack JSON API Documentation

This document describes the JSON API endpoints that the Vue components consume.

## Authentication

All API requests should include session cookies for authentication. The API uses the same session mechanism as the main Rodauth routes.

### Headers

```
Content-Type: application/json
Accept: application/json
```

---

## Email Authentication

### Request Email Auth Link

Send a passwordless sign-in link via email.

**Endpoint:** `POST /api/auth/email-auth-request`

**Request Body:**

```json
{
  "email": "user@example.com"
}
```

**Success Response (200 OK):**

```json
{
  "success": true,
  "message": "Email sent to user@example.com"
}
```

**Error Response (400/422):**

```json
{
  "error": "Invalid email address",
  "field_errors": {
    "email": ["is not a valid email"]
  }
}
```

**Rate Limiting:**

- Users can only request a new email link once every 5 minutes
- Links expire after 2 hours

---

## Two-Factor Authentication (OTP)

### Setup OTP

Initialize OTP setup and generate QR code.

**Endpoint:** `POST /api/mfa/otp/setup`

**Request Body:** None (empty)

**Success Response (200 OK):**

```json
{
  "qr_code": "<svg>...</svg>",
  "secret": "JBSWY3DPEHPK3PXP",
  "provisioning_uri": "otpauth://totp/AppName:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=AppName"
}
```

**Error Response (401):**

```json
{
  "error": "Authentication required"
}
```

---

### Confirm OTP Setup

Verify OTP code and enable two-factor authentication.

**Endpoint:** `POST /api/mfa/otp/confirm`

**Request Body:**

```json
{
  "otp_code": "123456"
}
```

**Success Response (200 OK):**

```json
{
  "success": true,
  "recovery_codes": [
    "a1b2c3d4e5f6g7h8",
    "i9j0k1l2m3n4o5p6",
    "q7r8s9t0u1v2w3x4",
    "y5z6a7b8c9d0e1f2",
    "g3h4i5j6k7l8m9n0"
  ]
}
```

**Error Response (422):**

```json
{
  "error": "Invalid authentication code"
}
```

---

### Verify OTP

Verify OTP code or recovery code during login.

**Endpoint:** `POST /api/mfa/verify`

**Request Body (OTP code):**

```json
{
  "otp_code": "123456"
}
```

**Request Body (Recovery code):**

```json
{
  "recovery_code": "a1b2c3d4e5f6g7h8"
}
```

**Success Response (200 OK):**

```json
{
  "success": true
}
```

**Error Response (422):**

```json
{
  "error": "Invalid authentication code. 4 attempts remaining."
}
```

**Account Lockout:**

- After 5 failed attempts, the account will be locked
- Lockout duration: 30 minutes (configurable)

---

### Disable OTP

Disable two-factor authentication.

**Endpoint:** `POST /api/mfa/otp/disable`

**Request Body:**

```json
{
  "password": "user_password"
}
```

**Success Response (200 OK):**

```json
{
  "success": true,
  "message": "Two-factor authentication disabled"
}
```

**Error Response (422):**

```json
{
  "error": "Invalid password"
}
```

---

### Get Recovery Codes

Retrieve existing recovery codes (requires re-authentication).

**Endpoint:** `GET /api/mfa/recovery-codes`

**Success Response (200 OK):**

```json
{
  "recovery_codes": [
    "a1b2c3d4e5f6g7h8",
    "i9j0k1l2m3n4o5p6",
    "q7r8s9t0u1v2w3x4"
  ]
}
```

Note: Used recovery codes are not included in the response.

---

## Audit Logs

### List Audit Logs

Retrieve audit logs for the current user.

**Endpoint:** `GET /api/audit_logs`

**Query Parameters:**

- `page` (integer, default: 1) - Page number
- `per_page` (integer, default: 25, max: 100) - Items per page
- `sort_by` (string, default: "at") - Sort column ("at", "message")
- `sort_order` (string, default: "desc") - Sort order ("asc", "desc")
- `start_date` (ISO 8601 date) - Filter logs from this date
- `end_date` (ISO 8601 date) - Filter logs to this date
- `action` (string) - Filter by action/message pattern
- `ip` (string) - Filter by IP address

**Example Request:**

```
GET /api/audit_logs?page=1&per_page=25&sort_order=desc&action=login
```

**Success Response (200 OK):**

```json
{
  "data": [
    {
      "id": 123,
      "account_id": 456,
      "timestamp": "2024-01-15T14:30:00Z",
      "message": "login",
      "ip_address": "192.168.1.1",
      "user_agent": "Mozilla/5.0...",
      "session_id": "abc123",
      "request_method": "POST",
      "request_path": "/auth/login",
      "metadata": {
        "ip": "192.168.1.1",
        "user_agent": "Mozilla/5.0...",
        "session_id": "abc123",
        "request_method": "POST",
        "request_path": "/auth/login"
      }
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

**Error Response (401):**

```json
{
  "error": "Authentication required"
}
```

---

### Get Single Audit Log

Retrieve a specific audit log by ID.

**Endpoint:** `GET /api/audit_logs/:id`

**Success Response (200 OK):**

```json
{
  "data": {
    "id": 123,
    "account_id": 456,
    "timestamp": "2024-01-15T14:30:00Z",
    "message": "login",
    "ip_address": "192.168.1.1",
    "user_agent": "Mozilla/5.0...",
    "session_id": "abc123",
    "request_method": "POST",
    "request_path": "/auth/login",
    "metadata": { }
  }
}
```

**Error Response (404):**

```json
{
  "error": "Audit log not found"
}
```

---

## Audit Log Message Types

The `message` field contains one of these action types:

### Authentication Actions

- `login` - User signed in
- `logout` - User signed out
- `login_failure` - Failed login attempt

### Account Actions

- `create_account` - Account created
- `verify_account` - Account verified via email
- `close_account` - Account closed/deleted

### Password Actions

- `reset_password` - Password reset via email
- `reset_password_request` - Password reset requested
- `change_password` - Password changed while logged in

### Email Actions

- `change_login` - Email address changed
- `verify_login_change` - Email change verified

### Two-Factor Actions

- `otp_setup` - Two-factor authentication enabled
- `otp_auth` - Two-factor authentication successful
- `otp_auth_failure` - Two-factor authentication failed
- `otp_disable` - Two-factor authentication disabled
- `recovery_auth` - Recovery code used

### Account Security

- `lockout` - Account locked due to failed attempts
- `unlock_account` - Account unlocked

### Email Auth

- `email_auth_request` - Passwordless email link requested
- `email_auth` - Signed in via email link

---

## Error Handling

### Error Response Format

All errors follow this format:

```json
{
  "error": "Human-readable error message",
  "field_errors": {
    "field_name": ["error message 1", "error message 2"]
  }
}
```

### HTTP Status Codes

- `200` - Success
- `201` - Created
- `400` - Bad Request (malformed request)
- `401` - Unauthorized (authentication required)
- `403` - Forbidden (insufficient permissions)
- `404` - Not Found
- `422` - Unprocessable Entity (validation failed)
- `429` - Too Many Requests (rate limited)
- `500` - Internal Server Error

---

## Rate Limiting

The following endpoints have rate limits:

- Email auth requests: 1 per 5 minutes per email
- OTP verification: 5 attempts per account (then lockout)
- Password reset: 3 per hour per email

Rate limit headers:

```
X-RateLimit-Limit: 5
X-RateLimit-Remaining: 4
X-RateLimit-Reset: 1642262400
```

---

## CSRF Protection

For non-JSON requests or when integrating with traditional forms, include the CSRF token:

```html
<meta name="csrf-token" content="token-value">
```

The API client automatically handles CSRF tokens from meta tags.

---

## Session Management

Sessions are managed via HTTP-only cookies:

```
Set-Cookie: _session_id=abc123; HttpOnly; Secure; SameSite=Strict
```

The Vue components rely on these cookies for authentication state.

---

## Development/Testing

### Local API Base URL

Development: `http://localhost:3000/api`
Production: `/api` (relative)

### Test Credentials

See your development seed data or test fixtures for test accounts.

### Debugging

Enable debug mode in the API client:

```typescript
import { apiClient } from '@utils/api'

// Log all requests/responses
apiClient.debug = true
```

---

## Security Considerations

1. **HTTPS Only** - All production traffic must use HTTPS
2. **CORS** - Configure CORS headers if API is on different domain
3. **Session Security** - Use secure, HTTP-only cookies
4. **Rate Limiting** - Implement rate limiting for sensitive endpoints
5. **Input Validation** - Validate all inputs server-side
6. **SQL Injection** - Use parameterized queries
7. **XSS Protection** - Sanitize user input before display
8. **CSRF Protection** - Validate CSRF tokens on state-changing requests

---

## API Versioning

Current version: **v1** (implicit)

Future versions will be explicitly versioned:

- `/api/v2/...`

The current API (`/api/...`) is considered v1 and will be maintained for backward compatibility.

---

## Migration Guide

If you're migrating from traditional Rodauth forms to the JSON API:

1. Keep existing Rodauth configuration
2. Add JSON API endpoints (see controllers in `app/controllers/api/`)
3. Update frontend to use Vue components
4. Test both flows during transition
5. Gradually migrate users to new flow
6. Remove old views once migration complete

---

## Support

For issues or questions:

- GitHub Issues: [rodauth-rack/issues](https://github.com/delano/rodauth-rack/issues)
- Documentation: [README.md](../README.md)
- Rodauth Docs: [http://rodauth.jeremyevans.net/](http://rodauth.jeremyevans.net/)
