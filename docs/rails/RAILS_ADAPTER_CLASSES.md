# Rodauth-Rack-Rails Class Diagram

## Inheritance Hierarchy

```
┌─────────────────────────────────────────────────────────────┐
│              Rodauth::Rack::Adapter::Base                   │
│  (Abstract interface - 20 methods)                          │
│                                                              │
│  View:    render, view_path                                 │
│  CSRF:    csrf_token, csrf_field, valid_csrf_token?         │
│  Session: session, clear_session                            │
│  Flash:   flash, flash_now                                  │
│  URL:     url_for, request_path                             │
│  Email:   deliver_email                                     │
│  Model:   account_model, find_account                       │
│  Config:  rodauth_config, db                                │
│  Request: params, env, redirect, status=                    │
└──────────────────┬──────────────────────────────────────────┘
                   │ inherits
                   ▼
┌─────────────────────────────────────────────────────────────┐
│         Rodauth::Rack::Rails::Adapter                       │
│  (Concrete Rails implementation)                            │
│                                                              │
│  + controller_instance: ActionController::Base              │
│  + rails_request: ActionDispatch::Request                   │
│                                                              │
│  # render(template, locals)                                 │
│  # view_path                                                │
│  # csrf_token                                               │
│  # csrf_field                                               │
│  # valid_csrf_token?(token)                                 │
│  # flash                                                    │
│  # url_for(path, **options)                                 │
│  # deliver_email(mailer_method, *args)                      │
│  # account_model                                            │
│  # rodauth_config                                           │
│  # db                                                       │
│  # clear_session (override)                                 │
└─────────────────────────────────────────────────────────────┘
```

## Roda Middleware Hierarchy

```
┌─────────────────────────────────────────────────────────────┐
│                      Roda                                   │
│  (Routing tree web toolkit)                                 │
└──────────────────┬──────────────────────────────────────────┘
                   │ inherits
                   ▼
┌─────────────────────────────────────────────────────────────┐
│            Rodauth::Rack::Rails::App                        │
│  (Roda app with Rodauth plugin)                             │
│                                                              │
│  plugin :middleware                                         │
│  plugin :rodauth                                            │
│  plugin :render                                             │
│  plugin :hooks                                              │
│                                                              │
│  .configure(name:, json:, **options, &block)                │
│  before { expose rodauth to env }                           │
│  after { commit flash }                                     │
│                                                              │
│  + flash                                                    │
│  + rails_routes                                             │
│  + rails_request                                            │
└─────────────────────────────────────────────────────────────┘
```

## Rodauth Configuration Hierarchy

```
┌─────────────────────────────────────────────────────────────┐
│                  Rodauth::Auth                              │
│  (Base Rodauth authentication class)                        │
└──────────────────┬──────────────────────────────────────────┘
                   │ inherits
                   ▼
┌─────────────────────────────────────────────────────────────┐
│            Rodauth::Rack::Rails::Auth                       │
│  (Rails-specific Rodauth configuration)                     │
│                                                              │
│  configure do                                               │
│    enable :rails                                            │
│    use_database_authentication_functions? false             │
│    set_deadline_values? true                                │
│    hmac_secret { Rails.application.secret_key_base }        │
│  end                                                        │
└─────────────────────────────────────────────────────────────┘
                   │ instantiated by
                   ▼
┌─────────────────────────────────────────────────────────────┐
│                   RodauthApp                                │
│  (User's app-specific configuration)                        │
│                                                              │
│  class RodauthApp < Rodauth::Rack::Rails::App               │
│    configure do                                             │
│      db Sequel.postgres(...)                                │
│      enable :login, :logout, :verify_account                │
│      accounts_table :accounts                               │
│      # ... user configuration ...                           │
│    end                                                      │
│  end                                                        │
└─────────────────────────────────────────────────────────────┘
```

## Feature Module Composition

