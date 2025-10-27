# Rodauth Feature Integration Plan

## Session Management and Password Security Features

This document provides comprehensive integration plans for six Rodauth features:

### Session Management Features

1. session_expiration - Timeout-based session invalidation
2. single_session - One session per account restriction
3. active_sessions - Multiple session tracking and management

### Password Security Features

4. password_complexity - Advanced password validation rules
5. password_expiration - Mandatory periodic password changes
6. password_pepper - Secret key for password hash protection

---

## 1. Session Expiration Feature

### Overview

The session_expiration feature enforces timeout-based session invalidation using two mechanisms: inactivity timeout and maximum session lifetime. This feature does NOT require database tables - it stores session metadata in the session store itself.

### How It Works

Sessions expire when either:

- Inactivity exceeds the configured timeout (default: 30 minutes)
- Total session duration exceeds maximum lifetime (default: 1 day)

Upon expiration, the session clears and users are redirected to the login page.

### Configuration Options

```ruby
# In rodauth_main.rb
configure do
  enable :session_expiration

  # Core timeouts
  max_session_lifetime 86400                    # 1 day (seconds)
  session_inactivity_timeout 1800               # 30 minutes (seconds)

  # Session keys for timestamp storage
  session_created_session_key :session_created_at
  session_last_activity_session_key :session_last_activity

  # Behavior control
  session_expiration_default true               # Expire sessions lacking timestamps
  session_expiration_error_flash "Your session has expired"
  session_expiration_error_status 401           # For JSON APIs
  session_expiration_redirect "/login"
end
```

### Database Requirements

**NONE** - This feature uses only session storage.

### Implementation in Route Handler

```ruby
# In rodauth_app.rb
route do |r|
  rodauth.check_session_expiration  # Place at top of routing tree

  r.rodauth

  # Rest of your routes
end
```

### Rails Adapter Requirements

No special adapter methods required. Uses existing:

- `session` - Access session hash
- `clear_session` - Clear expired sessions
- `redirect` - Redirect on expiration

### Hanami Adapter Requirements

Same as Rails - no special requirements. The Hanami adapter already implements:

- Session access via Rack session
- Session clearing
- Redirect functionality

### JSON API Support

For API endpoints:

```ruby
configure do
  enable :session_expiration, :json

  only_json? true
  session_expiration_error_status 401
end
```

Response when expired:

```json
{
  "error": "Your session has expired"
}
```

### Security Considerations

1. **Storage Security**: Session timestamps stored in session cookie/store
2. **Clock Skew**: Ensure server time synchronization
3. **Session Hijacking**: Combine with `single_session` or `active_sessions` for stronger security
4. **Remember Feature**: Session expiration applies even to "remembered" users

### Best Practices

1. Set appropriate timeouts based on application sensitivity:
   - High security: 15 min inactivity, 4 hour lifetime
   - Standard: 30 min inactivity, 24 hour lifetime
   - Low security: 60 min inactivity, 7 day lifetime

2. Warn users before expiration (requires custom JS implementation)

3. Combine with `active_sessions` for enterprise applications

### Integration Checklist

- [ ] Add `enable :session_expiration` to configuration
- [ ] Configure timeouts based on security requirements
- [ ] Add `rodauth.check_session_expiration` to route handler
- [ ] Test expiration behavior in both web and API modes
- [ ] Document timeout policy for users

---

## 2. Single Session Feature

### Overview

The single_session feature restricts each account to exactly one active session by storing a session key in the database. When a user logs in from a new location, all previous sessions become invalid.

**Rodauth Recommendation**: "It is not recommended to use this feature unless you have a policy that requires it" as most users expect to stay logged in on multiple devices.

**Alternative**: Consider `active_sessions` for multiple concurrent session support with better UX.

### How It Works

1. On login, a unique session key is generated and stored in the database
2. On each request, `rodauth.check_single_session` validates the current session key matches the stored key
3. On logout, the stored key is reset, invalidating any session using the old key

### Database Schema

#### Active Record Migration

```ruby
# db/migrate/20250101000000_create_rodauth_single_session.rb
create_table :account_session_keys, id: false do |t|
  t.bigint :id, primary_key: true
  t.foreign_key :accounts, column: :id
  t.string :key, null: false
end
```

#### Sequel Migration

```ruby
# db/migrate/20250101000000_create_rodauth_single_session.rb
Sequel.migration do
  change do
    create_table :account_session_keys do
      foreign_key :id, :accounts, primary_key: true, type: :Bignum
      String :key, null: false
    end
  end
end
```

### Configuration Options

```ruby
configure do
  enable :single_session

  # Table and column names
  single_session_table :account_session_keys
  single_session_id_column :id
  single_session_key_column :key

  # Session storage
  single_session_session_key :account_session_key

  # Error handling
  single_session_error_flash "This session is no longer valid"
  single_session_redirect "/login"
  inactive_session_error_status 401  # For JSON APIs

  # HMAC security (recommended)
  hmac_secret "your-secret-key-here"
  # For gradual HMAC adoption:
  # allow_raw_single_session_key? true
end
```

### Implementation in Route Handler

