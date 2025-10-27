when defining a new Rodauth feature, you have these configuration options:

## About this Document

This document outlines the configuration options available when defining a new Rodauth feature. Each section describes a specific configuration method, its purpose, and provides code examples from existing features.

We distinguish between:

- **Feature developers** - Writing Rodauth features
- **Application developers** - Using Rodauth in their applications
- **End users** - People logging into the application

Route Configuration

### `route(name, default, &block)` - Define a route for the feature

Creates routing infrastructure for a feature:

- `#{name}_route` - Route path (defaults to feature name with underscores→hyphens)
- `#{name}_path` and `#{name}_url` - Helper methods for generating URLs
- `handle_#{name}` - Route handler with CSRF protection
- `before_#{name}_route` - Lifecycle hook (runs when entering the route)

```ruby
# From lib/rodauth/features/logout.rb
route do |r|
  before_logout_route  # Auto-generated hook

  r.get do
    logout_view
  end

  r.post do
    transaction do
      before_logout  # Created by before macro
      logout
      after_logout   # Created by after macro
    end
    logout_response
  end
end
```

## Add Methods to Rodauth::Auth Class

Methods defined on the `Rodauth::Auth` class instance that can add to or override existing values/behavior during configuration and runtime authentication processing.

- **auth_methods** - Register methods as overridable (feature provides default implementation, application developers can customize via block)
- **auth_value_methods** - For configuration values (can be set to a string, number, boolean, etc., or a block)
- **auth_private_methods** - Internal methods that cannot be directly overridden - creates underscore-prefixed private method always hidden from public API

### `auth_methods(*methods)` - Public authentication methods

`auth_methods` is the **bridge** between the feature's default implementation and the configuration DSL - it exposes the method so **application developers** can override it.

```ruby
# From lib/rodauth/features/logout.rb
module Rodauth
  Feature.define(:logout, :Logout) do

    auth_methods :logout

    # default implementation
    def logout
      clear_session
    end

  end
end
```

1. **With `auth_methods :logout`**: Creates a configuration method allowing **developers** to override:

```ruby
rodauth do
  logout do  # Override available to developers
    # custom override
    clear_session
    audit_log_logout
  end
end
```

**Without `auth_methods :logout`**: The `def logout` method would still exist in the feature, but there would be no configuration method to override it. Users would be stuck with the default implementation.

### `auth_value_methods(*methods)` - Configuration value methods

`auth_value_methods` allows users to override configuration values with either a static value or a dynamic block.

```ruby
# From lib/rodauth/features/change_password.rb

  auth_value_methods(
    :change_password_requires_password?,
    :invalid_previous_password_message
  )

  # Default implementations
  def change_password_requires_password?
    modifications_require_password?
  end

  def invalid_previous_password_message
    invalid_password_message
  end
```

**With `auth_value_methods`**: Users can override with a value or block:

```ruby
rodauth do
  # Override with static value
  invalid_previous_password_message "Wrong password!"

  # Override with dynamic block
  change_password_requires_password? do
    account[:password_age] > 90
  end
end
```

**Without `auth_value_methods`**: The default methods would exist but couldn't be configured - users would need to subclass to override them.

### `auth_private_methods(*methods)`- Private authentication methods

```ruby
auth_private_methods :account_from_email_auth_key
```

## Redirect & Response Configuration

`redirect` and `response` are higher-level, convenience macros for feature developers.

1. **Automatically create and register methods** - They're helpers that define method implementation AND register it as configurable in one step
2. **Follow conventions** - They create standardized method names (`#{name}_redirect`, `#{name}_response`)
3. **Provide structure** - `response` combines flash + redirect in one pattern

### Compared to auth methods?

auth_methods/auth_value_methods are lower-level and **registration-only** primitives. They require the methods to be defined separately as well.

```ruby
# High-level: redirect() does both define + register
redirect(:logout) { default_redirect }

# vs Low-level: define then register separately
def logout_redirect
  default_redirect
end
auth_value_methods :logout_redirect
```

### `redirect(name, &block)`- Define redirect behavior

Defines and registers a `#{name}_redirect` method. Defaults to `default_redirect` (which returns `'/'`) if no block given.

```ruby
# From lib/rodauth/features/email_auth.rb
redirect(:email_auth_email_sent) { default_post_email_redirect }
```

### `response(name)`- Define standard response pattern

Creates a `#{name}_response` method combining notice flash + redirect in one pattern.

```ruby
response :email_auth_email_sent
```

Application developers can override the redirect or notice flash separately:

```ruby
rodauth do
  email_auth_email_sent_notice_flash "Email sent!"
  email_auth_email_sent_redirect { '/dashboard' }
end
```

## View Configuration

### `view(page, title, name)`- Define a view endpoint

- Creates `#{name}_view` method
- Auto-generates translatable `#{name}_page_title`

```ruby
view 'change-password', 'Change Password'
```

## Email Configuration

### `email(type, subject, opts)`- Define email functionality

- Creates subject, body, create, and send methods
- `opts[:translatable]` enables translation support

```ruby
email :password_changed, 'Password Changed', :translatable=>true
```

## Session & Flash Configuration

### `session_key(meth, value)`- Define session key with conversion

```ruby
session_key :email_auth_session_key, :email_auth_key
```

### `flash_key(meth, value)`- Define flash key with normalization

```ruby
flash_key :flash_error_key, :error
```

## UI Elements

### `notice_flash(value, name)`- Success message (translatable)

```ruby
notice_flash "You have been logged out"
```

### `error_flash(value, name)`- Error message (translatable)

```ruby
error_flash 'There was an error changing your password'
```

### `button(value, name)`- Button text (translatable)

```ruby
button 'Logout'
```

### `additional_form_tags(name)`- Extra form tag content

```ruby
additional_form_tags
```

## Value Methods

### `auth_value_method(meth, value)` - Configuration value with default

Convenience macro that defines a method returning a default value and registers it via `auth_value_methods`.

```ruby
# From lib/rodauth/features/change_password.rb
auth_value_method :new_password_param, 'new-password'
# Equivalent to:
#   def new_password_param; 'new-password'; end
#   auth_value_methods :new_password_param
```

Application developers can override with a **value or block**:

```ruby
rodauth do
  new_password_param 'password'           # static value
  new_password_param { ... }              # computed at runtime
end
```

### `translatable_method(meth, value)` - Translatable configuration value

Like `auth_value_method` but wraps the value with `translate()` for i18n support. Used for enduser-facing text.

```ruby
# From lib/rodauth/features/change_password.rb
translatable_method :new_password_label, 'New Password'
```

### `auth_cached_method(meth, iv)` - Cached computation method

Creates a private method that computes a value once and caches it in an instance variable. Application developers override `_#{meth}` to customize computation.

```ruby
# From lib/rodauth/features/otp.rb
auth_cached_method :otp_key  # Caches result of _otp_key in @otp_key
```

Application developers override the computation:

```ruby
rodauth do
  otp_key { custom_otp_generation_logic }
end
```

## Lifecycle Hooks

### before(name)` / `after(name)` - Define lifecycle hook for feature action

For **feature developers**: Creates two methods:

- `before_#{name}` - Wrapper that calls `_before_#{name}`, then notifies other features via `hook_action`
- `_before_#{name}` - Internal implementation (empty by default)

e.g. `before_logout` → calls → `_before_logout` → then calls `hook_action(:before, :logout)

The feature developer must explicitly call `before_#{name}` in the route handler.

**Distinction**: `before_#{name}` wraps the core action, while `before_#{name}_route` (auto-created by `route` macro) runs when entering the HTTP route.

```ruby
# From lib/rodauth/features/logout.rb
Feature.define(:logout, :Logout) do
  before  # Creates before_logout and _before_logout

  route do |r|
    r.post do
      transaction do
        before_logout  # Calls _before_logout + hook_action
        logout
        after_logout
      end
    end
  end
end
```

**Application developers** configure via the public method name (which redefines the internal `_` version):

```ruby
rodauth do
  before_logout do  # Redefines _before_logout internally
    audit_log("User #{account_id} logging out")
  end
end
```

### Before vs After

The only differences are:

1. **Name** - `before_#{name}` vs `after_#{name}`
2. **Timing** - Where the feature developer chooses to call them in the flow
3. **Hook type** - Passes `:before` or `:after` to `hook_action(hook_type, name)`

So semantically they're distinct, but mechanically identical. The "before" vs "after" behavior is entirely determined by where the feature developer places the method calls in the route handler.

### `hook_action(hook_type, action)`

A centralized notification point that fires whenever ANY hook runs (before/after for any action). Does nothing by default, but features like `audit_logging` use it to add behavior that applies to all hooks (e.g., logging every authentication action).

## Dependencies

### `depends(*features)`- Declare feature dependencies

```ruby
depends :otp, :email_base
```

### `internal_request_method(name)`- Mark method for internal requests

```ruby
internal_request_method
```

### `loaded_templates(array)`- Declare required templates

```ruby
loaded_templates %w'logout'
```
