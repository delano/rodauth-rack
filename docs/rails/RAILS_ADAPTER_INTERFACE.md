# Rails Adapter Interface Contract

This document specifies the exact interface that `Rodauth::Rack::Rails::Adapter` must implement to satisfy the `Rodauth::Rack::Adapter::Base` contract.

## Interface Overview

**Total Methods**: 20
- **Must Implement**: 14 methods
- **Inherited (OK to override)**: 6 methods

## Methods to Implement

### 1. View Rendering (2 methods)

#### `render(template, locals = {})`

**Purpose**: Render a view template with local variables

**Parameters**:
- `template` (String): Template name (e.g., "login", "create_account")
- `locals` (Hash): Local variables for the template

**Returns**: String - Rendered HTML

**Rails Implementation Strategy**:
```ruby
def render(template, locals = {})
  # Try user-defined Rails template
  controller_instance.render_to_string(
    partial: "rodauth/#{template.tr('-', '_')}",
    layout: false,
    locals: locals
  )
rescue ActionView::MissingTemplate
  # Fallback to Rodauth built-in template
  render_rodauth_template(template, locals)
end
```

**Template Resolution Order**:
1. `app/views/rodauth/_#{template}.html.erb` (partial)
2. `app/views/rodauth/#{template}.html.erb` (view)
3. Rodauth built-in template

#### `view_path`

**Purpose**: Get the base path for Rodauth view templates

**Parameters**: None

**Returns**: String - Path to view templates directory

**Rails Implementation**:
```ruby
def view_path
  Rails.root.join("app/views/rodauth").to_s
end
```

---

### 2. CSRF Protection (3 methods)

#### `csrf_token`

**Purpose**: Get the CSRF token for the current session

**Parameters**: None

**Returns**: String - CSRF token value

**Rails Implementation**:
```ruby
def csrf_token
  controller_instance.send(:form_authenticity_token)
end
```

**Notes**: Delegates to Rails' built-in CSRF token generation

#### `csrf_field`

**Purpose**: Get the CSRF field name (e.g., "authenticity_token")

**Parameters**: None

**Returns**: String - CSRF field name

**Rails Implementation**:
```ruby
def csrf_field
  ActionController::Base.request_forgery_protection_token.to_s
end
```

**Default Value**: "authenticity_token"

#### `valid_csrf_token?(token)`

**Purpose**: Check if the CSRF token is valid

**Parameters**:
- `token` (String): Token to validate

**Returns**: Boolean - True if valid, false otherwise

**Rails Implementation**:
```ruby
def valid_csrf_token?(token)
  controller_instance.send(:valid_authenticity_token?, session, token)
end
```

**Notes**: Uses Rails' RequestForgeryProtection mechanism

---

### 3. Flash Messages (1 method)

#### `flash`

**Purpose**: Get the flash hash for the current request

**Parameters**: None

**Returns**: Hash - Flash messages

**Rails Implementation**:
```ruby
def flash
  rails_request.flash
end
```

**Notes**: Returns ActionDispatch::Flash::FlashHash

---

### 4. URL Generation (1 method)

#### `url_for(path, **options)`

**Purpose**: Generate a full URL for a given path

**Parameters**:
- `path` (String): The path (e.g., "/login")
- `options` (Hash): URL options (host, protocol, port, etc.)

**Returns**: String - Full URL

**Rails Implementation**:
```ruby
def url_for(path, **options)
  Rails.application.routes.url_helpers.url_for(
    path: path,
    **default_url_options.merge(options)
  )
end

private

def default_url_options
  ActionMailer::Base.default_url_options.merge(
    host: Rails.configuration.action_mailer.default_url_options[:host],
    protocol: Rails.configuration.action_mailer.default_url_options[:protocol] || "https"
  )
end
```

**Used For**: Generating email links, redirects with full URLs

---

### 5. Email Delivery (1 method)

#### `deliver_email(mailer_method, *args)`

**Purpose**: Deliver an email using the framework's mailer

**Parameters**:
- `mailer_method` (Symbol): Mailer method name (e.g., :verify_account)
- `args` (Array): Arguments to pass to the mailer method

**Returns**: void