```ruby
route do |r|
  rodauth.load_memory  # For remember feature
  rodauth.check_single_session  # Validate session

  r.rodauth

  # Require authentication for protected routes
  r.on "dashboard" do
    rodauth.require_authentication
    # dashboard routes
  end
end
```

### Key Methods

```ruby
# Check if current session is active
rodauth.currently_active_session?  # => true/false

# Called automatically on logout - resets session key
rodauth.reset_single_session_key

# Called automatically on login - sets new session key
rodauth.update_single_session_key

# Handle inactive session scenario
rodauth.no_longer_active_session
```

### Rails Adapter Requirements

Uses standard adapter methods:

- `session` - Session access
- `clear_session` - Clear on invalid session
- `redirect` - Redirect on session invalidation
- `db` - Database connection for key storage

### Hanami Adapter Requirements

Same as Rails - all required methods already implemented.

### JSON API Support

```ruby
configure do
  enable :single_session, :json
  only_json? true

  inactive_session_error_status 401
end
```

API response when session invalid:

```json
{
  "error": "This session is no longer valid"
}
```

### Security Considerations

1. **HMAC Protection**: Always use `hmac_secret` to prevent session key tampering
2. **Database Security**: Session keys table should be tightly secured
3. **Logout Behavior**: Logout from one device logs out ALL sessions (by design)
4. **Session Fixation**: Feature prevents session fixation attacks by resetting keys

### User Experience Impact

**Negative UX Scenarios**:

- User logs in from phone, existing desktop session dies
- Multiple tabs stop working after login in new tab
- Shared devices cause mutual logout loops

**When to Use**:

- High-security applications (banking, healthcare)
- Single-device policies
- Compliance requirements mandate one session per user

### Migration from Multiple Sessions

If adding to existing application:

1. Generate migration for session keys table
2. Run migration
3. Add `enable :single_session` to config
4. Set `allow_raw_single_session_key? true` temporarily
5. After all users re-login, remove raw key support

### Integration Checklist

- [ ] Generate migration: `rails generate rodauth:migration single_session`
- [ ] Run migration: `rails db:migrate`
- [ ] Add `enable :single_session` to rodauth_main.rb
- [ ] Configure `hmac_secret` for production security
- [ ] Add `rodauth.check_single_session` to route handler
- [ ] Update table names if using custom prefix
- [ ] Test logout invalidates other sessions
- [ ] Document single-session behavior for users
- [ ] Consider UX impact and user complaints

---

## 3. Active Sessions Feature

### Overview

The active_sessions feature provides comprehensive session tracking, allowing users to:

- View all their active sessions
- Terminate specific sessions remotely
- Perform global logout (terminate all sessions)
- Automatic cleanup of expired sessions

This is the recommended alternative to `single_session` for most applications.

### How It Works

1. On login, a unique session ID is generated and stored with account ID, creation time, and last activity time
2. On each request, `rodauth.check_active_session` validates the session exists and is not expired
3. Sessions automatically expire based on inactivity timeout and/or maximum lifetime
4. Users can view and manage their sessions via custom UI (templates not provided by Rodauth)

### Database Schema

#### Active Record Migration

```ruby
# db/migrate/20250101000000_create_rodauth_active_sessions.rb
create_table :account_active_session_keys, primary_key: [:account_id, :session_id] do |t|
  t.references :account, foreign_key: true, type: :bigint
  t.string :session_id
  t.datetime :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
  t.datetime :last_use, null: false, default: -> { "CURRENT_TIMESTAMP" }
end
```

#### Sequel Migration

```ruby
# db/migrate/20250101000000_create_rodauth_active_sessions.rb
Sequel.migration do
  change do
    create_table :account_active_session_keys do
      foreign_key :account_id, :accounts, type: :Bignum
      String :session_id
      Time :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Time :last_use, null: false, default: Sequel::CURRENT_TIMESTAMP
      primary_key [:account_id, :session_id]
    end
  end
end
```

### Configuration Options

```ruby
configure do
  enable :active_sessions

  # Table and column configuration
  active_sessions_table :account_active_session_keys
  active_sessions_account_id_column :account_id
  active_sessions_session_id_column :session_id
  active_sessions_created_at_column :created_at
  active_sessions_last_use_column :last_use

  # Session storage
  active_sessions_session_key :active_session_id

  # Expiration settings
  max_session_lifetime 30 * 86400           # 30 days
  session_inactivity_timeout 86400          # 1 day
  # Set to nil to disable either expiration type:
  # max_session_lifetime nil
  # session_inactivity_timeout nil

  # Update last_use on every request (default: true)
  update_session_activity_time? true

  # Error handling
  active_sessions_error_flash "This session is no longer active"
  active_sessions_redirect "/login"
  inactive_session_error_status 401  # For JSON APIs

  # Global logout UI
  global_logout_label "Logout from all devices"
end
```

### Implementation in Route Handler

```ruby
route do |r|
  rodauth.load_memory
  rodauth.check_active_session  # Validate and update session activity

  r.rodauth

  # Custom session management routes
  r.on "sessions" do
    rodauth.require_authentication

    r.is do
      r.get do
        @sessions = rodauth.account_sessions
        view "sessions/index"
      end
    end

    r.on String do |session_id|
      r.delete do
        rodauth.remove_active_session(session_id)
        redirect "/sessions"
      end
    end
  end
end
```

