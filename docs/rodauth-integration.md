# Integrating Rodauth with Rack Applications

This guide shows how to integrate Rodauth into any Rack application using the official, recommended pattern.

## Overview

Rodauth is built on Roda, and **Roda can act as Rack middleware** when using the `:middleware` plugin. You don't need custom adapters or wrappers - just mount the Rodauth Roda app using the standard Rack `use` command.

## The Standard Pattern

### 1. Create a Rodauth Roda Application

```ruby
# lib/rodauth_app.rb or app/rodauth_app.rb
require 'roda'
require 'rodauth'
require 'sequel'

# Database connection (required by Rodauth)
DB = Sequel.connect(ENV['DATABASE_URL'] || 'sqlite://auth.db')

class RodauthApp < Roda
  # Enable middleware plugin so Roda can pass through requests
  plugin :middleware

  # Configure Rodauth
  plugin :rodauth do
    # Enable features
    enable :login, :logout, :create_account, :verify_account, :reset_password

    # Database
    db DB
    accounts_table :users

    # Email (if using email features)
    email_from 'noreply@example.com'

    # Redirects
    login_redirect '/dashboard'
    logout_redirect '/'
    verify_account_redirect '/dashboard'

    # Session
    session_key :user_id
  end

  route do |r|
    # Handle Rodauth routes
    r.rodauth

    # Require authentication for all remaining routes
    rodauth.require_authentication

    # Make Rodauth instance available to the main application
    env['rodauth'] = rodauth
  end
end
```

### 2. Mount in config.ru

```ruby
# config.ru
require_relative 'lib/rodauth_app'
require_relative 'lib/my_app'  # Your main application

# Session middleware (REQUIRED - must come before Rodauth)
use Rack::Session::Cookie,
  key: 'myapp.session',
  secret: ENV.fetch('SESSION_SECRET'),
  same_site: :lax,
  httponly: true

# Mount Rodauth as Rack middleware
use RodauthApp

# Run your main application
run MyApp
```

### 3. Access Rodauth in Your Application

The Rodauth instance is available via `env['rodauth']`:

```ruby
class MyApp
  def call(env)
    @rodauth = env['rodauth']

    # Check if logged in
    unless @rodauth.logged_in?
      return @rodauth.require_authentication
    end

    # Get current user ID
    user_id = @rodauth.account_id

    # Get current account (returns hash or Sequel model)
    account = @rodauth.account

    [200, {'Content-Type' => 'text/html'}, ["Hello, user #{user_id}"]]
  end
end
```

## Framework-Specific Examples

### Sinatra

```ruby
# app.rb
require 'sinatra/base'

class MyApp < Sinatra::Base
  # Helper to access Rodauth
  helpers do
    def rodauth
      request.env['rodauth']
    end
  end

  # Public route
  get '/' do
    if rodauth.logged_in?
      erb :homepage, locals: { user_id: rodauth.account_id }
    else
      erb :welcome
    end
  end

  # Protected route
  get '/dashboard' do
    rodauth.require_authentication
    erb :dashboard
  end

  # Logout (you could also use Rodauth's built-in route)
  post '/logout' do
    rodauth.logout
    redirect '/'
  end
end

# config.ru
use Rack::Session::Cookie, secret: ENV['SESSION_SECRET']
use RodauthApp
run MyApp
```

### Hanami

```ruby
# config.ru
require 'hanami'
require_relative 'lib/rodauth_app'

use Rack::Session::Cookie, secret: ENV['SESSION_SECRET']
use RodauthApp

run Hanami.app

# In your Hanami actions:
module MyApp
  module Actions
    module Dashboard
      class Index < Action
        def handle(request, response)
          rodauth = request.env['rodauth']
          rodauth.require_authentication

          response.body = "Welcome, user #{rodauth.account_id}"
        end
      end
    end
  end
end
```

### Cuba

