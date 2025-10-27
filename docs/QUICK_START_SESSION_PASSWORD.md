# Quick Start: Session Management and Password Security

## 5-Minute Setup: Basic Security

Add session timeouts and password protection to any app:

```ruby
# lib/rodauth_main.rb
class RodauthMain < Rodauth::Auth
  configure do
    enable :session_expiration, :password_pepper

    # Session security
    max_session_lifetime 86400        # 1 day
    session_inactivity_timeout 1800   # 30 minutes

    # Password security
    password_pepper ENV["RODAUTH_PASSWORD_PEPPER"]
    password_maximum_bytes 60
  end
end
```

```ruby
# lib/rodauth_app.rb
route do |r|
  rodauth.check_session_expiration  # Add this line
  r.rodauth
end
```

```bash
# Generate pepper
ruby -r securerandom -e 'puts SecureRandom.hex(32)'

# Add to .env
echo "RODAUTH_PASSWORD_PEPPER=<your-generated-pepper>" >> .env
```

**Done!** Sessions now expire automatically, passwords are protected.

---

## 15-Minute Setup: Session Management

Add user-visible session management:

### 1. Generate Migration

```bash
rails generate rodauth:migration active_sessions
rails db:migrate
```

### 2. Enable Feature

```ruby
# lib/rodauth_main.rb
configure do
  enable :session_expiration, :active_sessions, :password_pepper

  # Session settings
  max_session_lifetime 30 * 86400
  session_inactivity_timeout 86400
  global_logout_label "Logout from all devices"
end
```

### 3. Add Route Check

```ruby
# lib/rodauth_app.rb
route do |r|
  rodauth.check_active_session  # Changed from check_session_expiration
  r.rodauth
end
```

### 4. Create Sessions Route

```ruby
# config/routes.rb (Rails)
resources :sessions, only: [:index, :destroy]

# app/controllers/sessions_controller.rb
class SessionsController < ApplicationController
  before_action :authenticate_user!

  def index
    @sessions = rodauth.account_sessions
  end

  def destroy
    rodauth.remove_active_session(params[:id])
    redirect_to sessions_path, notice: "Session terminated"
  end
end
```

### 5. Create View

```erb
<!-- app/views/sessions/index.html.erb -->
<h1>Active Sessions</h1>

<table class="table">
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
        <td><%= time_ago_in_words(session[:created_at]) %> ago</td>
        <td><%= time_ago_in_words(session[:last_use]) %> ago</td>
        <td>
          <% if session[:session_id] == rodauth.active_session_id %>
            <span class="badge badge-primary">Current</span>
          <% else %>
            <%= button_to "Terminate", session_path(session[:session_id]),
                method: :delete, class: "btn btn-sm btn-danger" %>
          <% end %>
        </td>
      </tr>
    <% end %>
  </tbody>
</table>
```

### 6. Add Logout Checkbox

```erb
<!-- app/views/rodauth/_global_logout_field.html.erb -->
<div class="form-check">
  <%= check_box_tag rodauth.global_logout_param, "t", false,
      id: "global-logout", class: "form-check-input" %>
  <%= label_tag "global-logout", rodauth.global_logout_label,
      class: "form-check-label" %>
</div>
```

**Done!** Users can now view and manage their sessions.

---

## 30-Minute Setup: Password Expiration (Compliance)

Add mandatory password changes:

### 1. Generate Migrations

```bash
rails generate rodauth:migration password_expiration disallow_password_reuse
rails db:migrate
```

### 2. Enable Features

```ruby
# lib/rodauth_main.rb
configure do
  enable :session_expiration, :active_sessions,
         :password_pepper, :password_expiration,
         :disallow_password_reuse

  # Password policy
  require_password_change_after 90 * 86400  # 90 days
  previous_passwords_to_check 12
end
```

### 3. Add Warning Banner

```erb
<!-- app/views/layouts/application.html.erb -->
<% if logged_in? && rodauth.respond_to?(:password_expired?) %>
  <% if rodauth.password_expired? %>
    <div class="alert alert-danger">
      Your password has expired.
      <%= link_to "Change it now", change_password_path, class: "alert-link" %>
    </div>
  <% elsif days_until_expiration && days_until_expiration <= 7 %>
    <div class="alert alert-warning">
      Your password expires in <%= days_until_expiration %> days.
      <%= link_to "Change it now", change_password_path, class: "alert-link" %>
    </div>
  <% end %>
<% end %>
```