**Rails Implementation**:
```ruby
def deliver_email(mailer_method, *args)
  RodauthMailer.public_send(mailer_method, *args).deliver_now
end
```

**Mailer Class**:
```ruby
class RodauthMailer < ActionMailer::Base
  def verify_account(email, verify_link)
    mail(
      to: email,
      subject: "Verify Your Account",
      body: "Click here: #{verify_link}"
    )
  end

  # Generic method for all emails
  def create_email(to:, from:, subject:, body:)
    mail(to: to, from: from, subject: subject, body: body)
  end
end
```

---

### 6. Model Integration (1 method)

#### `account_model`

**Purpose**: Get the account model class (ActiveRecord or Sequel)

**Parameters**: None

**Returns**: Class - Account model class

**Rails Implementation**:
```ruby
def account_model
  @account_model ||= infer_account_model
end

private

def infer_account_model
  table_name = rodauth_config[:accounts_table] || "accounts"
  table_name = table_name.column if table_name.is_a?(Sequel::SQL::QualifiedIdentifier)

  table_name.to_s.classify.constantize
rescue NameError
  raise Error, "Cannot infer account model for table '#{table_name}'. " \
               "Please set account_model in your Rodauth configuration."
end
```

**Examples**:
- Table "accounts" → `Account` class
- Table "users" → `User` class
- Table "admin_accounts" → `AdminAccount` class

**Supports**:
- ActiveRecord models
- Sequel models

---

### 7. Configuration (2 methods)

#### `rodauth_config`

**Purpose**: Get the Rodauth configuration hash

**Parameters**: None

**Returns**: Hash - Configuration settings

**Rails Implementation**:
```ruby
def rodauth_config
  @rodauth_config ||= load_rodauth_config
end

private

def load_rodauth_config
  # Load from Rails configuration
  config = Rails.application.config.rodauth.to_h

  # Merge with defaults
  config.merge(
    accounts_table: config[:accounts_table] || :accounts,
    account_password_hash_column: config[:account_password_hash_column] || :password_digest,
    secret_key_base: Rails.application.secret_key_base
  )
end
```

**Configuration Sources**:
1. `config/initializers/rodauth.rb`
2. `app/misc/rodauth_app.rb`
3. Defaults

#### `db`

**Purpose**: Get the database connection (Sequel::Database)

**Parameters**: None

**Returns**: Sequel::Database - Database connection

**Rails Implementation**:
```ruby
def db
  @db ||= configure_sequel_connection
end

private

def configure_sequel_connection
  # Use sequel-activerecord_connection for seamless integration
  require "sequel/extensions/activerecord_connection"

  # Return existing Sequel database or create one
  Sequel::DATABASES.first || Sequel.postgres(
    extensions: :activerecord_connection,
    keep_reference: false
  )
end
```

**Notes**: Uses `sequel-activerecord_connection` to share ActiveRecord's connection pool

---

## Methods Inherited from Base (Optional to Override)

### 8. Session Management (2 methods)

#### `session`

**Purpose**: Get the session object

**Returns**: Hash - Session hash

**Base Implementation**:
```ruby
def session
  request.session
end
```

**Override If**: Need custom session handling

#### `clear_session`

**Purpose**: Clear the session

**Returns**: void

**Base Implementation**:
```ruby
def clear_session
  request.session.clear
end
```

**Rails Override** (recommended):
```ruby
def clear_session
  # Use Rails' reset_session for session fixation protection
  controller_instance.reset_session
end
```

---

### 9. Flash Messages (1 method)

#### `flash_now(key, message)`

**Purpose**: Set a flash message for the current request

**Parameters**:
- `key` (Symbol): Message type (:notice, :alert, :error)
- `message` (String): The message text

**Returns**: void

**Base Implementation**:
```ruby
def flash_now(key, message)
  flash[key] = message
end
```

**Override If**: Need custom flash behavior

---

### 10. Request/Response (3 methods)

#### `params`

**Purpose**: Get request parameters

**Returns**: Hash - Request parameters

**Base Implementation**:
```ruby
def params
  request.params
end
```

#### `env`

**Purpose**: Get request environment

**Returns**: Hash - Rack environment

**Base Implementation**:
```ruby
def env
  request.env
end
```

#### `request_path`

**Purpose**: Get the current request path

