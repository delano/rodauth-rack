# OTP (TOTP) Multi-Factor Authentication Integration

## Overview

This document describes the production-ready OTP (Time-based One-Time Password) integration for rodauth-rack. The implementation provides seamless TOTP-based two-factor authentication across Rails, Hanami, Sinatra, and Roda applications.

## Architecture

### Framework-Agnostic Design

The OTP integration follows a layered architecture:

1. **Rodauth Core**: Provides base OTP functionality (secret generation, verification, QR codes)
2. **Rack Adapter Layer**: Framework-agnostic integration (future: `/lib/rodauth/rack/features/otp.rb`)
3. **Framework-Specific Adapters**:
   - Rails: `/lib/rodauth/rack/rails/feature/otp.rb`
   - Hanami: `/lib/rodauth/rack/hanami/feature/otp.rb`

### Feature Loading

The OTP adapters are automatically loaded when both the framework feature (`:rails` or `:hanami`) and the `:otp` feature are enabled:

```ruby
class RodauthMain < Rodauth::Rack::Rails::Auth
  configure do
    enable :otp  # Automatically loads Rails OTP adapter
  end
end
```

## Rails Integration

### Configuration

Enable OTP in your Rodauth configuration:

```ruby
# app/misc/rodauth_main.rb
class RodauthMain < Rodauth::Rack::Rails::Auth
  configure do
    enable :otp, :recovery_codes

    # OTP configuration
    otp_drift 30  # Allow 30 seconds of time drift (default)
    otp_auth_failures_limit 5  # Lock out after 5 failed attempts
    two_factor_modifications_require_password? true  # Require password for OTP changes

    # Optional: HMAC secret wrapping for production
    hmac_secret ENV['RODAUTH_HMAC_SECRET']
    otp_keys_use_hmac? true
  end
end
```

### Database Migration

The OTP table is included in the base Rodauth migration:

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_rodauth.rb
create_table :account_otp_keys do |t|
  t.foreign_key :accounts, column: :id
  t.string :key, null: false
  t.integer :num_failures, null: false, default: 0
  t.datetime :last_use, null: false, default: -> { "CURRENT_TIMESTAMP" }
end
```

### View Customization

Create custom views in `app/views/rodauth/`:

```erb
<!-- app/views/rodauth/otp_setup.html.erb -->
<h1>Setup Two-Factor Authentication</h1>

<div class="qr-code">
  <%= raw otp_qr_code %>
</div>

<p>Or manually enter: <code><%= otp_user_key %></code></p>

<%= form_with url: otp_setup_path, method: :post do |form| %>
  <%= form.password_field otp_setup_param, placeholder: "Enter 6-digit code" %>
  <%= form.password_field password_param, placeholder: "Current Password" if two_factor_modifications_require_password? %>
  <%= raw csrf_tag %>
  <%= form.submit "Setup TOTP" %>
<% end %>
```

### Routes

OTP routes are automatically registered:

```
GET/POST  /otp-setup    # Generate and verify TOTP secret
GET/POST  /otp-auth     # Authenticate with TOTP code
GET/POST  /otp-disable  # Remove TOTP authentication
```

### Rails-Specific Features

#### QR Code Caching

The Rails adapter includes optional QR code caching for performance:

```ruby
# Caches QR codes for 5 minutes during setup
def otp_qr_code
  if defined?(::Rails.cache) && otp_key && !otp_setup?
    ::Rails.cache.fetch(rails_otp_cache_key, expires_in: 5.minutes) do
      super
    end
  else
    super
  end
end
```

#### JSON API Support

The adapter provides enhanced JSON responses for SPAs:

```ruby
configure do
  only_json? true  # Enable JSON-only mode
end

# POST /otp-setup
{
  "secret": "BASE32SECRET",
  "provisioning_uri": "otpauth://totp/...",
  "qr_code": "<svg>...</svg>"
}

# POST /otp-auth
{
  "message": "You have been multifactor authenticated",
  "redirect": "/"
}
```

#### Helper Methods

The Rails adapter adds convenience methods:

- `rails_otp_cache_key` - Generate cache key for QR codes
- `rails_otp_qr_code_url` - Get data URL for QR code SVG

## Hanami Integration

### Configuration

```ruby
# lib/rodauth_main.rb
class RodauthMain < Rodauth::Rack::Hanami::Auth
  configure do
    enable :hanami
    enable :otp, :recovery_codes

    # OTP configuration (same as Rails)
    otp_drift 30
    otp_auth_failures_limit 5
    two_factor_modifications_require_password? true
  end