```
┌─────────────────────────────────────────────────────────────┐
│        Rodauth::Rack::Rails::Feature                        │
│  (Composite module via ActiveSupport::Concern)              │
│                                                              │
│  includes:                                                  │
│    ├─ Base                                                  │
│    ├─ Render                                                │
│    ├─ CSRF                                                  │
│    ├─ Email                                                 │
│    └─ Callbacks                                             │
└─────────────────────────────────────────────────────────────┘
           │             │            │          │          │
           ▼             ▼            ▼          ▼          ▼
    ┌──────────┐  ┌──────────┐  ┌──────┐  ┌───────┐  ┌─────────┐
    │   Base   │  │  Render  │  │ CSRF │  │ Email │  │Callback │
    │          │  │          │  │      │  │       │  │         │
    │ rails_   │  │ view()   │  │csrf_ │  │create_│  │ before_ │
    │ account  │  │ render() │  │tag   │  │email  │  │ rodauth │
    │          │  │          │  │      │  │       │  │         │
    │ rails_   │  │rails_    │  │check_│  │send_  │  │ after_  │
    │ account_ │  │render    │  │csrf  │  │email  │  │ rodauth │
    │ model    │  │          │  │      │  │       │  │         │
    │          │  │ button() │  │rails_│  │       │  │         │
    │clear_    │  │          │  │csrf_ │  │       │  │         │
    │session   │  │Turbo     │  │*     │  │       │  │         │
    │          │  │disable   │  │      │  │       │  │         │
    └──────────┘  └──────────┘  └──────┘  └───────┘  └─────────┘
```

## Railtie Integration Flow

```
┌─────────────────────────────────────────────────────────────┐
│                  Rails::Railtie                             │
└──────────────────┬──────────────────────────────────────────┘
                   │ inherits
                   ▼
┌─────────────────────────────────────────────────────────────┐
│          Rodauth::Rack::Rails::Railtie                      │
│                                                              │
│  config.rodauth = OrderedOptions.new                        │
│                                                              │
│  initializer "rodauth.middleware"                           │
│    └─> app.middleware.use Middleware                        │
│                                                              │
│  initializer "rodauth.controller_methods"                   │
│    └─> include ControllerMethods                            │
│                                                              │
│  initializer "rodauth.test_helpers"                         │
│    └─> include Test::Controller                             │
│                                                              │
│  initializer "rodauth.sequel_activerecord"                  │
│    └─> app.middleware.use Sequel::AR::Middleware            │
│                                                              │
│  rake_tasks                                                 │
│    └─> load "rodauth/rack/rails/tasks.rake"                 │
└─────────────────────────────────────────────────────────────┘
```

## Controller Integration

```
┌─────────────────────────────────────────────────────────────┐
│              ActionController::Base                         │
└──────────────────┬──────────────────────────────────────────┘
                   │ includes (via Railtie)
                   ▼
┌─────────────────────────────────────────────────────────────┐
│     Rodauth::Rack::Rails::ControllerMethods                 │
│                                                              │
│  + rodauth(name = nil)                                      │
│    Returns Rodauth instance from env                        │
│                                                              │
│  + rodauth_response(&block)                                 │
│    Catches :halt and sets response                          │
│                                                              │
│  + append_info_to_payload(payload)                          │
│    Logs Rodauth status for instrumentation                  │
└─────────────────────────────────────────────────────────────┘
                   │ mixed into
                   ▼
┌─────────────────────────────────────────────────────────────┐
│              ApplicationController                          │
│                                                              │
│  before_action :require_login                               │
│                                                              │
│  def require_login                                          │
│    rodauth.require_account                                  │
│  end                                                        │
│                                                              │
│  def current_account                                        │
│    @current_account ||= rodauth.rails_account               │
│  end                                                        │
│  helper_method :current_account                             │
└─────────────────────────────────────────────────────────────┘
```

## Middleware Stack

```
Rails Middleware Stack
│
├─ Rack::Sendfile
├─ ActionDispatch::Static
├─ Rack::Lock
├─ Rack::Runtime
├─ Rack::MethodOverride
├─ ActionDispatch::RequestId
├─ ActionDispatch::RemoteIp
├─ Rails::Rack::Logger
├─ ActionDispatch::ShowExceptions
├─ ActionDispatch::DebugExceptions
├─ ActionDispatch::Callbacks
├─ ActionDispatch::Cookies
├─ ActionDispatch::Session::CookieStore
│
├─ Sequel::ActiveRecordConnection::Middleware ←── Added by Railtie
│   (Shares AR connection pool with Sequel)
│
├─ Rodauth::Rack::Rails::Middleware ←────────────── Added by Railtie
│   │
│   ├─ Skip if asset request
│   ├─ Load RodauthApp.constantize
│   ├─ Create Roda app instance
│   └─ catch(:halt) { app.call(env) }
│
├─ ActionDispatch::Flash
├─ Rack::Head
├─ Rack::ConditionalGet
├─ Rack::ETag
└─ Your Rails App
```

