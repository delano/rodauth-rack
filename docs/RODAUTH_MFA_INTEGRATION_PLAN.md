# Rodauth MFA Integration Plan for rodauth-rack

## Executive Summary

This document provides a comprehensive blueprint for integrating Rodauth's Multi-Factor Authentication (MFA) features into the rodauth-rack gem for both Rails and Hanami frameworks. The analysis covers OTP (TOTP), WebAuthn, Recovery Codes, SMS Codes, and supporting features.

## Current State

### Existing Partial Integration

- **Location**: `/test/rails/rails_app/app/misc/rodauth_admin.rb`
- **Features Enabled**:
  - `two_factor_base` - Core MFA framework
  - `webauthn_autofill` - WebAuthn login with autofill (JRuby excluded)
  - `webauthn_modify_email` - Email notifications for WebAuthn changes

### Migration Templates

All MFA migration templates already exist in both ActiveRecord and Sequel formats:

- `/lib/rodauth/rack/generators/migration/active_record/otp.erb`
- `/lib/rodauth/rack/generators/migration/active_record/webauthn.erb`
- `/lib/rodauth/rack/generators/migration/active_record/recovery_codes.erb`
- `/lib/rodauth/rack/generators/migration/active_record/otp_unlock.erb`
- `/lib/rodauth/rack/generators/migration/active_record/sms_codes.erb`
- Corresponding Sequel templates exist

## MFA Feature Analysis

### 1. Two-Factor Base (`two_factor_base`)

**Purpose**: Foundation for all 2FA features

**Core Concepts**:

- Tracks authentication methods in session (`authenticated_by` array)
- Distinguishes between partial auth (1 factor) and full auth (2+ factors)
- Provides unified management interface (`/multifactor-manage`)

**Routes**:

- `GET/POST /multifactor-manage` - Setup/remove 2FA methods
- `GET/POST /multifactor-auth` - Authenticate with 2nd factor
- `GET/POST /multifactor-disable` - Remove all 2FA methods

**Database Requirements**: None (uses session only)

**Rails Adapter Requirements**:

- **None** - Pure session/routing logic, no framework-specific code needed
- Already works via existing `Base`, `Csrf`, `Render` features

**Key Methods**:

- `two_factor_authenticated?` - Check if user passed 2FA
- `require_two_factor_authenticated` - Guard for protected routes
- `two_factor_update_session(type)` - Mark factor as authenticated
- `two_factor_remove` - Hook for cleaning up all factor data

### 2. OTP Feature (`otp`)

**Purpose**: Time-based One-Time Password (TOTP) authentication using authenticator apps

**Dependencies**:

- `two_factor_base`
- External gems: `rotp`, `rqrcode`

**Routes**:

- `GET/POST /otp-setup` - Generate and verify TOTP secret
- `GET/POST /otp-auth` - Authenticate with TOTP code
- `GET/POST /otp-disable` - Remove TOTP authentication

**Database Schema** (`account_otp_keys`):

```ruby
id: bigint (FK to accounts.id)
key: string (Base32 encoded secret)
num_failures: integer (lockout tracking)
last_use: timestamp (prevent replay attacks)
```

**Rails Adapter Requirements**:

**NEW FILE**: `/lib/rodauth/rack/rails/feature/otp.rb`

```ruby
module Rodauth::Rack::Rails::Feature::Otp
  extend ActiveSupport::Concern

  included do
    depends :otp
    auth_methods :rails_otp_provisioning_uri, :rails_otp_qr_code
  end

  # Override to use Rails asset pipeline if needed
  def otp_qr_code
    # Default implementation works fine
    # Could cache in Rails.cache for performance
    super
  end

  # For JSON APIs, return structured data
  def otp_setup_response
    if only_json?
      json_response_success(
        secret: otp_key,
        provisioning_uri: otp_provisioning_uri,
        qr_code: otp_qr_code
      )
    else
      super
    end
  end
end
```

**Controller Integration**: None needed - routes handled by Rodauth middleware

**View Requirements**:

- Server-rendered: Use Rodauth's built-in templates or override in `app/views/rodauth/`
- SPA: Use JSON API mode (`only_json?` configuration)

**JSON API Structure** (for SPAs):

```ruby
# Setup: POST /otp-setup
Request:
{
  "otp_secret": "base32secret",
  "otp_raw_secret": "raw_base32",  # if hmac enabled
  "otp": "123456",                  # verification code
  "password": "current_password"    # if required
}

Response (success):
{
  "success": "TOTP authentication is now setup",
  "redirect": "/multifactor-manage"
}

# Auth: POST /otp-auth
Request:
{
  "otp": "123456"
}

Response (success):
{
  "success": "You have been multifactor authenticated",
  "redirect": "/"
}
```

