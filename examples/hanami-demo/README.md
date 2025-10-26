# Hanami + Rodauth Demo Application

A minimal Hanami 2.x application demonstrating Rodauth integration for authentication using the `rodauth-rack` adapter.

## Overview

This demo application shows how to:

- Integrate Rodauth into a Hanami 2.x application
- Configure authentication with Sequel and SQLite
- Protect routes with authentication requirements
- Use Rodauth's built-in authentication UI
- Access Rodauth functionality from Hanami actions

## Features

The demo includes these Rodauth features:

- **Account Management**: Create account, verify account, close account
- **Login/Logout**: Standard login/logout with session management
- **Remember Me**: Persistent login sessions
- **Password Management**: Reset password, change password
- **Email Management**: Change login email, verify email changes
- **Grace Period**: Verify account grace period for unverified users

## Project Structure

```
hanami-demo/
├── app/
│   ├── actions/
│   │   └── home/
│   │       └── show.rb          # Public home page action
│   ├── templates/
│   │   ├── layouts/
│   │   │   └── app.html.erb     # Application layout
│   │   └── home/
│   │       └── show.html.erb    # Home page template
│   └── views/
│       └── home/
│           └── show.rb          # Home page view
├── config/
│   ├── app.rb                   # Hanami application config
│   ├── routes.rb                # Application routes
│   └── providers/
│       └── rodauth.rb           # Rodauth provider (generated)
├── lib/
│   ├── rodauth_app.rb           # Rodauth Roda app (generated)
│   └── rodauth_main.rb          # Rodauth configuration (generated)
├── slices/
│   └── main/
│       ├── actions/
│       │   └── dashboard/
│       │       └── show.rb      # Protected dashboard action
│       ├── templates/
│       │   └── dashboard/
│       │       └── show.html.erb
│       └── views/
│           └── dashboard/
│               └── show.rb
└── config.ru                    # Rack configuration
```

## Setup Instructions

### 1. Install Dependencies

```bash
cd examples/hanami-demo
bundle install
```

### 2. Create the Database

```bash
mkdir -p db
```

### 3. Run Database Migration

First, generate the Rodauth migration:

```bash
rr generate migration base reset_password verify_account
```

This creates a migration file in `db/migrate/`. Then run:

```bash
bundle exec hanami db migrate
```

Or manually with Sequel:

```bash
bundle exec sequel -m db/migrate sqlite://db/hanami_demo.db
```

### 4. Start the Server

```bash
bundle exec hanami server
```

Or with Rackup:

```bash
bundle exec rackup -p 2300
```

The application will be available at <http://localhost:2300>

## Usage Guide

### Creating an Account

1. Visit <http://localhost:2300>
2. Click "Create Account"
3. Fill in email and password
4. Submit the form

Since email sending is not configured, the verification link will be printed to the console. Copy that link and paste it into your browser to verify your account.

### Logging In

1. Visit <http://localhost:2300/login>
2. Enter your email and password
3. Submit the form

After successful login, you'll be redirected to `/dashboard`.

### Accessing Protected Pages

The `/dashboard` route is protected and requires authentication:

- If logged in: Shows your account ID and available account actions
- If not logged in: Redirects to the login page

### Authentication Flow

```
┌─────────────────┐
│   Home Page     │
│   (Public)      │
└────────┬────────┘
         │
    ┌────▼────┐
    │ Sign Up │
    └────┬────┘
         │
    ┌────▼────────────┐
    │ Verify Email    │
    │ (check console) │
    └────┬────────────┘
         │
    ┌────▼────┐
    │  Login  │
    └────┬────┘
         │
    ┌────▼──────────┐
    │   Dashboard   │
    │  (Protected)  │
    └───────────────┘
```

## Key Implementation Details

### Rodauth Provider

The provider (`config/providers/rodauth.rb`) registers Rodauth middleware and makes it available in the dependency injection container:

```ruby
Hanami.app.register_provider :rodauth do
  prepare do
    require "rodauth/rack/hanami"
  end

  start do
    require "rodauth_app"
    target.app.config.middleware.use(Rodauth::Rack::Hanami::Middleware)

    register "rodauth" do
      Rodauth::Rack::Hanami
    end
  end
end
```

### Protected Actions

Actions can require authentication by including the `rodauth` dependency and calling `rodauth.require_account`:

```ruby
module Main
  module Actions
    module Dashboard
      class Show < Main::Action
        include Deps["rodauth"]

        def handle(request, response)
          rodauth.require_account
          response.render(view, account_id: rodauth.account_id)
        end
      end
    end
  end
end
```

### Rodauth Configuration

The main configuration (`lib/rodauth_main.rb`) enables features and sets options:

```ruby
class RodauthMain < Rodauth::Rack::Hanami::Auth
  configure do
    enable :hanami
    enable :create_account, :verify_account, :login, :logout, :remember

    accounts_table :accounts
    login_redirect "/dashboard"
    logout_redirect "/"
  end
end
```

## Customization

### Adding More Features

Edit `lib/rodauth_main.rb` to enable additional Rodauth features:

```ruby
enable :lockout, :audit_logging, :password_complexity
```

See [Rodauth documentation](https://rodauth.jeremyevans.net/features.html) for all available features.

### Custom Templates

Generate Hanami views for Rodauth pages:

```bash
rodauth generate hanami:views
```

This creates customizable templates in your app for all Rodauth pages.

### Protecting More Routes

Add authentication to any action by including the dependency:

```ruby
include Deps["rodauth"]

def handle(request, response)
  rodauth.require_account
  # ... protected action code
end
```

## Development Notes

- **Database**: Uses SQLite for simplicity (configured in `config/app.rb`)
- **Email**: Not configured - verification links print to console
- **Sessions**: Stored in encrypted cookies (Rack default)
- **Password Hashing**: Uses bcrypt

## Production Considerations

Before deploying to production:

1. **Database**: Switch to PostgreSQL or MySQL
2. **Email**: Configure proper email delivery (SMTP, SendGrid, etc.)
3. **Sessions**: Use Redis or database-backed sessions
4. **HTTPS**: Enable SSL/TLS for secure cookie transmission
5. **Secrets**: Set `JWT_SECRET` and other secrets via environment variables
6. **Email Verification**: Configure proper email delivery system

## Troubleshooting

### Database Issues

If migrations fail, drop and recreate the database:

```bash
rm db/hanami_demo.db
bundle exec sequel -m db/migrate sqlite://db/hanami_demo.db
```

### Rodauth Not Loading

Ensure the provider is registered before the app starts. Check that `config/providers/rodauth.rb` exists and is being loaded.

### Session Not Persisting

Check that cookies are enabled in your browser. For "remember me" to work, persistent cookies must be allowed.

## Resources

- [Hanami Documentation](https://hanamirb.org)
- [Rodauth Documentation](https://rodauth.jeremyevans.net)
- [rodauth-rack Repository](https://github.com/delano/rodauth-rack)
- [Sequel Documentation](https://sequel.jeremyevans.net)

## License

This demo application is provided as-is for educational purposes.
