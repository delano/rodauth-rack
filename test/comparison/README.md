# Rails Adapter Comparison Tests

This directory contains automated comparison tests that verify the rodauth-rack Rails adapter generates the same output as the original rodauth-rails gem.

## Overview

The comparison test creates two identical Rails applications:

- **rodauth-rails-test**: Uses the published `rodauth-rails` gem (~> 1.15)
- **rodauth-rack-test**: Uses the local `rodauth-rack` gem with Rails adapter

It then runs all four generators on both apps and compares the output.

## Running Locally

```bash
# Basic run
ruby test/comparison/compare_rails_adapters.rb

# Verbose output
VERBOSE=1 ruby test/comparison/compare_rails_adapters.rb

# Keep temp directories for debugging
KEEP_TEMP=1 ruby test/comparison/compare_rails_adapters.rb
```

## What Gets Tested

### Generators

1. `rails g rodauth:install` - Creates initializer, models, controllers
2. `rails g rodauth:migration [features]` - Creates database migrations
3. `rails g rodauth:views` - Creates view templates
4. `rails g rodauth:mailer` - Creates mailer templates

### Comparisons

- Generator output messages
- Generated file structure
- File contents (with namespace normalization)

## CI Integration

The test runs automatically on:

- Push to `main` or `feature/*` branches
- Pull requests that modify:
  - `lib/generators/**`
  - `lib/rodauth/rack/rails/**`
  - `test/comparison/**`

### Matrix Testing

- Ruby versions: 3.2, 3.3, 3.4
- Rails versions: 7.1, 7.2, 8.0

## Expected Differences

Some minor differences are acceptable and don't indicate bugs:

1. **Output formatting**: `gemfile` vs `create` in generator messages
2. **Timestamps**: Migration filenames have different timestamps
3. **Comments**: rodauth-rack may include additional helpful comments
4. **Require statements**: rodauth-rack adds `require "rodauth/rack/rails"` to generated initializer

These differences are cosmetic and don't affect functionality.

## Debugging Failures

If the comparison test fails in CI:

1. **Check the artifacts**: Failed runs upload the temp directories containing both test apps
2. **Run locally**: Use `KEEP_TEMP=1` to inspect the generated apps
3. **Check diffs**: Look at the specific differences reported in the test output

### Common Issues

- **Missing feature modules**: Ensure all files in `lib/rodauth/rack/rails/feature/` are present
- **Template paths**: Generators should point to correct template directories
- **Namespace issues**: Check that `Rodauth::Rails` alias is properly set up

## Adding New Generators

When adding a new generator:

1. Add it to the `GENERATORS` array in `compare_rails_adapters.rb`
2. Ensure templates are in the correct location
3. Update this README with the new generator
4. Run the comparison test locally before pushing

## Maintenance

This comparison test ensures we maintain compatibility with rodauth-rails while building the rodauth-rack monorepo. As we add features to the Rails adapter, this test helps verify we don't break existing behavior.
