when defining a new Rodauth feature, you have these configuration options:

## Route Configuration

**`route(name, default, &block)`** - Define a route for the feature

- Creates `#{name}_route` method (defaults to feature name with underscores→hyphens)
- Auto-generates `#{name}_path` and `#{name}_url` helper methods
- Creates `handle_#{name}` method with CSRF protection and around/before hooks

## Method Visibility Options

**`auth_methods(*methods)`** - Public authentication methods

**`auth_value_methods(*methods)`** - Configuration value methods (overridable)

**`auth_private_methods(*methods)`** - Private authentication methods

## Response & Redirect Configuration

**`redirect(name, &block)`** - Define redirect behavior

- Creates `#{name}_redirect` method
- Defaults to `default_redirect` if no block given

**`response(name)`** - Define standard response pattern

- Creates `#{name}_response` method
- Handles notice flash and redirect automatically

## View Configuration

**`view(page, title, name)`** - Define a view endpoint

- Creates `#{name}_view` method
- Auto-generates translatable `#{name}_page_title`

## Email Configuration

**`email(type, subject, opts)`** - Define email functionality

- Creates subject, body, create, and send methods
- `opts[:translatable]` enables translation support

## Session & Flash Configuration

**`session_key(meth, value)`** - Define session key with conversion

**`flash_key(meth, value)`** - Define flash key with normalization

## UI Elements

**`notice_flash(value, name)`** - Success message (translatable)

**`error_flash(value, name)`** - Error message (translatable)

**`button(value, name)`** - Button text (translatable)

**`additional_form_tags(name)`** - Extra form tag content

## Value Methods

**`auth_value_method(meth, value)`** - Simple configuration value

**`translatable_method(meth, value)`** - Translatable configuration value

**`auth_cached_method(meth, iv)`** - Cached instance variable method

## Lifecycle Hooks

**`before(name)`** - Before hook for route/action

**`after(name)`** - After hook for route/action

## Dependencies

**`depends(*features)`** - Declare feature dependencies

**`internal_request_method(name)`** - Mark method for internal requests

**`loaded_templates(array)`** - Declare required templates