### Key Methods

```ruby
# Check if current session is active
rodauth.currently_active_session?  # => true/false

# Get all sessions for current account
rodauth.account_sessions
# Returns: Array of hashes with :session_id, :created_at, :last_use

# Remove specific session
rodauth.remove_active_session(session_id)

# Remove all sessions except current
rodauth.remove_all_active_sessions_except_for(session_id)

# Remove all sessions (including current)
rodauth.remove_all_active_sessions

# Clean up expired sessions
rodauth.remove_inactive_sessions
```

### Rails Adapter Requirements

Uses standard adapter methods:

- `session` - Session access
- `clear_session` - Clear expired sessions
- `redirect` - Redirect on session invalidation
- `db` - Database connection for session storage

### Hanami Adapter Requirements

Same as Rails - all required methods already implemented in base adapter.

### JSON API Support

```ruby
configure do
  enable :active_sessions, :json
  only_json? true

  inactive_session_error_status 401
end
```

#### API Endpoints (Custom Implementation Required)

```ruby
# GET /api/sessions - List active sessions
{
  "sessions": [
    {
      "session_id": "abc123",
      "created_at": "2025-10-26T10:00:00Z",
      "last_use": "2025-10-26T14:30:00Z",
      "current": true
    },
    {
      "session_id": "def456",
      "created_at": "2025-10-25T08:00:00Z",
      "last_use": "2025-10-26T12:00:00Z",
      "current": false
    }
  ]
}

# DELETE /api/sessions/:session_id - Terminate session
{
  "message": "Session terminated"
}

# POST /api/sessions/logout_all - Global logout
{
  "message": "All sessions terminated"
}
```

### Session Management UI

Rodauth does NOT provide built-in templates for session management. You must implement:

#### 1. Sessions List View

```erb
<!-- app/views/sessions/index.html.erb -->
<h1>Active Sessions</h1>

<table>
  <thead>
    <tr>
      <th>Created</th>
      <th>Last Activity</th>
      <th>Actions</th>
    </tr>
  </thead>
  <tbody>
    <% @sessions.each do |session| %>
      <tr>
        <td><%= session[:created_at] %></td>
        <td><%= session[:last_use] %></td>
        <td>
          <% if session[:session_id] == rodauth.active_session_id %>
            <span class="badge">Current Session</span>
          <% else %>
            <%= button_to "Terminate",
                session_path(session[:session_id]),
                method: :delete %>
          <% end %>
        </td>
      </tr>
    <% end %>
  </table>

<%= button_to "Logout All Devices", logout_all_path,
    method: :post, class: "btn-danger" %>
```

#### 2. Global Logout Checkbox on Logout Page

```erb
<!-- app/views/rodauth/_global_logout_field.html.erb -->
<div class="form-check">
  <%= check_box_tag rodauth.global_logout_param, "t", false,
      id: "global-logout", class: "form-check-input" %>
  <%= label_tag "global-logout", rodauth.global_logout_label,
      class: "form-check-label" %>
</div>
```

Include in logout form:

```erb
<%= rodauth.render('global_logout_field') %>
```

### Security Considerations

1. **Session ID Security**: Session IDs are cryptographically random
2. **Database Access**: Secure the active sessions table
3. **Cleanup Jobs**: Run periodic cleanup to remove expired sessions
4. **Session Hijacking**: Each session has unique ID preventing fixation attacks
5. **Activity Tracking**: `last_use` timestamp helps identify suspicious activity

### Background Job for Cleanup

```ruby
# app/jobs/cleanup_expired_sessions_job.rb
class CleanupExpiredSessionsJob < ApplicationJob
  queue_as :default

  def perform
    DB.transaction do
      rodauth.remove_inactive_sessions
    end
  end
end

# config/initializers/rodauth_jobs.rb
# Run daily at 3 AM
sidekiq_scheduler.schedule["cleanup_sessions"] = {
  cron: "0 3 * * *",
  class: "CleanupExpiredSessionsJob"
}
```

### Migration from single_session

1. Disable single_session: Remove `enable :single_session`
2. Generate active_sessions migration
3. Run migration
4. Enable active_sessions: `enable :active_sessions`
5. Users will create new sessions on next login

### Integration Checklist

- [ ] Generate migration: `rails generate rodauth:migration active_sessions`
- [ ] Run migration: `rails db:migrate`
- [ ] Add `enable :active_sessions` to rodauth_main.rb
- [ ] Add `rodauth.check_active_session` to route handler
- [ ] Configure expiration timeouts
- [ ] Update table names if using custom prefix
- [ ] Create sessions management routes
- [ ] Build sessions list UI template
- [ ] Add global logout checkbox to logout view
- [ ] Implement JSON API endpoints if needed
- [ ] Set up background job for expired session cleanup
- [ ] Test session termination from multiple devices
- [ ] Add session management link to user dashboard
- [ ] Document session limits and expiration policy

---

## 4. Password Complexity Feature

### Overview

The password_complexity feature enforces sophisticated password validation rules:

1. Character group diversity (3 of 4 groups: uppercase, lowercase, numbers, special chars)
2. Pattern rejection (keyboard sequences like "qwerty", "123456")
3. Repeating character limits (max 3 consecutive identical characters)
4. Dictionary word detection (prevents "password1", "w0rd$$")

