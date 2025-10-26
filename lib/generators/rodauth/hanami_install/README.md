# Rodauth Hanami Install Generator

Generates Rodauth configuration files for Hanami 2.x applications.

## Usage

```bash
# Basic installation
rr generate hanami:install

# With options
rr generate hanami:install [options]
```

## Options

- `--json` - Configure JSON API support
- `--jwt` - Configure JWT authentication
- `--argon2` - Use Argon2 for password hashing (instead of bcrypt)
- `--api-only` - Configure for API-only application
- `--prefix=NAME` - Set custom prefix for account tables
- `--table=NAME` - Set custom name for accounts table

## Generated Files

### 1. `config/providers/rodauth.rb`

Hanami provider that registers Rodauth middleware and makes it available in the dependency injection container.

```ruby
Hanami.app.register_provider :rodauth do
  prepare do
    require "rodauth/rack/hanami"
  end

  start do
    require "rodauth_app"

    target.app.config.middleware.use(
      Rodauth::Rack::Hanami::Middleware
    )

    register "rodauth" do
      Rodauth::Rack::Hanami
    end
  end
end
```

### 2. `lib/rodauth_app.rb`

Roda application that handles Rodauth routing.

```ruby
class RodauthApp < Rodauth::Rack::Hanami::App
  configure RodauthMain

  route do |r|
    rodauth.load_memory  # autologin remembered users
    r.rodauth            # route rodauth requests
  end
end

Rodauth::Rack::Hanami.app = RodauthApp
```

### 3. `lib/rodauth_main.rb`

Main Rodauth configuration with all authentication features and settings.

```ruby
class RodauthMain < Rodauth::Rack::Hanami::Auth
  configure do
    enable :hanami
    enable :create_account, :verify_account, :login, :logout, :remember,
           :reset_password, :change_password, :change_login,
           :verify_login_change, :close_account

    accounts_table :accounts
    email_from "noreply@example.com"
    # ... more configuration
  end
end
```

## Next Steps

After running the generator:

1. **Add dependencies** to your `Gemfile`:

   ```ruby
   gem 'rodauth-rack', '~> 1.0'
   gem 'tilt', '~> 2.4'
   gem 'bcrypt', '~> 3.1'  # or 'argon2'
   ```

2. **Generate database migration**:

   ```bash
   rr generate migration base reset_password verify_account
   ```

3. **Run the migration**:

   ```bash
   bundle exec hanami db migrate
   ```

4. **Start your Hanami app**:

   ```bash
   bundle exec hanami server
   ```

5. **Access Rodauth**:
   - Visit <http://localhost:2300/login>
   - Visit <http://localhost:2300/create-account>

## View Templates

Rodauth uses Tilt for rendering view templates. You have two options:

### Option 1: Use Built-in Templates (Quickest)

Rodauth includes built-in ERB templates for all features. These work out of the box but have minimal styling.

### Option 2: Create Custom Templates (Recommended)

Create your own templates in `app/templates/rodauth/`:

```text
app/templates/rodauth/
├── login.html.erb
├── create_account.html.erb
├── reset_password_request.html.erb
├── reset_password.html.erb
└── verify_account.html.erb
```

Example template (`app/templates/rodauth/login.html.erb`):

```erb
<div class="rodauth-form">
  <h1>Login</h1>

  <%= rodauth.render('_login_form') %>

  <p>
    <%= rodauth.create_account_link('Create account') if rodauth.create_account? %>
    <%= rodauth.reset_password_request_link('Forgot password?') if rodauth.reset_password_request? %>
  </p>
</div>
```

See the [Rodauth documentation](https://rodauth.jeremyevans.net/) for available view methods.

## Email Templates

For email templates, create files in `app/templates/mailers/rodauth/`:

```text
app/templates/mailers/rodauth/
├── verify_account.html.erb
├── verify_account.text.erb
├── reset_password.html.erb
└── reset_password.text.erb
```

## Configuration Modes

### Standard Web Application

```bash
rr generate hanami:install
```

Generates configuration for traditional web app with HTML views and sessions.

### JSON API

```bash
rr generate hanami:install --json
```

Enables JSON responses for API requests. HTML rendering is skipped when `only_json? true`.

### JWT Authentication

```bash
rr generate hanami:install --jwt
```

Stateless JWT authentication. No sessions or cookies.

### API-Only

```bash
rr generate hanami:install --api-only --jwt
```

Combined API-only mode with JWT. Minimal configuration.

## Customization

Edit the generated files to customize:

- **Features**: Add/remove features in `lib/rodauth_main.rb`
- **Routes**: Customize routing in `lib/rodauth_app.rb`
- **Middleware**: Adjust middleware configuration in `config/providers/rodauth.rb`
- **Email settings**: Configure email delivery in `lib/rodauth_main.rb`

## Examples

### Add Two-Factor Authentication

```ruby
# lib/rodauth_main.rb
configure do
  enable :hanami
  enable :create_account, :login, :logout,
         :otp,  # One-time password (TOTP)
         :recovery_codes  # Backup codes

  # ... rest of configuration
end
```

### Custom Account Model

```ruby
# lib/rodauth_main.rb
configure do
  enable :hanami
  accounts_table :users
  login_column :email

  # ... rest of configuration
end
```

### Multiple Configurations

```ruby
# lib/rodauth_app.rb
class RodauthApp < Rodauth::Rack::Hanami::App
  # Primary configuration for users
  configure RodauthMain

  # Secondary configuration for admins
  configure RodauthAdmin, :admin

  route do |r|
    r.rodauth         # user routes at /login, /logout, etc.
    r.rodauth(:admin)  # admin routes at /admin/login, /admin/logout, etc.
  end
end
```

## Troubleshooting

### Views Not Rendering

1. Check that `tilt` gem is installed
2. Verify templates exist in `app/templates/rodauth/`
3. Check file permissions

### Email Not Sending

1. Configure email delivery method in Hanami
2. Set proper `email_from` address
3. Check mailer configuration

### Database Errors

1. Ensure migration has been run
2. Check database connection in `config/app.rb`
3. Verify table names match configuration

## Further Reading

- [Rodauth Documentation](https://rodauth.jeremyevans.net/)
- [Rodauth Features](https://rodauth.jeremyevans.net/features.html)
- [Hanami Documentation](https://guides.hanamirb.org)
