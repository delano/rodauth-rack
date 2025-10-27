when defining a new Rodauth feature, you have these configuration options:

## Route Configuration

### `route(name, default, &block)`- Define a route for the feature

- Creates `#{name}_route` method (defaults to feature name with underscores→hyphens)
- Auto-generates `#{name}_path` and `#{name}_url` helper methods
- Creates `handle_#{name}` method with CSRF protection and around/before hooks

```ruby
route do |r|
  # logout feature
end
```

## Add Methods to Rodauth::Auth Class

Methods defined on the `Rodauth::Auth` class instance that can add to or override existing values/behavior during configuration and runtime authentication processing.

- **auth_methods** - Register methods as user-overridable (feature provides default implementation, users can customize via block)
- **auth_value_methods** - For simple configuration values (can be set to a string, number, boolean, etc., or a block)
- **auth_private_methods** - Internal methods users cannot directly override - creates underscore-prefixed private method always hidden from public API

### `auth_methods(*methods)` - Public authentication methods

`auth_methods` is the **bridge** between the feature's default implementation and the configuration DSL - it exposes the method to the configuration interface.

```ruby
# lib/rodauth/features/logout.rb
module Rodauth
  Feature.define(:logout, :Logout) do

    auth_methods :logout
    # ...
    def logout
      clear_session  # default implementation
    end

  end
end
```

1. **With `auth_methods :logout`**: Creates a configuration method allowing override:

```ruby
rodauth do
  logout do  # This method exists because of auth_methods
    # custom override
    clear_session
    audit_log_logout
  end
end
```

2. **Without `auth_methods :logout`**: The `def logout` method would still exist in the feature, but there would be no configuration method to override it. Users would be stuck with the default implementation.

### `auth_value_methods(*methods)`- Configuration value methods (overridable)

```ruby
auth_value_method :login_param, 'email' - configures parameter name
```

### `auth_private_methods(*methods)`- Private authentication methods

```ruby
auth_private_methods :account_from_email_auth_key
```

## Response & Redirect Configuration

### `redirect(name, &block)`- Define redirect behavior

- Creates `#{name}_redirect` method
- Defaults to `default_redirect` if no block given

```ruby
redirect(:email_auth_email_sent){default_post_email_redirect}
```

### `response(name)`- Define standard response pattern

- Creates `#{name}_response` method
- Handles notice flash and redirect automatically

```ruby
response :email_auth_email_sent
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

### `auth_value_method(meth, value)`- Simple configuration value

```ruby
auth_value_method :new_password_param, 'new-password'
```

### `translatable_method(meth, value)`- Translatable configuration value

```ruby
translatable_method :new_password_label, 'New Password'
```

### `auth_cached_method(meth, iv)`- Cached instance variable method

```ruby
auth_cached_method :otp_key
```

## Lifecycle Hooks

### `before(name)`- Before hook for route/action

```ruby
before
```

### `after(name)`- After hook for route/action

```ruby
after
```

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