**Rodauth Recommendation**: "It is not recommended to use this feature unless you have a policy that requires it" as overly complex rules often result in weaker passwords that users write down or reuse.

### How It Works

On password creation or change, the feature runs four validators in sequence:

1. Checks character group diversity (bypassed if password > 11 chars)
2. Rejects common keyboard patterns
3. Prevents excessive repeating characters
4. Validates against dictionary words (with substitution detection)

### Database Requirements

**NONE** - Validation occurs in application layer only.

### Configuration Options

```ruby
configure do
  enable :password_complexity

  # Character group requirements
  password_min_groups 3  # Require 3 of 4 groups
  password_max_length_for_groups_check 11  # Bypass groups check if longer

  # Character groups (customizable)
  password_character_groups [
    /[[:lower:]]/,           # Lowercase letters
    /[[:upper:]]/,           # Uppercase letters
    /[[:digit:]]/,           # Numbers
    /[^[:lower:][:upper:][:digit:]]/  # Special characters
  ]

  # Repeating character limit
  password_max_repeating_characters 3

  # Dictionary configuration
  password_dictionary_file "/usr/share/dict/words"
  # Or provide custom list:
  # password_dictionary %w[password admin root user]

  # Custom error messages
  password_not_enough_character_groups_message \
    "Password must contain characters from at least 3 groups"
  password_common_sequence_message \
    "Password contains common sequence"
  password_too_many_repeating_characters_message \
    "Password contains too many repeating characters"
  password_is_dictionary_word_message \
    "Password is based on a dictionary word"
end
```

### Custom Complexity Rules

For simpler custom rules, use this instead:

```ruby
configure do
  # DON'T enable password_complexity

  # Custom validation
  password_meets_requirements? do |password|
    super(password) && password_complex_enough?(password)
  end

  auth_class_eval do
    def password_complex_enough?(password)
      return true if password.match?(/\d/) && password.match?(/[^a-zA-Z\d]/)
      set_password_requirement_error_message(
        :password_simple,
        "requires one number and one special character"
      )
      false
    end
  end
end
```

### Rails Adapter Requirements

No special adapter methods required. Uses:

- Password validation hooks (already in base Rodauth)

### Hanami Adapter Requirements

Same as Rails - no special requirements.

### JSON API Support

Works automatically. Validation errors return:

```json
{
  "field-error": ["password", "must contain characters from at least 3 groups"]
}
```

### Security Considerations

1. **Usability vs Security**: Research shows overly complex requirements lead to:
   - Written-down passwords
   - Predictable patterns (Password1!, Password2!)
   - Password reuse across sites

2. **Better Alternative**: Use `password_pepper` + longer minimum length (12-16 chars) without complexity requirements

3. **Breach Detection**: Consider integrating HaveIBeenPwned API instead

4. **Dictionary Performance**: Large dictionary files can slow down registration/password changes

### Best Practices

1. **Use Custom Rules**: Implement simple custom validation instead of full feature:

   ```ruby
   # Good: Simple, understandable rule
   password.match?(/\d/) && password.match?(/[^a-zA-Z\d]/)

   # Bad: Complex rules users don't understand
   enable :password_complexity
   ```

2. **Minimum Length Over Complexity**:
   - 12+ characters plain is stronger than 8 characters with symbols
   - Users choose better passwords with length-only requirements

3. **User-Friendly Errors**: Provide clear guidance:

   ```ruby
   password_requirement_message \
     "must be at least 12 characters with one number and one symbol"
   ```

4. **Testing**: Ensure form displays errors clearly during registration

### Integration Checklist

- [ ] Evaluate if complexity requirements are necessary
- [ ] Consider custom validation instead of full feature
- [ ] Add `enable :password_complexity` to rodauth_main.rb (if required)
- [ ] Configure `password_min_groups` based on policy
- [ ] Set `password_dictionary_file` if using dictionary validation
- [ ] Customize error messages for clarity
- [ ] Test password validation in registration form
- [ ] Test password validation in change password form
- [ ] Ensure JSON API returns proper validation errors
- [ ] Document password requirements for users
- [ ] Provide password strength indicator (custom JS)

---

## 5. Password Expiration Feature

### Overview

The password_expiration feature enforces mandatory password changes at set intervals. By default, users must update their password every 90 days upon login.

**Rodauth Recommendation**: "Password expiration in general results in users choosing weaker passwords" and should only be used if organizational policy mandates it.

### How It Works

1. On account creation or password change, current timestamp is stored
2. On login, password age is checked against `require_password_change_after`
3. If expired, user is redirected to change password page
4. Optionally enforce minimum time between password changes

### Database Schema

#### Active Record Migration

```ruby
# db/migrate/20250101000000_create_rodauth_password_expiration.rb
create_table :account_password_change_times, id: false do |t|
  t.bigint :id, primary_key: true
  t.foreign_key :accounts, column: :id
  t.datetime :changed_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
end
```

#### Sequel Migration