**Email Integration** (optional features):

- `otp_modify_email` - Send email on TOTP setup/disable
- Requires email configuration in Rodauth

**Special Considerations**:

- HMAC secret rotation support (for key wrapping)
- Lockout after 5 failed attempts (configurable)
- Time drift handling (30 second default)
- QR code generation requires SVG support

### 3. OTP Unlock Feature (`otp_unlock`)

**Purpose**: Allow users to unlock OTP after lockout via timed challenge

**Dependencies**: `otp`

**Routes**:

- `GET/POST /otp-unlock` - Unlock with consecutive successful OTPs

**Database Schema** (`account_otp_unlocks`):

```ruby
id: bigint (FK to accounts.id)
num_successes: integer (consecutive successes)
next_auth_attempt_after: timestamp (cooldown timer)
```

**Rails Adapter Requirements**:

- **None** - Works with existing adapters
- Consider adding auto-refresh JavaScript helper for cooldown UI

**Key Mechanism**:

- Requires 3 consecutive successful OTP verifications (configurable)
- 15-minute cooldown between attempts after failure
- 15-minute deadline to complete unlock process

### 4. WebAuthn Feature (`webauthn`)

**Purpose**: FIDO2/WebAuthn authentication (hardware keys, biometrics)

**Dependencies**:

- `two_factor_base`
- External gem: `webauthn`

**Routes**:

- `GET/POST /webauthn-setup` - Register new authenticator
- `GET/POST /webauthn-auth` - Authenticate with authenticator
- `GET/POST /webauthn-remove` - Remove authenticator
- `GET /webauthn-setup.js` - Setup JavaScript
- `GET /webauthn-auth.js` - Auth JavaScript

**Database Schema**:

`account_webauthn_user_ids`:

```ruby
id: bigint (FK to accounts.id)
webauthn_id: string (unique user ID for WebAuthn)
```

`account_webauthn_keys`:

```ruby
account_id: bigint (FK to accounts.id)
webauthn_id: string (credential ID)
public_key: string (credential public key)
sign_count: integer (replay attack prevention)
last_use: timestamp
PRIMARY KEY (account_id, webauthn_id)
```

**Rails Adapter Requirements**:

**NEW FILE**: `/lib/rodauth/rack/rails/feature/webauthn.rb`

```ruby
module Rodauth::Rack::Rails::Feature::Webauthn
  extend ActiveSupport::Concern

  included do
    depends :webauthn
    auth_methods :rails_webauthn_js_nonce
  end

  # Integrate with Rails asset pipeline
  def webauthn_setup_js_path
    if defined?(Rails.application.assets)
      asset_path('rodauth/webauthn_setup.js')
    else
      super
    end
  end

  def webauthn_auth_js_path
    if defined?(Rails.application.assets)
      asset_path('rodauth/webauthn_auth.js')
    else
      super
    end
  end

  # Add CSP nonce support
  def webauthn_setup_js
    js = super
    if nonce = rails_controller_instance.content_security_policy_nonce
      # Wrap in script tag with nonce
      %(<script nonce="#{nonce}">#{js}</script>)
    else
      js
    end
  end

  # JSON API responses
  def new_webauthn_credential
    credential_options = super
    if only_json?
      # Return serializable options for SPA
      credential_options.as_json
    else
      credential_options
    end
  end
end
```

**JavaScript Assets**:

- Copy Rodauth JS files to `app/assets/javascripts/rodauth/`
- Or serve directly from gem via routes
- Required for credential creation/verification

**JSON API Structure**:

```ruby
# Setup: GET /webauthn-setup
Response:
{
  "publicKey": {
    "challenge": "base64_challenge",
    "rp": { "name": "App", "id": "example.com" },
    "user": { "id": "base64_user_id", "name": "user@example.com" },
    "pubKeyCredParams": [...],
    "authenticatorSelection": {...},
    "timeout": 120000,
    "excludeCredentials": [...]
  },
  "challenge_hmac": "hmac_for_verification"
}

# Setup: POST /webauthn-setup
Request:
{
  "webauthn_setup": {
    "id": "credential_id",
    "rawId": "base64_raw_id",
    "response": {...},
    "type": "public-key"
  },
  "webauthn_setup_challenge": "challenge",
  "webauthn_setup_challenge_hmac": "hmac",
  "password": "current_password"
}
```

