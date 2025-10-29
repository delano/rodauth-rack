# Contributing to rodauth-tools

Thank you for your interest in contributing to rodauth-tools!

## Development Setup

1. Fork and clone the repository:

   ```bash
   git clone https://github.com/YOUR_USERNAME/rodauth-tools.git
   cd rodauth-tools
   ```

2. Install dependencies:

   ```bash
   bundle install
   ```

3. Install pre-commit hooks:

   ```bash
   # Install pre-commit (if not already installed)
   pip install pre-commit
   # or
   brew install pre-commit

   # Install the git hook scripts
   pre-commit install
   pre-commit install --hook-type commit-msg
   ```

4. Run tests:

   ```bash
   bundle exec rspec
   ```

## Pre-commit Hooks

This project uses pre-commit to ensure code quality. The hooks will run automatically on `git commit`.

To manually run all hooks on all files:

```bash
pre-commit run --all-files
```

To skip hooks (not recommended):

```bash
git commit --no-verify
```

### Configured Hooks

- **File checks**: Trailing whitespace, end-of-file, large files, merge conflicts
- **RuboCop**: Ruby style and linting (auto-corrects when possible)
- **Bundler Audit**: Security vulnerability checks
- **Markdown linting**: Ensures consistent Markdown formatting
- **Commit message**: Enforces conventional commit format

## Code Style

We use RuboCop for Ruby code style. Configuration is in `.rubocop.yml`.

Key conventions:

- Ruby 3.2+ syntax
- Double quotes for strings
- 2-space indentation

## Commit Messages

Follow conventional commits format:

```text
type(scope): subject

body (optional)
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`

Examples:

- `feat: add CSRF protection to base adapter`
- `fix: correct session reset behavior in Rails adapter`
- `docs: update installation instructions`

## Running Tests

```bash
# Run all tests
bundle exec rspec

# Run with coverage
COVERAGE=true bundle exec rspec
```

## Pull Request Process

1. Create a feature branch from `main`
2. Make your changes with clear, conventional commits
3. Ensure all tests pass and pre-commit hooks succeed
4. Update documentation as needed
5. Submit a pull request with a clear description of changes

## Questions?

Feel free to open an issue for discussion before starting major work.
