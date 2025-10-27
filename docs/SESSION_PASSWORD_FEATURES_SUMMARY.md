# Session Management and Password Security Features - Summary

## Executive Summary

This document summarizes the analysis of six Rodauth features for integration into rodauth-rack. All features are **ready for immediate integration** - the existing adapter interface and migration templates support them without modification.

## Feature Overview

### Session Management

| Feature | Database | Purpose | Recommendation |
|---------|----------|---------|----------------|
| session_expiration | No | Timeout-based expiration | **Recommended for all apps** |
| single_session | Yes | One session per account | Use only if required by policy |
| active_sessions | Yes | Multi-session management | **Recommended for enterprise** |

### Password Security

| Feature | Database | Purpose | Recommendation |
|---------|----------|---------|----------------|
| password_pepper | No | Secret key for hash protection | **Strongly recommended** |
| password_expiration | Yes | Mandatory periodic changes | Discouraged (use only if required) |
| password_complexity | No | Advanced validation rules | Discouraged (use custom rules) |

## Integration Status

### Migration Templates

All required migration templates already exist in rodauth-rack:

```
lib/rodauth/rack/generators/migration/
├── active_record/
│   ├── single_session.erb           ✓ Ready
│   ├── active_sessions.erb          ✓ Ready
│   └── password_expiration.erb      ✓ Ready
└── sequel/
    ├── single_session.erb           ✓ Ready
    ├── active_sessions.erb          ✓ Ready
    └── password_expiration.erb      ✓ Ready
```

**No database schema** needed for:

- session_expiration (uses session store only)
- password_pepper (configuration only)
- password_complexity (validation only)

### Adapter Compatibility

Both Rails and Hanami adapters support all features using existing methods:

**Required Methods** (already implemented):

- `session` - Session access
- `clear_session` - Session clearing
- `redirect` - Redirects
- `flash` - Flash messages
- `db` - Database connection

**No new adapter methods required.**

## Recommended Implementation Paths

### Path 1: Standard Web Application (Most Common)

**Features**: session_expiration + password_pepper

**Time**: 1 hour

**Benefits**:

- Automatic session security
- Database hash protection
- Zero UX impact
- No migrations needed

**Configuration**:

```ruby
enable :session_expiration, :password_pepper

max_session_lifetime 86400
session_inactivity_timeout 1800
password_pepper ENV["RODAUTH_PASSWORD_PEPPER"]
```

### Path 2: Enterprise Application

**Features**: session_expiration + active_sessions + password_pepper + disallow_password_reuse

**Time**: 5 hours

**Benefits**:

- Session management UI
- User can terminate sessions remotely
- Password history tracking
- Global logout capability

**Migrations Required**:

- active_sessions table
- previous_password_hashes table

### Path 3: High Security / Compliance

**Features**: All six features

**Time**: 8 hours

**Benefits**:

- Maximum security controls
- Compliance with strict policies
- Full audit trail

**Migrations Required**:

- single_session table
- active_sessions table (alternative to single_session)
- password_expiration table
- previous_password_hashes table

**Trade-offs**:

- Restricted user experience
- Higher maintenance burden
- User complaints likely

## UI Requirements

### Session Management UI (Active Sessions Feature)

Rodauth does NOT provide built-in templates. Must implement:

1. **Sessions List Page**
   - Display all active sessions
   - Show device/browser info
   - Allow remote termination
   - Highlight current session

2. **Global Logout Checkbox**
   - Add to logout form
   - Terminates all sessions
   - Template: `_global_logout_field.html.erb`

**Example**: `/Users/d/Projects/opensource/d/rodauth-rack/test/rails/rails_app/app/views/rodauth/_global_logout_field.html.erb`

### Password Expiration UI

No dedicated templates needed. Must implement:

1. **Dashboard Warning Banner**
   - Show expiration countdown
   - Link to change password
   - Alert style based on urgency

2. **Email Notifications**
   - Send 7 days before expiration
   - Reminder at 3 days
   - Final warning at 1 day

## JSON API Support

### Session Expiration

```json
// GET /api/protected - Expired session
{
  "error": "Your session has expired",
  "status": 401
}
```