```ruby
# db/migrate/20250101000000_create_rodauth_password_expiration.rb
Sequel.migration do
  change do
    create_table :account_password_change_times do
      foreign_key :id, :accounts, primary_key: true, type: :Bignum
      DateTime :changed_at, null: false, default: Sequel::CURRENT_TIMESTAMP
    end
  end
end
```

### Configuration Options

```ruby
configure do
  enable :password_expiration

  # Table configuration
  password_expiration_table :account_password_change_times
  password_expiration_id_column :id
  password_expiration_changed_at_column :changed_at

  # Expiration policy
  require_password_change_after 90 * 86400  # 90 days (seconds)
  allow_password_change_after nil           # Minimum time between changes (disabled by default)
  # allow_password_change_after 86400       # Example: 1 day minimum

  # Default behavior for accounts without change time record
  password_expiration_default false         # Don't expire by default

  # Redirect destination when password expired
  password_change_needed_redirect "/change-password"

  # Error messages
  password_expired_error_flash \
    "Your password has expired and must be changed"
  password_changed_too_recently_error_flash \
    "You cannot change your password yet"
end
```

### Enforcing Password Expiration Checks

#### Option 1: Automatic Check on Login (Default)

No additional code needed - expiration checked automatically during login.

#### Option 2: Force Check for All Authenticated Routes

```ruby
# In rodauth_app.rb
route do |r|
  r.rodauth

  # Protected routes
  r.on "dashboard" do
    rodauth.require_authentication
    rodauth.require_current_password  # Forces password expiration check

    # dashboard routes
  end
end
```

### Key Methods

```ruby
# Check if password is expired
rodauth.password_expired?  # => true/false

# Update password change timestamp (called automatically)
rodauth.update_password_changed_at

# Get time when password expires
rodauth.password_expiration_time  # => Time object
```

### Rails Adapter Requirements

Uses standard adapter methods:

- `db` - Database connection
- `redirect` - Redirect to change password page
- `flash` - Display expiration messages

### Hanami Adapter Requirements

Same as Rails - all required methods already implemented.

### JSON API Support

```ruby
configure do
  enable :password_expiration, :json
  only_json? true

  password_expired_error_status 403  # Custom status for expired passwords
end
```

API response when password expired:

```json
{
  "error": "Your password has expired and must be changed",
  "reason": "password_expired",
  "change_password_url": "/change-password"
}
```

### User Notification Strategy

#### 1. Warning Email Before Expiration

```ruby
# app/jobs/password_expiration_warning_job.rb
class PasswordExpirationWarningJob < ApplicationJob
  def perform
    # Find accounts with passwords expiring in next 7 days
    warning_threshold = 7.days.from_now
    expiration_age = rodauth.require_password_change_after

    DB[:account_password_change_times]
      .where { changed_at < Time.now - (expiration_age - 7.days) }
      .each do |record|
        PasswordExpirationMailer.warning(record[:id]).deliver_later
      end
  end
end
```

#### 2. Dashboard Warning Banner

```erb
<!-- app/views/dashboard/show.html.erb -->
<% if rodauth.password_expired? %>
  <div class="alert alert-danger">
    Your password has expired.
    <%= link_to "Change it now", change_password_path %>
  </div>
<% elsif rodauth.password_expires_soon? %>
  <div class="alert alert-warning">
    Your password expires in <%= rodauth.password_days_until_expiration %> days.
    <%= link_to "Change it now", change_password_path %>
  </div>
<% end %>
```

Custom helper methods:

```ruby
# In rodauth_main.rb
auth_methods :password_expires_soon?, :password_days_until_expiration

auth_class_eval do
  def password_expires_soon?
    return false unless logged_in?
    time_until_expiration < 7.days
  end

  def password_days_until_expiration
    return nil unless logged_in?
    (time_until_expiration / 86400).ceil
  end

  private

  def time_until_expiration
    changed_at = db[password_expiration_table]
      .where(password_expiration_id_column => account_id)
      .get(password_expiration_changed_at_column)

    return 0 unless changed_at

    expiration_time = changed_at + require_password_change_after
    expiration_time - Time.now
  end
end
```

### Password History Integration

Combine with `disallow_password_reuse` to prevent password cycling:

```ruby
configure do
  enable :password_expiration, :disallow_password_reuse

  require_password_change_after 90 * 86400
  previous_passwords_to_check 12  # Remember last 12 passwords
end
```

### Security Considerations

1. **Weaker Passwords**: Forced expiration leads to:
   - Sequential passwords (Password1, Password2, etc.)
   - Written-down passwords
   - User frustration and security fatigue

2. **Better Alternative**: Use breach detection instead of expiration

3. **Compliance**: Only implement if required by:
   - PCI-DSS
   - HIPAA
   - SOC 2
   - Internal security policy

4. **Notification Strategy**: Always warn users before expiration

### Best Practices

1. **Longer Intervals**: If required, use 180+ days instead of 90

2. **Combine with Password History**: Prevent simple cycling

3. **Grace Period**: Allow limited access to export data before forcing change

4. **Clear Communication**: Explain why passwords expire

5. **Exception Handling**: Provide way for users to request extension

### Integration Checklist