```ruby
# app.rb
require 'cuba'

Cuba.define do
  def rodauth
    env['rodauth']
  end

  on root do
    if rodauth.logged_in?
      res.write "Welcome, user #{rodauth.account_id}"
    else
      res.write "Please log in"
    end
  end

  on 'dashboard' do
    rodauth.require_authentication
    res.write "Dashboard for user #{rodauth.account_id}"
  end
end

# config.ru
use Rack::Session::Cookie, secret: ENV['SESSION_SECRET']
use RodauthApp
run Cuba
```

### Plain Rack

```ruby
# app.rb
class MyApp
  def call(env)
    @env = env
    @rodauth = env['rodauth']

    case env['PATH_INFO']
    when '/'
      homepage
    when '/dashboard'
      dashboard
    else
      not_found
    end
  end

  private

  def homepage
    if @rodauth.logged_in?
      [200, {'Content-Type' => 'text/html'}, ["Welcome, #{@rodauth.account_id}"]]
    else
      [200, {'Content-Type' => 'text/html'}, ["<a href='/login'>Login</a>"]]
    end
  end

  def dashboard
    return @rodauth.require_authentication unless @rodauth.logged_in?

    [200, {'Content-Type' => 'text/html'}, ["Dashboard for #{@rodauth.account_id}"]]
  end

  def not_found
    [404, {'Content-Type' => 'text/html'}, ['Not Found']]
  end
end
```

## Common Rodauth Methods

Once you have access to the `rodauth` instance, you can use any Rodauth method:

### Authentication State

```ruby
rodauth.logged_in?              # Boolean: is user logged in?
rodauth.account_id              # Integer: current user's ID (or nil)
rodauth.account                 # Hash/Model: current account data
rodauth.session_value           # Get value from session
```

### Authentication Actions

```ruby
rodauth.require_authentication  # Redirect to login if not authenticated
rodauth.logout                  # Log out current user
rodauth.clear_session          # Clear session data
```

### Account Information

```ruby
rodauth.account[:email]         # Get account email
rodauth.account[:status_id]        # Get account status
rodauth.account_status_id       # Account status ID
```

## Database Setup

Rodauth requires database tables. Use the migration generator:

```ruby
require 'rodauth/tools'

generator = Rodauth::Tools::Migration.new(
  features: [:base, :verify_account, :reset_password],
  prefix: 'account'
)

puts generator.generate
```