### Active Sessions

```json
// GET /api/sessions
{
  "sessions": [
    {
      "session_id": "abc123",
      "created_at": "2025-10-26T10:00:00Z",
      "last_use": "2025-10-26T14:30:00Z",
      "current": true
    }
  ]
}

// DELETE /api/sessions/:id
{
  "message": "Session terminated"
}
```

### Password Expiration

```json
// POST /api/login - Expired password
{
  "error": "Your password has expired and must be changed",
  "reason": "password_expired",
  "change_password_url": "/change-password",
  "status": 403
}
```

## Security Best Practices

### Critical: Password Pepper

**Generate secure pepper**:

```bash
ruby -r securerandom -e 'puts SecureRandom.hex(32)'
```

**Storage locations** (in order of preference):

1. AWS Secrets Manager / HashiCorp Vault
2. Rails credentials (encrypted)
3. Environment variables (gitignored)
4. Never commit to version control

**BCrypt users**: Set `password_maximum_bytes 60` to prevent truncation vulnerability.

### Session Timeouts

Recommended values by application type:

| Application Type | Inactivity | Max Lifetime |
|------------------|------------|--------------|
| Banking/Healthcare | 15 min | 4 hours |
| Standard web app | 30 min | 24 hours |
| Internal tools | 60 min | 7 days |

### Password Policies

**Modern recommendations**:

- Minimum length: 12-16 characters
- NO complexity requirements
- NO expiration (unless required)
- YES password pepper
- YES breach detection (HaveIBeenPwned)

**Legacy compliance**:

- Expiration: 90-180 days
- History: 10-12 passwords
- Complexity: Custom rules only (avoid password_complexity feature)

## Migration Commands

```bash
# Session features
rails generate rodauth:migration single_session
rails generate rodauth:migration active_sessions

# Password features
rails generate rodauth:migration password_expiration
rails generate rodauth:migration disallow_password_reuse

# Run migrations
rails db:migrate
```

## Performance Impact

### Database Queries per Request

| Feature | Queries | Impact |
|---------|---------|--------|
| session_expiration | 0 | None |
| single_session | 1 | Minimal |
| active_sessions | 1-2 | Low |
| password_pepper | 0 | CPU only |
| password_expiration | 1 (login only) | Minimal |

### Optimization Tips

1. Add index on `active_sessions.last_use` for cleanup queries
2. Run session cleanup daily via background job
3. Limit password history to 10-12 records
4. Remove old peppers after 95% migration

## Integration Checklist

### Phase 1: Basic Security (1 hour)

- [ ] Generate secure password pepper (32+ characters)
- [ ] Store pepper in environment variable or credentials
- [ ] Add `enable :session_expiration, :password_pepper`
- [ ] Configure timeouts based on security requirements
- [ ] Set `password_maximum_bytes 60` for bcrypt
- [ ] Add `rodauth.check_session_expiration` to route handler
- [ ] Test session expiration behavior
- [ ] Test password creation and login

### Phase 2: Session Management (4 hours)

- [ ] Generate active_sessions migration
- [ ] Run migration
- [ ] Add `enable :active_sessions`
- [ ] Configure expiration timeouts
- [ ] Create sessions list route and view
- [ ] Add global logout checkbox to logout form
- [ ] Implement JSON API endpoints (if needed)
- [ ] Set up background job for cleanup
- [ ] Test multi-device session management

### Phase 3: Compliance Features (4 hours, if required)

- [ ] Generate password_expiration migration
- [ ] Run migration
- [ ] Add `enable :password_expiration, :disallow_password_reuse`
- [ ] Configure expiration interval (90+ days)
- [ ] Implement warning email system
- [ ] Add dashboard expiration banner
- [ ] Test expiration redirect flow
- [ ] Document password policy for users

## Testing Strategy

### Unit Tests