**Email Integration** (optional):

- `webauthn_modify_email` - Send email on authenticator add/remove
- Already partially implemented in test app

**Special Considerations**:

- Requires HTTPS in production
- Origin validation critical for security
- Multiple authenticators per account supported
- Sign count verification prevents cloning
- Ruby gem compatibility: WebAuthn 3.x+ recommended

### 5. WebAuthn Supporting Features

#### `webauthn_login`

- Allows WebAuthn as primary authentication method
- Skip password requirement if WebAuthn succeeds
- Integrates with multi-phase login

#### `webauthn_autofill`

- Browser-native credential picker (conditional UI)
- Requires resident keys/discoverable credentials
- Already implemented in test app

#### `webauthn_verify_account`

- Use WebAuthn for account verification instead of email
- Useful for passwordless flows

**Rails Integration**: Minimal - these extend `webauthn` feature, no additional adapter code needed

### 6. Recovery Codes Feature (`recovery_codes`)

**Purpose**: Backup authentication method when primary factor unavailable

**Dependencies**: `two_factor_base`

**Routes**:

- `GET/POST /recovery-codes` - View/add recovery codes
- `GET/POST /recovery-auth` - Authenticate with recovery code

**Database Schema** (`account_recovery_codes`):

```ruby
id: bigint (FK to accounts.id)
code: string (random 32-byte hex)
PRIMARY KEY (id, code)
```

**Rails Adapter Requirements**:

- **None** - Pure database operations, existing adapters sufficient

**Key Mechanism**:

- 16 codes generated by default (configurable)
- Single-use codes (deleted after successful auth)
- Auto-add when OTP/WebAuthn/SMS setup (configurable)
- Auto-remove when all 2FA methods removed (configurable)
- Can be primary 2FA if no other methods enabled

**JSON API Structure**:

```ruby
# View: GET /recovery-codes (requires 2FA authenticated)
Response:
{
  "recovery_codes": [
    "4f3c8b9a2e7d6f1a...",
    "9b2e7d6f1a4f3c8b..."
  ],
  "codes_remaining": 16,
  "codes_limit": 16
}

# Add: POST /recovery-codes
Request:
{
  "password": "current_password",
  "add": "1"
}

Response:
{
  "recovery_codes": ["..."],  # newly added codes
  "success": "Additional authentication recovery codes have been added"
}
```

### 7. SMS Codes Feature (`sms_codes`)

**Purpose**: SMS-based 2FA (backup method, less secure than OTP/WebAuthn)

**Dependencies**: `two_factor_base`

**Routes**:

- `GET/POST /sms-setup` - Register phone number
- `GET/POST /sms-confirm` - Verify phone with code
- `GET/POST /sms-request` - Request authentication code
- `GET/POST /sms-auth` - Authenticate with SMS code
- `GET/POST /sms-disable` - Remove SMS 2FA

**Database Schema** (`account_sms_codes`):

```ruby
id: bigint (FK to accounts.id)
phone_number: string
code: string (6-digit, short-lived)
code_issued_at: timestamp
num_failures: integer (NULL = pending confirmation)
```

**Rails Adapter Requirements**:

**NEW FILE**: `/lib/rodauth/rack/rails/feature/sms.rb`

```ruby
module Rodauth::Rack::Rails::Feature::Sms
  extend ActiveSupport::Concern

  included do
    depends :sms_codes
    auth_methods :rails_sms_send
  end

  # Integrate with Rails SMS provider (Twilio, SNS, etc.)
  def sms_send(phone, message)
    # Use ActiveJob for async delivery
    SmsDeliveryJob.perform_later(phone, message)

    # Or direct integration:
    # Rails.application.credentials.dig(:twilio, :client)
    #   .messages.create(to: phone, from: twilio_number, body: message)
  end

  # JSON API response
  def sms_request_response
    if only_json?
      json_response_success(
        message: "SMS authentication code has been sent",
        expires_in: sms_code_allowed_seconds
      )
    else
      super
    end
  end
end
```

**Special Considerations**:

- Requires SMS gateway integration (Twilio, AWS SNS, etc.)
- Two-phase setup: register + confirm with code
- Codes expire after 5 minutes (configurable)
- Less secure than TOTP/WebAuthn - should be backup only
- Consider rate limiting to prevent SMS abuse
- Phone number validation/normalization

**Configuration Example**:

```ruby
configure do
  enable :sms_codes

  # Must implement this method
  sms_send do |phone, message|
    TwilioService.send_sms(phone, message)
  end

  sms_codes_primary? false  # Make it backup-only
  auto_add_recovery_codes? true  # Add recovery codes on SMS setup
end
```