- [ ] Evaluate if expiration is required by policy
- [ ] Generate migration: `rails generate rodauth:migration password_expiration`
- [ ] Run migration: `rails db:migrate`
- [ ] Add `enable :password_expiration` to rodauth_main.rb
- [ ] Configure `require_password_change_after` interval
- [ ] Set `allow_password_change_after` if minimum interval needed
- [ ] Update table names if using custom prefix
- [ ] Add `rodauth.require_current_password` to protected routes (optional)
- [ ] Implement password expiration warning emails
- [ ] Add dashboard warning banner
- [ ] Test expiration redirect on login
- [ ] Test minimum change interval if enabled
- [ ] Combine with `disallow_password_reuse` if needed
- [ ] Document password expiration policy for users
- [ ] Set up monitoring for accounts with expired passwords

---

## 6. Password Pepper Feature

### Overview

The password_pepper feature adds a secret string (pepper) to passwords before hashing. This provides defense-in-depth: even if attackers steal password hashes from the database, they cannot crack them without also obtaining the pepper from your application configuration.

### How It Works

1. On password creation/change: `hash = bcrypt(password + pepper)`
2. On login: Compare `bcrypt(provided_password + pepper)` with stored hash
3. On pepper rotation: Check both new pepper and old peppers
4. Automatic migration: When user logs in with old pepper, hash is updated with new pepper

### Database Requirements

**NONE** - Pepper stored in application configuration only.

### Configuration Options

```ruby
configure do
  enable :password_pepper

  # Current pepper (keep secret!)
  password_pepper ENV.fetch("RODAUTH_PASSWORD_PEPPER")

  # For bcrypt users: prevent truncation beyond 72 bytes
  password_maximum_bytes 60  # Leave 12 bytes for bcrypt overhead

  # Pepper rotation support
  # previous_password_peppers [
  #   ENV.fetch("RODAUTH_OLD_PEPPER_1"),
  #   ""  # For passwords created without pepper
  # ]

  # Auto-update hashes to new pepper on login (default: true)
  password_pepper_update? true
end
```

### Pepper Generation

Generate a secure pepper:

```bash
# Ruby
ruby -r securerandom -e 'puts SecureRandom.hex(32)'

# OpenSSL
openssl rand -hex 32

# Output: 64-character hex string
# Example: a1b2c3d4e5f6...
```

### Storage Options

#### Option 1: Environment Variable (Recommended)

```ruby
# config/rodauth_main.rb
password_pepper ENV.fetch("RODAUTH_PASSWORD_PEPPER")

# .env (development)
RODAUTH_PASSWORD_PEPPER=a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456

# config/secrets.yml (production)
production:
  rodauth_password_pepper: <%= ENV["RODAUTH_PASSWORD_PEPPER"] %>
```

#### Option 2: Rails Credentials (Rails 5.2+)

```bash
rails credentials:edit
```

```yaml
rodauth:
  password_pepper: a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456
```

```ruby
# config/rodauth_main.rb
password_pepper Rails.application.credentials.dig(:rodauth, :password_pepper)
```

#### Option 3: Secret Management Service

```ruby
# config/rodauth_main.rb
password_pepper VaultService.fetch("rodauth/password_pepper")
```

### Pepper Rotation

When rotating peppers (e.g., after potential compromise):

```ruby
configure do
  enable :password_pepper

  # New pepper (active for new passwords)
  password_pepper ENV.fetch("RODAUTH_PASSWORD_PEPPER_NEW")

  # Previous peppers (for validation)
  previous_password_peppers [
    ENV.fetch("RODAUTH_PASSWORD_PEPPER_OLD"),
    ""  # For passwords that had no pepper initially
  ]

  # Automatically update to new pepper on successful login
  password_pepper_update? true
end
```

**Migration Process**:

1. Add new pepper to `password_pepper`
2. Add old pepper(s) to `previous_password_peppers`
3. Deploy application
4. Wait for all users to login (updates hashes automatically)
5. After sufficient time, remove old peppers

### BCrypt Truncation Issue

BCrypt has a 72-byte limit. Password + pepper exceeding this is vulnerable:

```ruby
# BAD: Long password + pepper = truncation
password = "a" * 60  # 60 bytes
pepper = "b" * 40    # 40 bytes
# Total: 100 bytes -> bcrypt only hashes first 72

# ATTACKER CAN:
# 1. Brute force 12-byte pepper suffix
# 2. Crack password without knowing full pepper

# SOLUTION: Set maximum password bytes
configure do
  enable :password_pepper
  password_pepper "32-character-pepper-here-xxx"  # 32 bytes
  password_maximum_bytes 40  # 40 + 32 = 72 bytes total
end
```

### Argon2 Users

If using Argon2, use `argon2_secret` instead:

```ruby
configure do
  enable :argon2

  argon2_secret { ENV.fetch("RODAUTH_ARGON2_SECRET") }

  # Disable bcrypt to save memory
  require_bcrypt? false
end
```

### Rails Adapter Requirements

No special adapter methods required.

### Hanami Adapter Requirements

Same as Rails - no special requirements.

### JSON API Support

Works transparently - no API changes needed.

### Security Considerations

1. **Storage Security**:
   - Store pepper separately from database
   - Use environment variables or secret management
   - Never commit peppers to version control

2. **Pepper vs Salt**:
   - Salt: Per-password, stored in database (prevents rainbow tables)
   - Pepper: Global secret, stored separately (prevents hash cracking)