## Generator Hierarchy

```
┌─────────────────────────────────────────────────────────────┐
│            Rails::Generators::Base                          │
└──────────────────┬──────────────────────────────────────────┘
                   │ inherits
        ┌──────────┴──────────┬─────────────┬────────────┐
        ▼                     ▼             ▼            ▼
┌───────────────┐  ┌───────────────┐  ┌─────────┐  ┌─────────┐
│Install        │  │Migration      │  │Mailer   │  │Views    │
│Generator      │  │Generator      │  │Generator│  │Generator│
│               │  │               │  │         │  │         │
│ orchestrates: │  │ wraps:        │  │copies:  │  │copies:  │
│ • migration   │  │ Rodauth::Rack │  │ email   │  │ view    │
│ • app class   │  │ ::Generators  │  │ templ.  │  │ templ.  │
│ • controller  │  │ ::Migration   │  │         │  │         │
│ • model       │  │               │  │         │  │         │
│ • initializer │  │ generates:    │  │         │  │         │
│ • mailer      │  │ AR migration  │  │         │  │         │
│ • views       │  │ for features  │  │         │  │         │
└───────────────┘  └───────────────┘  └─────────┘  └─────────┘
```

## Mailer Integration

```
┌─────────────────────────────────────────────────────────────┐
│              ActionMailer::Base                             │
└──────────────────┬──────────────────────────────────────────┘
                   │ inherits
                   ▼
┌─────────────────────────────────────────────────────────────┐
│         Rodauth::Rack::Rails::Mailer                        │
│                                                              │
│  default from: -> { config.email_from }                     │
│                                                              │
│  def create_email(to:, from:, subject:, body:)              │
│    mail(to: to, from: from, subject: subject, body: body)   │
│  end                                                        │
│                                                              │
│  def verify_account(recipient, email_link)                  │
│    @email_link = email_link                                 │
│    mail(to: recipient, subject: "Verify Account")           │
│  end                                                        │
│                                                              │
│  def reset_password(recipient, email_link)                  │
│    @email_link = email_link                                 │
│    mail(to: recipient, subject: "Reset Password")           │
│  end                                                        │
└─────────────────────────────────────────────────────────────┘
                   │ used by
                   ▼
┌─────────────────────────────────────────────────────────────┐
│     Rodauth::Rack::Rails::Feature::Email                    │
│                                                              │
│  def create_email_to(to, subject, body)                     │
│    Mailer.create_email(...)                                 │
│  end                                                        │
│                                                              │
│  def send_email(email)                                      │
│    email.deliver_now                                        │
│  end                                                        │
└─────────────────────────────────────────────────────────────┘
```

## Object Relationships

```
Request Flow:
  HTTP Request
    → Rails Middleware Stack
    → Rodauth::Rack::Rails::Middleware
    → RodauthApp (Roda)
    → Rodauth::Auth (with :rails feature)
    → Rodauth::Rack::Rails::Adapter
    → Rails Components (ActionView, ActionMailer, etc.)
    → HTTP Response

Configuration Flow:
  config/initializers/rodauth.rb
    → Rails.application.config.rodauth
    → Railtie reads config
    → Middleware loads RodauthApp.constantize
    → RodauthApp.configure block
    → Rodauth::Rack::Rails::Auth defaults

Feature Loading:
  enable :rails
    → Rodauth::Rack::Rails::Feature
    → includes Base + Render + CSRF + Email + Callbacks
    → methods available in Rodauth config
```

## Key Object Instances

```
┌─────────────────────────────────────────────────────────────┐
│  Per Request:                                               │
│                                                              │
│  request: Rack::Request                                     │
│    └─> rails_request: ActionDispatch::Request               │
│                                                              │
│  response: Rack::Response                                   │
│                                                              │
│  adapter: Rodauth::Rack::Rails::Adapter                     │
│    ├─> controller_instance: ActionController::Base          │
│    ├─> rails_request: ActionDispatch::Request               │
│    └─> account_model: ActiveRecord::Base or Sequel::Model   │
│                                                              │
│  rodauth: Rodauth::Auth instance                            │
│    └─> stored in env["rodauth"] for controller access       │
│                                                              │
│  db: Sequel::Database                                       │
│    └─> uses activerecord_connection extension               │
└─────────────────────────────────────────────────────────────┘
```