**Returns**: String - Request path

**Base Implementation**:
```ruby
def request_path
  request.path
end
```

#### `redirect(path, status: 302)`

**Purpose**: Redirect to a path

**Parameters**:
- `path` (String): Path to redirect to
- `status` (Integer): HTTP status code (default: 302)

**Returns**: void

**Base Implementation**:
```ruby
def redirect(path, status: 302)
  response.redirect(path, status)
end
```

#### `status=(status)`

**Purpose**: Set response status

**Parameters**:
- `status` (Integer): HTTP status code

**Returns**: void

**Base Implementation**:
```ruby
def status=(status)
  response.status = status
end
```

---

## Helper Methods (Private)

These are not part of the interface but are needed for implementation:

### `controller_instance`

**Purpose**: Get or create a Rails controller instance

**Returns**: ActionController::Base or ActionController::API

```ruby
attr_reader :controller_instance

def initialize(request, response)
  super
  @controller_instance = create_controller_instance
end

private

def create_controller_instance
  controller_class = if json_only?
    ActionController::API
  else
    ActionController::Base
  end

  controller = controller_class.new
  controller.set_request!(rails_request)
  controller.set_response!(controller_class.make_response!(rails_request))
  controller
end
```

### `rails_request`

**Purpose**: Get ActionDispatch::Request wrapper

**Returns**: ActionDispatch::Request

```ruby
def rails_request
  @rails_request ||= ActionDispatch::Request.new(request.env)
end
```

### `render_rodauth_template(template, locals)`

**Purpose**: Render Rodauth's built-in ERB template

**Parameters**:
- `template` (String): Template name
- `locals` (Hash): Local variables

**Returns**: String - Rendered HTML

```ruby
def render_rodauth_template(template, locals)
  template_path = File.join(
    Gem.loaded_specs["rodauth"].full_gem_path,
    "templates",
    "#{template}.str"
  )

  erb_content = File.read(template_path)
  ERB.new(erb_content).result_with_hash(locals)
end
```

---

## Testing the Interface

All 14 required methods should be tested:

```ruby
RSpec.describe Rodauth::Rack::Rails::Adapter do
  let(:adapter) { described_class.new(request, response) }

  describe "#render" do
    it "renders Rails template"
    it "falls back to Rodauth template"
  end

  describe "#view_path" do
    it "returns Rails view path"
  end

  describe "#csrf_token" do
    it "returns Rails CSRF token"
  end

  describe "#csrf_field" do
    it "returns authenticity_token"
  end

  describe "#valid_csrf_token?" do
    it "validates token via Rails"
  end

  describe "#flash" do
    it "returns Rails flash"
  end

  describe "#url_for" do
    it "generates full URL"
  end

  describe "#deliver_email" do
    it "sends email via ActionMailer"
  end

  describe "#account_model" do
    it "infers model from table name"
  end

  describe "#rodauth_config" do
    it "loads Rails configuration"
  end

  describe "#db" do
    it "returns Sequel connection"
  end

  describe "#clear_session" do
    it "resets Rails session"
  end
end
```

---

## Interface Compliance Checklist

- [ ] `render(template, locals)` implemented
- [ ] `view_path` implemented
- [ ] `csrf_token` implemented
- [ ] `csrf_field` implemented
- [ ] `valid_csrf_token?(token)` implemented
- [ ] `flash` implemented
- [ ] `url_for(path, **options)` implemented
- [ ] `deliver_email(mailer_method, *args)` implemented
- [ ] `account_model` implemented
- [ ] `rodauth_config` implemented
- [ ] `db` implemented
- [ ] `clear_session` overridden for Rails
- [ ] All methods tested
- [ ] Integration tests passing

---

## Summary

**Required Implementation**: 14 methods across 7 categories
**Recommended Overrides**: 1 method (clear_session)
**Helper Methods**: 3-4 private methods
**Total Lines of Code**: ~200-250 LOC

**Key Dependencies**:
- ActionController (CSRF, rendering)
- ActionView (templates)
- ActionMailer (emails)
- ActionDispatch (flash, request)
- Sequel (database)
- sequel-activerecord_connection (connection sharing)

**Next Step**: Implement `lib/rodauth/rack/rails/adapter.rb`