3. **Rotation Strategy**:
   - Rotate annually or after suspected compromise
   - Use `previous_password_peppers` for gradual migration

4. **Backup Security**:
   - Database backups alone cannot crack passwords
   - Peppers must be stolen separately

5. **Performance Impact**:
   - Multiple peppers = multiple hash attempts per login
   - Example: 3 peppers × 10 password history checks = 30 validations

### Best Practices

1. **Length**: Use 32+ character peppers

2. **Rotation Schedule**:
   - Annual rotation for standard security
   - Immediate rotation after breach

3. **Secret Management**:
   - Production: Use AWS Secrets Manager, HashiCorp Vault, etc.
   - Staging: Use Rails credentials
   - Development: Use .env files (gitignored)

4. **Documentation**:
   - Document pepper location for ops team
   - Include rotation procedure in runbooks

5. **Testing**:
   - Use separate pepper for test environment
   - Never use production pepper in tests

### Integration with Password History

When combined with `disallow_password_reuse`:

```ruby
configure do
  enable :password_pepper, :disallow_password_reuse

  password_pepper ENV.fetch("RODAUTH_PASSWORD_PEPPER")
  previous_password_peppers [ENV.fetch("RODAUTH_OLD_PEPPER")]

  previous_passwords_to_check 10
end

# Performance impact:
# Login: (1 new pepper + 1 old pepper) = 2 hash checks
# Password change: 2 peppers × 10 history checks = 20 hash checks
```

### Monitoring

Track pepper usage during rotation:

```ruby
# Custom hook to monitor pepper updates
configure do
  after_password_pepper_update do
    StatsD.increment("rodauth.pepper.updated")
  end
end

# Query accounts still using old pepper
DB[:accounts]
  .exclude(password_hash: DB[:accounts]
    .where(Sequel.lit("password_hash LIKE 'new_pepper_prefix%'"))
    .select(:password_hash))
  .count
```

### Integration Checklist

- [ ] Generate secure pepper (32+ characters)
- [ ] Store pepper in secret management system
- [ ] Add `enable :password_pepper` to rodauth_main.rb
- [ ] Configure `password_pepper` from ENV or credentials
- [ ] Set `password_maximum_bytes` if using bcrypt
- [ ] Test password creation with pepper
- [ ] Test login with peppered passwords
- [ ] Document pepper location for ops team
- [ ] Set up annual rotation reminder
- [ ] Create pepper rotation procedure
- [ ] Test pepper rotation with `previous_password_peppers`
- [ ] Ensure peppers never committed to version control
- [ ] Configure separate peppers for each environment
- [ ] Add pepper to deployment checklist
- [ ] Monitor pepper updates during rotation

---

## Comprehensive Implementation Blueprint

### Phase 1: Session Management Features

#### Decision Matrix

| Feature | Use Case | Database Required | User Impact |
|---------|----------|-------------------|-------------|
| session_expiration | All apps with sensitive data | No | Low - transparent |
| single_session | Banking, healthcare, compliance | Yes | High - restricts devices |
| active_sessions | Enterprise apps, user control | Yes | Medium - better UX |

**Recommended Stack**:

- Standard Apps: `session_expiration` alone
- Enterprise Apps: `session_expiration` + `active_sessions`
- High Security: All three features combined

#### Implementation Order

1. **session_expiration** (30 minutes)
   - Add to config
   - Test timeout behavior
   - Document for users

2. **active_sessions** (4 hours)
   - Generate and run migration
   - Add to config
   - Build sessions management UI
   - Test multi-device scenarios

3. **single_session** (if required) (2 hours)
   - Generate and run migration
   - Replace active_sessions in config
   - Test device restrictions
   - Document UX changes

### Phase 2: Password Security Features

#### Decision Matrix

| Feature | Use Case | Database Required | Recommendation |
|---------|----------|-------------------|----------------|
| password_pepper | All production apps | No | Strongly recommended |
| password_expiration | Compliance requirements only | Yes | Discouraged |
| password_complexity | Policy requirements only | No | Discouraged |

**Recommended Configuration**:

- Minimum: `password_pepper` + 12-char minimum length
- Compliance: Add `password_expiration` + `disallow_password_reuse`
- Avoid: `password_complexity` (use custom validation instead)

#### Implementation Order

1. **password_pepper** (1 hour)
   - Generate secure pepper
   - Store in secret management
   - Add to config
   - Test password operations

2. **password_expiration** (if required) (3 hours)
   - Generate and run migration
   - Add to config
   - Build warning system
   - Test expiration flow

3. **password_complexity** (if required) (2 hours)
   - Consider custom validation first
   - Add to config if policy requires
   - Test validation errors
   - Document requirements

### Combined Feature Configurations

#### Configuration 1: Standard Web Application

```ruby
class RodauthMain < Rodauth::Auth
  configure do
    enable :login, :logout, :create_account,
           :reset_password, :change_password,
           :remember,
           :session_expiration,  # Timeout-based security
           :password_pepper      # Hash protection

    # Session security
    max_session_lifetime 86400
    session_inactivity_timeout 1800

    # Password security
    password_pepper ENV.fetch("RODAUTH_PASSWORD_PEPPER")
    password_maximum_bytes 60
    password_minimum_length 12
  end
end
```