### 4. Add Helper Method

```ruby
# app/helpers/application_helper.rb
def days_until_expiration
  return nil unless logged_in?
  return nil unless rodauth.respond_to?(:password_expired?)

  changed_at = DB[:account_password_change_times]
    .where(id: rodauth.account_id)
    .get(:changed_at)

  return nil unless changed_at

  expiration = changed_at + rodauth.require_password_change_after
  days = ((expiration - Time.now) / 86400).ceil
  days > 0 ? days : nil
end
```

### 5. Set Up Warning Emails

```ruby
# app/jobs/password_expiration_warning_job.rb
class PasswordExpirationWarningJob < ApplicationJob
  def perform
    expiring_soon = DB[:account_password_change_times]
      .where { changed_at < Time.now - 83.days }  # 7 days before expiration
      .where { changed_at > Time.now - 90.days }
      .select(:id)

    expiring_soon.each do |record|
      PasswordExpirationMailer.warning(record[:id]).deliver_later
    end
  end
end

# config/initializers/scheduled_jobs.rb
# Run daily at 8 AM
Sidekiq::Cron::Job.create(
  name: "Password expiration warnings",
  cron: "0 8 * * *",
  class: "PasswordExpirationWarningJob"
)
```

**Done!** Password expiration policy enforced.

---

## Common Configurations

### Standard Web App

```ruby
enable :session_expiration, :password_pepper

max_session_lifetime 86400
session_inactivity_timeout 1800
password_pepper ENV["RODAUTH_PASSWORD_PEPPER"]
password_maximum_bytes 60
password_minimum_length 12
```

### Enterprise SaaS

```ruby
enable :session_expiration, :active_sessions,
       :password_pepper, :disallow_password_reuse

max_session_lifetime 30 * 86400
session_inactivity_timeout 86400
password_pepper ENV["RODAUTH_PASSWORD_PEPPER"]
password_maximum_bytes 60
password_minimum_length 12
previous_passwords_to_check 10
```

### Banking / Healthcare

```ruby
enable :session_expiration, :single_session,
       :password_pepper, :password_expiration,
       :disallow_password_reuse

max_session_lifetime 4 * 3600
session_inactivity_timeout 900
password_pepper ENV["RODAUTH_PASSWORD_PEPPER"]
password_maximum_bytes 60
password_minimum_length 16
require_password_change_after 90 * 86400
previous_passwords_to_check 12
```

### API-Only Application

```ruby
enable :session_expiration, :active_sessions,
       :password_pepper, :json

only_json? true
max_session_lifetime 30 * 86400
session_inactivity_timeout 3600
password_pepper ENV["RODAUTH_PASSWORD_PEPPER"]
inactive_session_error_status 401
```

---

## Pepper Management

### Generate Pepper

```bash
# Ruby
ruby -r securerandom -e 'puts SecureRandom.hex(32)'

# Output: 64-character hex string
```

### Store Pepper

**Development** (.env file):

```bash
RODAUTH_PASSWORD_PEPPER=a1b2c3d4e5f6...
```

**Production** (Rails credentials):

```bash
rails credentials:edit
```

```yaml
rodauth:
  password_pepper: a1b2c3d4e5f6...
```

```ruby
password_pepper Rails.application.credentials.dig(:rodauth, :password_pepper)
```

### Rotate Pepper

```ruby
configure do
  enable :password_pepper

  # New pepper for new passwords
  password_pepper ENV["RODAUTH_PASSWORD_PEPPER_NEW"]

  # Old peppers for validation
  previous_password_peppers [
    ENV["RODAUTH_PASSWORD_PEPPER_OLD"],
    ""  # For passwords created without pepper
  ]

  # Auto-update hashes on login
  password_pepper_update? true
end
```

---

## Troubleshooting

### Session expires immediately

Check `max_session_lifetime` and `session_inactivity_timeout` values. Ensure they're in seconds:

```ruby
max_session_lifetime 86400    # Correct: 1 day
max_session_lifetime 1        # Wrong: 1 second
```

### Password validation fails after adding pepper

Existing passwords need users to login once to migrate. Add empty string to `previous_password_peppers`:

```ruby
previous_password_peppers [""]
```

### Active sessions not updating

Ensure `rodauth.check_active_session` is in route handler:

```ruby
route do |r|
  rodauth.check_active_session  # Must be before r.rodauth
  r.rodauth
end
```

### BCrypt truncation error

Set `password_maximum_bytes` based on pepper length:

```ruby
pepper_length = ENV["RODAUTH_PASSWORD_PEPPER"].bytesize  # e.g., 32
password_maximum_bytes 72 - pepper_length  # e.g., 40
```

---

## JSON API Examples

### Session Expiration

```bash
# Request with expired session
curl -X GET http://localhost:3000/api/profile \
  -H "Authorization: Bearer <expired-token>"

# Response
{
  "error": "Your session has expired",
  "status": 401
}
```

### Active Sessions List

```bash
curl -X GET http://localhost:3000/api/sessions \
  -H "Authorization: Bearer <token>"

# Response
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
```

### Terminate Session

```bash
curl -X DELETE http://localhost:3000/api/sessions/abc123 \
  -H "Authorization: Bearer <token>"

# Response
{
  "message": "Session terminated"
}
```

### Password Expired on Login

```bash
curl -X POST http://localhost:3000/api/login \
  -d '{"email":"user@example.com","password":"pass123"}'

# Response
{
  "error": "Your password has expired and must be changed",
  "reason": "password_expired",
  "change_password_url": "/change-password",
  "status": 403
}
```

---

## Testing

### RSpec Examples

```ruby
# spec/features/session_management_spec.rb
describe "Session Management" do
  it "expires session after inactivity" do
    login_as(user)
    travel 31.minutes
    visit dashboard_path
    expect(page).to have_current_path(login_path)
  end

  it "lists active sessions" do
    login_as(user)
    visit sessions_path
    expect(page).to have_content("Current")
  end

  it "terminates session remotely" do
    session1 = create_session_for(user)
    login_as(user)
    visit sessions_path
    click_button "Terminate", match: :first
    expect(page).to have_content("Session terminated")
  end
end

# spec/features/password_expiration_spec.rb
describe "Password Expiration" do
  it "redirects to change password when expired" do
    user.update(password_changed_at: 91.days.ago)
    login_as(user)
    expect(page).to have_current_path(change_password_path)
  end

  it "shows warning banner" do
    user.update(password_changed_at: 85.days.ago)
    login_as(user)
    visit dashboard_path
    expect(page).to have_content("Your password expires in 5 days")
  end
end
```

---

## Monitoring

### Track Session Activity

```ruby
# config/initializers/rodauth_monitoring.rb
Rodauth::Auth.configure do
  after_login do
    StatsD.increment("rodauth.login.success")
  end

  after_logout do
    StatsD.increment("rodauth.logout")
  end
end

# Monitor active sessions
Sidekiq.schedule do
  every("1.hour") do
    count = DB[:account_active_session_keys].count
    StatsD.gauge("rodauth.active_sessions", count)
  end
end
```

### Track Password Changes

```ruby
after_change_password do
  StatsD.increment("rodauth.password.changed")

  if password_expired?
    StatsD.increment("rodauth.password.changed_after_expiration")
  end
end
```

---

## Next Steps

1. Read full integration plan: `docs/FEATURE_INTEGRATION_PLAN.md`
2. Review summary: `docs/SESSION_PASSWORD_FEATURES_SUMMARY.md`
3. Check Rodauth documentation: <https://rodauth.jeremyevans.net/>
4. Test in development before production deployment
5. Document password/session policies for users
6. Set up monitoring and alerts
7. Plan pepper rotation schedule (annually)
8. Configure background jobs for session cleanup

---

## Support

- Rodauth documentation: <https://rodauth.jeremyevans.net/>
- Migration templates: `lib/rodauth/rack/generators/migration/`
- Example apps: `examples/hanami-demo/` and `test/rails/rails_app/`
- GitHub issues: <https://github.com/jeremyevans/rodauth/issues>