Or create them manually. See [Rodauth documentation](https://rodauth.jeremyevans.net/documentation.html) for table schemas.

## Session Configuration

Rodauth requires session support. Configure it BEFORE mounting RodauthApp:

```ruby
# config.ru

# Option 1: Cookie-based sessions (simple)
use Rack::Session::Cookie,
  key: 'app.session',
  secret: ENV.fetch('SESSION_SECRET'),  # REQUIRED
  same_site: :lax,
  httponly: true,
  secure: ENV['RACK_ENV'] == 'production'

# Option 2: Redis sessions (production)
use Rack::Session::Redis,
  redis_server: ENV['REDIS_URL'],
  key: 'app.session',
  secret: ENV.fetch('SESSION_SECRET')

# Then mount Rodauth
use RodauthApp
run MyApp
```

## Important Notes

### 1. Session Middleware Order

Session middleware MUST be loaded before RodauthApp:

```ruby
# ✅ Correct
use Rack::Session::Cookie, secret: 'secret'
use RodauthApp
run MyApp

# ❌ Wrong - session not available to Rodauth
use RodauthApp
use Rack::Session::Cookie, secret: 'secret'
run MyApp
```

### 2. Rodauth Routes vs. App Routes

Rodauth handles its own routes (`/login`, `/logout`, etc.). Your app handles everything else:

```ruby
# RodauthApp handles:
# - /login (GET and POST)
# - /logout
# - /create-account
# - /verify-account
# - /reset-password
# - etc. (depends on enabled features)

# Your app handles:
# - /
# - /dashboard
# - /api/*
# - Everything else
```

### 3. Mounting at a Path Prefix

You can mount all Rodauth routes under a specific prefix (e.g., `/auth`):

**Option A: Using Rodauth's `prefix` configuration (Recommended)**

```ruby
class RodauthApp < Roda
  plugin :middleware

  plugin :rodauth do
    enable :login, :logout
    prefix '/auth'  # All routes under /auth
  end

  route do |r|
    r.on 'auth' do  # Match the prefix
      r.rodauth
    end

    # Set rodauth for ALL requests (auth and non-auth)
    env['rodauth'] = rodauth
  end
end

# config.ru
use RodauthApp
run MyApp  # Can be Sinatra, Hanami, plain Rack, anything

# Routes become:
# /auth/login
# /auth/logout
# /auth/create-account
# etc.
```

**How it works:**

- ALL requests flow through RodauthApp middleware first
- Requests to `/auth/*` are handled by Rodauth
- All other requests pass through to MyApp
- `env['rodauth']` is set for all requests (so MyApp can check auth state)
- Sessions are automatically shared (same `env['rack.session']`)

**Option B: Using Rack's `map` (Not Recommended)**

```ruby
# config.ru
map '/auth' do
  run RodauthApp
end

map '/' do
  run MyApp
end
```

**Problems with this approach:**

- Requests are routed by path to completely separate apps
- Requests to `/dashboard` never touch RodauthApp
- `env['rodauth']` is NOT available in MyApp routes
- No way to check authentication state in your main application
- While sessions technically work across `map` branches, you can't access Rodauth methods

**Recommendation:** Use Option A. It maintains a single middleware chain where all requests flow through Rodauth first, making authentication state accessible everywhere in your application.

### 4. Customizing Individual Route Paths

You can also customize individual route paths:

```ruby
plugin :rodauth do
  enable :login, :logout

  # Change individual route paths
  login_route 'signin'        # /signin instead of /login
  logout_route 'signout'      # /signout instead of /logout
  create_account_route 'register'  # /register instead of /create-account
end
```

### 5. Multiple Rodauth Configurations

You can have multiple Rodauth configurations (e.g., user auth vs. admin auth):

```ruby
class RodauthApp < Roda
  plugin :middleware

  plugin :rodauth, name: :user do
    enable :login, :logout
    prefix '/user'
    # User configuration
  end

  plugin :rodauth, name: :admin do
    enable :login, :logout
    prefix '/admin'
    # Admin configuration
  end

  route do |r|
    r.on 'user' do
      r.rodauth(:user)
    end

    r.on 'admin' do
      r.rodauth(:admin)
    end

    env['rodauth.user'] = rodauth(:user)
    env['rodauth.admin'] = rodauth(:admin)
  end
end

# In your app:
user_rodauth = env['rodauth.user']
admin_rodauth = env['rodauth.admin']
```

## Rails Integration

For Rails, use the mature [rodauth-rails](https://github.com/janko/rodauth-rails) gem instead of this manual integration. It provides:

- Generator for installation
- ActiveRecord integration
- ActionMailer integration
- Rails routing integration
- Controller helpers
- View helpers

```bash
# In a Rails app
bundle add rodauth-rails
rails generate rodauth:install
```

## What This Library Provides

This `rodauth-tools` library provides:

1. **External Rodauth Features** - Like `table_guard` for validating database setup:

```ruby
plugin :rodauth do
  enable :login, :table_guard

  table_guard_mode :error  # Raise error if tables missing
end
```

1. **Migration Generator** - Generate Sequel migrations for Rodauth tables:

```ruby
require 'rodauth/tools'

generator = Rodauth::Tools::Migration.new(
  features: [:base, :verify_account],
  prefix: 'account'
)

puts generator.generate
```

## Resources

- [Rodauth Documentation](https://rodauth.jeremyevans.net/documentation.html) - Official Rodauth docs
- [Roda Documentation](http://roda.jeremyevans.net/documentation.html) - Roda web framework
- [Sequel Documentation](https://sequel.jeremyevans.net/) - Database toolkit
- [rodauth-rails](https://github.com/janko/rodauth-rails) - Rails integration