```ruby
# Session expiration
it "expires session after inactivity timeout"
it "expires session after max lifetime"
it "updates activity timestamp on request"

# Active sessions
it "creates session record on login"
it "removes session record on logout"
it "lists all account sessions"
it "terminates specific session"
it "global logout removes all sessions"

# Password pepper
it "applies pepper to new passwords"
it "validates login with peppered password"
it "migrates hash on pepper rotation"

# Password expiration
it "redirects to change password when expired"
it "allows password change before expiration"
it "prevents password change before minimum interval"
```

### Integration Tests

```ruby
# Multi-device scenarios
scenario "login on second device"
scenario "logout from one device affects only that session"
scenario "global logout terminates all devices"

# Expiration flows
scenario "session expires after timeout"
scenario "password expires after configured days"
scenario "user receives expiration warning"
```

## Documentation Requirements

### For Users

Create documentation covering:

1. **Session Policy**
   - Timeout durations
   - Multi-device support
   - How to manage sessions

2. **Password Policy**
   - Length requirements
   - Complexity rules
   - Expiration schedule (if enabled)
   - History limitations

3. **Session Management UI**
   - How to view active sessions
   - How to terminate sessions
   - What information is displayed

### For Developers

Document:

1. **Configuration Options**
   - All available settings
   - Recommended values
   - Security implications

2. **Customization Points**
   - Custom validation rules
   - UI templates
   - Email templates

3. **Pepper Management**
   - Generation procedure
   - Storage locations
   - Rotation process

## Known Issues and Limitations

### Session Expiration

- Uses session store timestamps (not database)
- Clock skew between servers can cause issues
- No built-in warning before expiration

### Single Session

- Poor UX for multi-device users
- No grace period for device switching
- Rodauth recommends against using it

### Active Sessions

- No built-in UI for session management
- Requires custom views implementation
- Session table grows over time (needs cleanup)

### Password Complexity

- Dictionary validation can be slow
- Complex rules lead to weaker passwords
- Rodauth recommends against using it

### Password Expiration

- Forces weaker password choices
- Causes user frustration
- Rodauth recommends against using it

### Password Pepper

- BCrypt truncation vulnerability if not configured properly
- Rotation requires all users to login for migration
- Pepper compromise requires password reset for all users

## Support and References

### Documentation

- Full integration plan: `/Users/d/Projects/opensource/d/rodauth-rack/docs/FEATURE_INTEGRATION_PLAN.md`
- Rodauth docs: <https://rodauth.jeremyevans.net/>
- Session expiration: <https://rodauth.jeremyevans.net/rdoc/files/doc/session_expiration_rdoc.html>
- Single session: <https://rodauth.jeremyevans.net/rdoc/files/doc/single_session_rdoc.html>
- Active sessions: <https://rodauth.jeremyevans.net/rdoc/files/doc/active_sessions_rdoc.html>
- Password complexity: <https://rodauth.jeremyevans.net/rdoc/files/doc/password_complexity_rdoc.html>
- Password expiration: <https://rodauth.jeremyevans.net/rdoc/files/doc/password_expiration_rdoc.html>
- Password pepper: <https://rodauth.jeremyevans.net/rdoc/files/doc/password_pepper_rdoc.html>

### Migration Templates

- Active Record: `/Users/d/Projects/opensource/d/rodauth-rack/lib/rodauth/rack/generators/migration/active_record/`
- Sequel: `/Users/d/Projects/opensource/d/rodauth-rack/lib/rodauth/rack/generators/migration/sequel/`

### Example Code

- Hanami demo: `/Users/d/Projects/opensource/d/rodauth-rack/examples/hanami-demo/`
- Rails test app: `/Users/d/Projects/opensource/d/rodauth-rack/test/rails/rails_app/`
- Global logout field: `/Users/d/Projects/opensource/d/rodauth-rack/test/rails/rails_app/app/views/rodauth/_global_logout_field.html.erb`

## Conclusion

All six features are ready for integration with minimal effort:

**Immediate Use** (no code changes):

- session_expiration
- password_pepper
- password_complexity

**Requires Migrations** (templates exist):

- single_session
- active_sessions
- password_expiration

**Requires UI Implementation**:

- active_sessions (session management page)
- password_expiration (warning banners)

**Recommended Starting Point**:
Enable `session_expiration` + `password_pepper` in all applications for baseline security with zero UX impact.