## Integration Architecture

### Rails-Specific Adapter Pattern

All MFA features follow this structure:

```
/lib/rodauth/rack/rails/feature/
  mfa.rb              # Optional: Unified MFA module
  otp.rb              # OTP-specific Rails integrations
  webauthn.rb         # WebAuthn-specific Rails integrations
  sms.rb              # SMS-specific Rails integrations
```

Each module:

1. Extends `ActiveSupport::Concern`
2. Declares `depends :feature_name`
3. Overrides methods for Rails-specific behavior:
   - Asset pipeline integration
   - ActiveJob integration (for SMS/email)
   - JSON API responses
   - CSP nonce handling

### Hanami-Specific Adapter Pattern

Mirror Rails structure:

```
/lib/rodauth/rack/hanami/feature/
  mfa.rb
  otp.rb
  webauthn.rb
  sms.rb
```

Key differences:

- No ActiveSupport::Concern
- Use Hanami::View for rendering
- Use Hanami assets system
- ROM integration for database queries

### Shared Components (No Adapter Needed)

These features work identically across frameworks:

- `two_factor_base` - Pure routing/session logic
- `recovery_codes` - Pure database operations
- `otp_unlock` - Pure database operations
- `webauthn_login` - Extends webauthn, no new adapter code
- `webauthn_autofill` - Extends webauthn, no new adapter code

## Implementation Checklist

### Phase 1: Core OTP Support

- [ ] Create `/lib/rodauth/rack/rails/feature/otp.rb`
- [ ] Add OTP JSON API response methods
- [ ] Create example Rails controller for OTP setup
- [ ] Add integration test for OTP flow
- [ ] Document QR code rendering options
- [ ] Create Hanami equivalent

### Phase 2: WebAuthn Support

- [ ] Create `/lib/rodauth/rack/rails/feature/webauthn.rb`
- [ ] Copy Rodauth JS files to gem assets
- [ ] Add asset pipeline integration
- [ ] Add CSP nonce support
- [ ] Add JSON API response methods
- [ ] Test with multiple authenticator types
- [ ] Create Hanami equivalent

### Phase 3: Recovery Codes

- [ ] Add JSON API response methods for recovery codes
- [ ] Document auto-add/auto-remove configuration
- [ ] Add example of custom code generation
- [ ] Integration tests

### Phase 4: SMS Codes (Optional)

- [ ] Create `/lib/rodauth/rack/rails/feature/sms.rb`
- [ ] Document SMS gateway integration patterns
- [ ] Example ActiveJob implementation
- [ ] Rate limiting recommendations
- [ ] Create Hanami equivalent

### Phase 5: Documentation

- [ ] Rails integration guide
- [ ] Hanami integration guide
- [ ] JSON API reference
- [ ] Security best practices
- [ ] Migration guide from other auth systems

## Security Considerations

### Critical Requirements

1. **HTTPS Only**: WebAuthn requires HTTPS in production
2. **Origin Validation**: Correctly configure `webauthn_origin` and `webauthn_rp_id`
3. **CSRF Protection**: All POST routes must validate CSRF tokens
4. **Session Security**: Use secure, httponly cookies
5. **Rate Limiting**: Implement on all 2FA endpoints

### Best Practices

1. Require OTP/WebAuthn over SMS when available
2. Enable `auto_add_recovery_codes?` for backup access
3. Set `two_factor_modifications_require_password?` to true
4. Log all 2FA changes for audit trail
5. Implement account lockout after repeated failures

### HMAC Secret Configuration

For production deployments using HMAC-wrapped secrets:

```ruby
configure do
  hmac_secret ENV['RODAUTH_HMAC_SECRET']
  hmac_old_secret ENV['RODAUTH_HMAC_OLD_SECRET']  # For rotation

  # Enables HMAC wrapping for OTP keys
  otp_keys_use_hmac? true
end
```

## JSON API Design Pattern

All MFA features support JSON-only mode via `only_json?` configuration:

```ruby
configure do
  only_json? true  # Disable HTML templates

  # Custom JSON responses
  json_response_success_key :message
  json_response_error_key :error
end
```

Response format:

```ruby
# Success
{
  "message": "Operation successful",
  "field_errors": {},  # Empty on success
  "redirect": "/next-page"
}

# Error
{
  "error": "Operation failed",
  "field_errors": {
    "otp": "Invalid authentication code"
  },
  "status": 422
}
```