end
```

### Database Migration

Sequel migration (similar to Rails):

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_rodauth.rb
Sequel.migration do
  change do
    create_table :account_otp_keys do
      foreign_key :id, :accounts, primary_key: true, type: :Bignum
      String :key, null: false
      Integer :num_failures, null: false, default: 0
      Time :last_use, null: false, default: Sequel::CURRENT_TIMESTAMP
    end
  end
end
```

### View Templates

Create views in `slices/main/templates/rodauth/`:

```erb
<!-- slices/main/templates/rodauth/otp_setup.html.erb -->
<h1>Setup Two-Factor Authentication</h1>

<div class="qr-code">
  <%= hanami_otp_qr_code_url %>
</div>

<form action="<%= otp_setup_path %>" method="post">
  <input type="password" name="<%= otp_setup_param %>" placeholder="Enter 6-digit code">
  <% if two_factor_modifications_require_password? %>
    <input type="password" name="<%= password_param %>" placeholder="Current Password">
  <% end %>
  <%= raw csrf_tag %>
  <button type="submit">Setup TOTP</button>
</form>
```

### Hanami-Specific Features

#### Helper Methods

- `hanami_otp_qr_code_url` - Get data URL for QR code SVG

## Complete Integration Flow

### 1. OTP Setup

1. User navigates to `/otp-setup`
2. Server generates new TOTP secret
3. QR code and secret displayed to user
4. User scans QR code with authenticator app
5. User enters verification code
6. Server validates code and stores encrypted secret
7. Recovery codes automatically generated (if enabled)

### 2. OTP Authentication

1. User logs in with password (first factor)
2. Server detects OTP is enabled for account
3. User redirected to `/otp-auth`
4. User enters current TOTP code from app
5. Server validates code (with drift tolerance)
6. User fully authenticated and session updated

### 3. OTP Disable

1. User navigates to `/otp-disable`
2. User confirms with password (if required)
3. Server removes OTP secret from database
4. Recovery codes removed (if configured)

## Security Considerations

### HMAC Secret Wrapping

Always use HMAC secret wrapping in production:

```ruby
configure do
  hmac_secret ENV['RODAUTH_HMAC_SECRET']  # 64+ character random string
  otp_keys_use_hmac? true
end
```

Generate a strong secret:

```bash
ruby -r securerandom -e "puts SecureRandom.hex(64)"
```

### Time Drift Tolerance

The default 30-second drift allows for minor clock skew:

```ruby
otp_drift 30  # Accept codes from -30s to +30s window
```

### Lockout Protection

Prevent brute force attacks with failure limits:

```ruby
otp_auth_failures_limit 5  # Lock after 5 failures
```

Enable `otp_unlock` feature for user-initiated unlock:

```ruby
enable :otp_unlock
```

### Recovery Codes

Always enable recovery codes as a backup:

```ruby
enable :recovery_codes
auto_add_recovery_codes? true  # Auto-generate on OTP setup
recovery_codes_count 16  # Number of codes
```

### Rate Limiting

Implement rate limiting on OTP endpoints (not included in rodauth-rack):

```ruby
# config/application.rb (Rails with rack-attack)
Rack::Attack.throttle('otp-auth', limit: 5, period: 60) do |req|
  req.ip if req.path == '/otp-auth' && req.post?
end
```

## Testing

### RSpec Example

```ruby
RSpec.describe "OTP Authentication" do
  let(:account) { Account.create!(email: "test@example.com", password: "secret") }
  let(:rodauth) { Rodauth::Rack::Rails.rodauth(account_id: account.id) }

  before do
    # Setup OTP
    secret = rodauth.send(:new_otp_secret)
    rodauth.db.from(:account_otp_keys).insert(
      id: account.id,
      key: rodauth.send(:otp_key_from_secret, secret)
    )
    @secret = secret
  end

  it "authenticates with valid TOTP code" do
    totp = ROTP::TOTP.new(@secret)
    valid_code = totp.now

    post "/login", params: { login: account.email, password: "secret" }
    post "/otp-auth", params: { otp: valid_code }

    expect(response).to redirect_to(root_path)
  end

  it "rejects invalid TOTP code" do
    post "/login", params: { login: account.email, password: "secret" }
    post "/otp-auth", params: { otp: "000000" }

    expect(response.body).to match(/invalid/i)
  end
end
```