#### Configuration 2: Enterprise Application

```ruby
class RodauthMain < Rodauth::Auth
  configure do
    enable :login, :logout, :create_account,
           :reset_password, :change_password,
           :remember,
           :session_expiration,
           :active_sessions,  # Session management UI
           :password_pepper,
           :disallow_password_reuse

    # Session security
    max_session_lifetime 30 * 86400
    session_inactivity_timeout 86400
    update_session_activity_time? true

    # Password security
    password_pepper ENV.fetch("RODAUTH_PASSWORD_PEPPER")
    password_maximum_bytes 60
    password_minimum_length 12
    previous_passwords_to_check 10
  end
end
```

#### Configuration 3: High-Security/Compliance

```ruby
class RodauthMain < Rodauth::Auth
  configure do
    enable :login, :logout, :create_account,
           :reset_password, :change_password,
           :remember,
           :session_expiration,
           :single_session,  # One session per account
           :password_pepper,
           :password_expiration,
           :disallow_password_reuse

    # Session security
    max_session_lifetime 4 * 3600  # 4 hours
    session_inactivity_timeout 900  # 15 minutes

    # Password security
    password_pepper ENV.fetch("RODAUTH_PASSWORD_PEPPER")
    password_maximum_bytes 60
    password_minimum_length 16
    require_password_change_after 90 * 86400
    previous_passwords_to_check 12
  end
end
```

### Migration Generation Commands

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

### Testing Checklist

#### Session Features

- [ ] Session expires after inactivity timeout
- [ ] Session expires after maximum lifetime
- [ ] Expired session redirects to login
- [ ] Activity updates last_use timestamp
- [ ] Global logout terminates all sessions
- [ ] Individual session termination works
- [ ] Sessions list displays correctly
- [ ] JSON API returns 401 for expired sessions

#### Password Features

- [ ] Pepper applied to new passwords
- [ ] Login works with peppered passwords
- [ ] Pepper rotation migrates hashes
- [ ] Password expires after configured period
- [ ] Expired password forces change on login
- [ ] Warning appears before expiration
- [ ] Previous passwords cannot be reused
- [ ] Complexity rules enforced (if enabled)

### Documentation for Users

#### Session Management

```markdown
# Session Security

Your account sessions expire automatically for security:

- **Inactivity**: 30 minutes without activity
- **Maximum**: 24 hours total session length

## Managing Sessions

View and terminate your active sessions at:
[https://example.com/sessions](https://example.com/sessions)

Each session shows:
- Device/browser information
- When it was created
- Last activity time

You can terminate any session remotely.

## Logout Options

- **Standard Logout**: Ends current session only
- **Logout All**: Terminates all active sessions
```

#### Password Policy

```markdown
# Password Policy

## Requirements

Passwords must:
- Be at least 12 characters long
- Contain at least one number
- Contain at least one special character

## Security Features

- Passwords are encrypted with industry-standard bcrypt
- Additional secret key protection prevents database-only attacks
- Password history prevents reuse of last 10 passwords

## Expiration (if enabled)

Passwords expire every 90 days. You'll receive:
- Email warning 7 days before expiration
- Dashboard banner when expiration is near
- Forced change on login after expiration
```

### Performance Considerations

#### Database Load

| Feature | DB Queries per Request | Impact |
|---------|----------------------|--------|
| session_expiration | 0 | None (session only) |
| single_session | 1 SELECT | Minimal |
| active_sessions | 1-2 (SELECT + UPDATE) | Low |
| password_pepper | 0 | None (CPU only) |
| password_expiration | 1 SELECT (on login) | Minimal |

#### Optimization Tips

1. **Active Sessions**: Add index on last_use for cleanup queries
2. **Password History**: Limit `previous_passwords_to_check` to 10-12
3. **Pepper Rotation**: Remove old peppers after 95% migration
4. **Session Cleanup**: Run daily, not per-request

### Security Audit Questions

- [ ] Is password pepper at least 32 characters?
- [ ] Is pepper stored separately from database?
- [ ] Are session timeouts appropriate for application sensitivity?
- [ ] Is session expiration enforced on all protected routes?
- [ ] Are expired sessions cleaned up regularly?
- [ ] Is password expiration policy documented?
- [ ] Are users warned before password expiration?
- [ ] Is password minimum length at least 12 characters?
- [ ] Are previous passwords prevented from reuse?
- [ ] Is pepper rotation procedure documented?

---

## Conclusion

This integration plan provides complete guidance for implementing session management and password security features in rodauth-rack. The existing migration templates and adapter interface require no modifications - all features work with current Rails and Hanami adapters.

**Key Takeaways**:

1. **Start Simple**: Begin with `session_expiration` + `password_pepper`
2. **Add as Needed**: Enterprise apps benefit from `active_sessions`
3. **Avoid Unless Required**: Skip `password_complexity` and `password_expiration` unless mandated
4. **Document Everything**: Users need clear guidance on security policies
5. **Test Thoroughly**: Verify all scenarios before production deployment

Each feature includes complete configuration examples, security considerations, and UI implementation guidance suitable for both Rails and Hanami frameworks.