## Template Customization

Server-rendered apps can override any Rodauth template:

```
app/views/rodauth/
  otp_setup.html.erb
  otp_auth.html.erb
  webauthn_setup.html.erb
  webauthn_auth.html.erb
  recovery_codes.html.erb
  two_factor_manage.html.erb
```

Hanami:

```
slices/main/templates/rodauth/
  otp_setup.html.erb
  ...
```

## Performance Optimizations

### Database Indexes

Ensure migrations include:

```ruby
add_index :account_otp_keys, :id, unique: true
add_index :account_webauthn_keys, [:account_id, :webauthn_id], unique: true
add_index :account_recovery_codes, [:id, :code], unique: true
```

### Caching Strategies

```ruby
# Cache OTP QR codes temporarily
def otp_qr_code
  Rails.cache.fetch("otp_qr_#{account_id}", expires_in: 5.minutes) do
    super
  end
end

# Cache WebAuthn credential options
def new_webauthn_credential
  # Generate fresh for security, don't cache
  super
end
```

### Async Operations

```ruby
# Send SMS codes asynchronously
def sms_send(phone, message)
  SmsDeliveryJob.perform_later(phone, message)
end

# Send email notifications asynchronously
after_otp_setup do
  OtpNotificationMailer.setup_notification(account_id).deliver_later
end
```

## Testing Strategy

### Required Test Coverage

1. **Unit Tests**: Each adapter module
2. **Integration Tests**: Complete MFA flows
3. **Security Tests**:
   - CSRF validation
   - Rate limiting
   - Lockout mechanisms
   - Replay attack prevention
4. **Browser Tests**: WebAuthn JavaScript integration
5. **API Tests**: JSON-only mode

### Example Test Structure

```ruby
RSpec.describe "OTP Authentication" do
  context "with Rails adapter" do
    it "generates valid TOTP secret"
    it "validates TOTP codes with drift"
    it "locks out after failures"
    it "integrates with recovery codes"
    it "sends JSON responses in API mode"
  end
end

RSpec.describe "WebAuthn Authentication" do
  context "with Rails adapter" do
    it "registers authenticator"
    it "authenticates with credential"
    it "validates origin and RP ID"
    it "handles CSP nonces"
    it "supports multiple authenticators"
  end
end
```

## Migration from Other Systems

### From Devise Two-Factor

```ruby
# Map existing TOTP secrets
Account.find_each do |account|
  if account.otp_secret.present?
    RodauthApp.rodauth(:main).otp_add_key(account.otp_secret)
  end
end
```

### From Clearance/Sorcery

These don't have built-in 2FA - Rodauth adds new capability

## Deployment Checklist

- [ ] Generate HMAC secret for production
- [ ] Configure HTTPS for WebAuthn
- [ ] Set up SMS gateway credentials
- [ ] Configure email delivery for notifications
- [ ] Run database migrations
- [ ] Test all 2FA flows in staging
- [ ] Set up monitoring for auth failures
- [ ] Configure rate limiting
- [ ] Review CSP policies for WebAuthn JS
- [ ] Document recovery process for locked-out users

## Open Questions / Decisions Needed

1. **Asset Management**: Should WebAuthn JS be in gem assets or served via routes?
   - Recommendation: Both options, configurable

2. **SMS Provider**: Should gem include example SMS implementations?
   - Recommendation: Yes, add examples for Twilio, AWS SNS

3. **Default Configuration**: What 2FA methods should be recommended?
   - Recommendation: OTP + WebAuthn + Recovery Codes

4. **Naming**: Use "MFA" or "2FA" in public APIs?
   - Current: "two_factor" (matches Rodauth)
   - Recommendation: Keep for consistency

5. **Rails Generator**: Should there be `rails g rodauth:mfa` generator?
   - Recommendation: Yes, generates all MFA migrations + config

## Conclusion

All Rodauth MFA features are production-ready and well-designed. The integration into rodauth-rack requires minimal adapter code:

**Required New Adapters**:

- Rails: `otp.rb`, `webauthn.rb`, `sms.rb` (3 files)
- Hanami: Same 3 files

**Works Without Adapters**:

- `two_factor_base`, `recovery_codes`, `otp_unlock`, all WebAuthn extensions

**Migration Templates**: Already complete

The main integration work is:

1. Asset pipeline integration for WebAuthn JS
2. SMS gateway abstraction for `sms_codes`
3. JSON API response formatting
4. Documentation and examples

Total estimated effort: 2-3 days for Rails, 2-3 days for Hanami, plus documentation.
