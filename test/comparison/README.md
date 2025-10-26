# Rails Adapter Comparison Tests

This directory contains automated comparison tests to verify that the `rodauth-rack` Rails adapter produces functionally equivalent output to the original `rodauth-rails` gem.

## Running Locally

### Prerequisites

- Ruby 3.2+ installed
- Rails gem installed (`gem install rails`)
- rodauth-rails gem installed (`gem install rodauth-rails`)

### Run the comparison test

```bash
# From the project root
ruby test/comparison/compare_rails_adapters.rb

# With verbose output
VERBOSE=1 ruby test/comparison/compare_rails_adapters.rb

# Keep temporary files for inspection
KEEP_TEMP=1 ruby test/comparison/compare_rails_adapters.rb
```

## What It Tests

The comparison test creates two identical Rails applications and compares outputs:

1. **App A**: Uses `rodauth-rails` gem (~> 1.15)
2. **App B**: Uses `rodauth-rack` Rails adapter (local path)

### Generators Tested

- `rails g rodauth:install` - Initial setup
- `rails g rodauth:migration` - Database migrations (base, verify_account, reset_password, remember, otp)
- `rails g rodauth:views` - View templates
- `rails g rodauth:mailer` - Mailer templates

### Comparison Points

1. **File structure** - Same files generated in same locations
2. **File contents** - Identical content (after normalizing namespace differences)
3. **Generator output** - Same console output from generators

### Expected Differences

The only acceptable differences are namespace-related:

- `Rodauth::Rails` → `Rodauth::Rack::Rails`
- `require "rodauth/rails"` → `require "rodauth/rack/rails"`

## CI Integration

### GitHub Actions Workflow

To add this as a CI check, create `.github/workflows/rails-adapter-comparison.yml`:

```yaml
name: Rails Adapter Comparison

on: [push, pull_request]

jobs:
  compare:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        ruby-version: ["3.2", "3.3"]
        rails-version: ["7.0", "7.1", "7.2"]

    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: ${{ matrix.ruby-version }}
          bundler-cache: true

      - name: Install dependencies
        run: |
          gem install rails -v "~> ${{ matrix.rails-version }}.0"
          gem install rodauth-rails

      - name: Run comparison test
        run: ruby test/comparison/compare_rails_adapters.rb
        env:
          VERBOSE: "1"
```

**Security Note**: This workflow only uses matrix variables (defined in the workflow) and hardcoded values. No user-controlled input is used.

## Troubleshooting

### Test Fails

If the comparison test fails:

1. **Keep temp files**: Run with `KEEP_TEMP=1` to inspect generated apps
2. **Check differences**: Look at the failure output for specific mismatches
3. **Verbose mode**: Use `VERBOSE=1` to see detailed output

### Common Issues

- **Missing Rails**: Install with `gem install rails`
- **Missing rodauth-rails**: Install with `gem install rodauth-rails`
- **Bundle install fails**: Check your Ruby version compatibility

## Development Workflow

When modifying the Rails adapter:

1. Make changes to `lib/rodauth/rack/rails/` or `lib/rodauth/rack/generators/rails/`
2. Run comparison test: `ruby test/comparison/compare_rails_adapters.rb`
3. Fix any discrepancies
4. Commit changes

This ensures the adapter remains functionally equivalent to the original rodauth-rails gem.