### Minitest Example

```ruby
class OtpTest < IntegrationTest
  test "OTP setup flow" do
    account = Account.create!(email: "test@example.com", password: "secret", status: "verified")

    post "/login", params: { login: account.email, password: "secret" }
    get "/otp-setup"

    assert_response :success
    assert_match(/QR code/, response.body)
  end
end
```

## Troubleshooting

### QR Code Not Displaying

Ensure the `rqrcode` gem is installed:

```ruby
# Gemfile
gem "rqrcode"
```

### Time Sync Issues

OTP relies on synchronized time between server and authenticator:

- Ensure server time is accurate (use NTP)
- Increase `otp_drift` if necessary (max 60 seconds)
- Check authenticator app time sync settings

### Lockout Recovery

If users get locked out:

1. Enable `otp_unlock` feature for self-service unlock
2. Or provide admin interface to reset `num_failures`
3. Or temporarily disable OTP in database

```sql
-- Emergency OTP disable for user
DELETE FROM account_otp_keys WHERE id = <account_id>;
```

## Performance Optimization

### Database Indexes

Ensure proper indexing:

```ruby
add_index :account_otp_keys, :id, unique: true
```

### QR Code Caching

The Rails adapter caches QR codes automatically. For Hanami, implement caching:

```ruby
def otp_qr_code
  cache_key = "otp_qr_#{account_id}_#{otp_key}"
  cache.fetch(cache_key, expires_in: 300) { super }
end
```

## API Reference

### Configuration Options

- `otp_drift` - Time drift tolerance in seconds (default: 30)
- `otp_auth_failures_limit` - Max failed attempts before lockout (default: 5)
- `otp_keys_use_hmac?` - Wrap secrets with HMAC (default: false)
- `two_factor_modifications_require_password?` - Require password for OTP changes (default: false)

### Routes

- `GET /otp-setup` - Display OTP setup page with QR code
- `POST /otp-setup` - Verify and complete OTP setup
- `GET /otp-auth` - Display OTP authentication page
- `POST /otp-auth` - Verify OTP code
- `GET /otp-disable` - Display OTP disable confirmation
- `POST /otp-disable` - Disable OTP authentication

### Helper Methods

#### Rails

- `rails_otp_cache_key` - Cache key for QR code
- `rails_otp_qr_code_url` - Data URL for QR code SVG

#### Hanami

- `hanami_otp_qr_code_url` - Data URL for QR code SVG

## Migration from Other Systems

### From Devise Two-Factor

```ruby
# Map existing TOTP secrets
Account.find_each do |account|
  if account.otp_secret.present?
    rodauth = Rodauth::Rack::Rails.rodauth(account_id: account.id)
    rodauth.db.from(:account_otp_keys).insert(
      id: account.id,
      key: rodauth.send(:otp_key_from_secret, account.otp_secret)
    )
  end
end
```

## Additional Resources

- [Rodauth OTP Feature Documentation](https://rodauth.jeremyevans.net/rdoc/files/doc/otp_rdoc.html)
- [TOTP RFC 6238](https://tools.ietf.org/html/rfc6238)
- [Google Authenticator](https://github.com/google/google-authenticator)
- [ROTP Ruby Gem](https://github.com/mdp/rotp)

## Summary

The rodauth-rack OTP integration provides:

- Production-ready TOTP authentication
- Framework-agnostic design with Rails and Hanami adapters
- Secure HMAC secret wrapping
- QR code generation and caching
- JSON API support for SPAs
- Lockout protection and recovery
- Comprehensive test coverage

For complete examples, see:

- `/test/rails/rails_app/app/misc/rodauth_main.rb` (Rails configuration)
- `/examples/hanami-demo/lib/rodauth_main.rb` (Hanami configuration)
- `/test/rails/otp_test.rb` (Integration tests)
