# Rodauth::Rack

Framework-agnostic [Rodauth](http://rodauth.jeremyevans.net) authentication integration for Rack 3 applications.

## Overview

Rodauth::Rack provides core Rodauth authentication functionality for any Rack framework (Rails, Hanami, Sinatra, Roda, etc.) through a flexible adapter interface. This gem extracts the framework-agnostic parts of [rodauth-rails](https://github.com/janko/rodauth-rails) to enable Rodauth integration across the Ruby web framework ecosystem.

## Features

- **Framework Agnostic**: Works with any Rack 3 framework
- **Adapter Interface**: Clean separation between Rodauth core and framework-specific concerns
- **Flexible Middleware**: Easy integration into existing applications
- **Well Tested**: Comprehensive test suite with >80% coverage
- **Production Ready**: Battle-tested patterns extracted from rodauth-rails

## Architecture

### Core Components

```
┌─────────────────────────────────────────────────────┐
│                  Your Application                    │
│              (Rails, Hanami, Sinatra, etc.)         │
└──────────────────┬──────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────┐
│           Framework-Specific Adapter                 │
│    (rodauth-rack-rails, rodauth-rack-hanami, etc.)  │
└──────────────────┬──────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────┐
│              Rodauth::Rack (Core)                    │
│  • Adapter::Base (interface)                        │
│  • Middleware (request routing)                      │
│  • Configuration                                     │
└──────────────────┬──────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────┐
│                   Rodauth                            │
│              (Authentication Logic)                  │
└─────────────────────────────────────────────────────┘
```

### Adapter Interface

The `Rodauth::Rack::Adapter::Base` class defines approximately 20 methods that framework adapters must implement:

- **View Rendering**: `render`, `view_path`
- **CSRF Protection**: `csrf_token`, `csrf_field`, `valid_csrf_token?`
- **Session Management**: `session`, `clear_session`
- **Flash Messages**: `flash`, `flash_now`
- **URL Generation**: `url_for`, `request_path`
- **Email Delivery**: `deliver_email`
- **Model Integration**: `account_model`, `find_account`
- **Configuration**: `rodauth_config`, `db`

## Installation

Add this line to your application's Gemfile:

```ruby
gem "rodauth-rack"
```

Then execute:

```bash
bundle install
```

**Note**: For most applications, you'll want to install a framework-specific adapter gem instead:

- Rails: `gem "rodauth-rack-rails"` (coming soon)
- Hanami: `gem "rodauth-rack-hanami"` (coming soon)
- Sinatra/Roda: Use the CLI tool `rodauth-cli` (coming soon)

## Usage

### For Framework Developers

If you're building a framework adapter, inherit from `Rodauth::Rack::Adapter::Base` and implement the required methods:

```ruby
module MyFramework
  class RodauthAdapter < Rodauth::Rack::Adapter::Base
    def render(template, locals = {})
      # Render template using your framework's view layer
    end

    def csrf_token
      # Return your framework's CSRF token
    end

    # ... implement other required methods
  end
end
```

### For Application Developers

See the documentation for your framework-specific adapter:

- [rodauth-rack-rails](https://github.com/delano/rodauth-rack-rails) - Rails integration
- [rodauth-rack-hanami](https://github.com/delano/rodauth-rack-hanami) - Hanami integration
- [rodauth-cli](https://github.com/delano/rodauth-cli) - CLI for Roda and Sinatra

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Related Projects

- [rodauth](https://github.com/jeremyevans/rodauth) - The authentication framework
- [rodauth-rails](https://github.com/janko/rodauth-rails) - Rails integration (inspiration for this gem)
- [roda](https://github.com/jeremyevans/roda) - Routing tree web toolkit

## Roadmap

- [ ] Issue #1: Core gem (✓ Initial setup complete)
- [ ] Issue #2: Migration generators
- [ ] Issue #3: Rails adapter (rodauth-rack-rails)
- [ ] Issue #4: Hanami adapter (rodauth-rack-hanami)
- [ ] Issue #5: CLI tool (rodauth-cli)
- [ ] Issue #6: Demo applications

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/delano/rodauth-rack. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/delano/rodauth-rack/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Acknowledgments

This gem extracts and builds upon patterns from [rodauth-rails](https://github.com/janko/rodauth-rails) by Janko Marohnić, released under the MIT License. We're grateful for the excellent foundation provided by that project.

## Code of Conduct

Everyone interacting in the Rodauth::Rack project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/delano/rodauth-rack/blob/main/CODE_OF_CONDUCT.md).
