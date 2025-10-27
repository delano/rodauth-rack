# Session Management and Password Security Features - Documentation Index

## Overview

This directory contains comprehensive integration plans for six Rodauth features related to session management and password security. All features are ready for integration with existing rodauth-rack infrastructure.

## Documentation Files

### 1. [FEATURE_INTEGRATION_PLAN.md](FEATURE_INTEGRATION_PLAN.md)

**Purpose**: Complete integration guide for all six features

**Contents**:

- Detailed feature analysis (how each feature works)
- Database schema requirements with migrations
- Configuration options and examples
- Rails and Hanami adapter requirements
- JSON API integration patterns
- Security considerations and best practices
- UI implementation guidance
- Complete implementation blueprints

**Use this when**: You need comprehensive understanding of a feature before implementation

**Target audience**: Senior developers, architects

**Length**: ~500 lines, comprehensive

---

### 2. [SESSION_PASSWORD_FEATURES_SUMMARY.md](SESSION_PASSWORD_FEATURES_SUMMARY.md)

**Purpose**: Executive summary and quick reference

**Contents**:

- Feature comparison matrix
- Integration status checklist
- Recommended implementation paths
- UI requirements overview
- JSON API examples
- Security best practices
- Performance considerations
- Testing strategy
- Known issues and limitations

**Use this when**: You need a high-level overview or quick reference

**Target audience**: Technical leads, product managers, developers

**Length**: ~400 lines, reference guide

---

### 3. [QUICK_START_SESSION_PASSWORD.md](QUICK_START_SESSION_PASSWORD.md)

**Purpose**: Step-by-step setup guides with copy-paste examples

**Contents**:

- 5-minute basic security setup
- 15-minute session management setup
- 30-minute compliance setup (password expiration)
- Common configuration templates
- Pepper management procedures
- Troubleshooting guide
- JSON API examples
- Testing snippets
- Monitoring examples

**Use this when**: You want to implement features quickly with minimal reading

**Target audience**: All developers

**Length**: ~350 lines, tutorial format

---

### 4. [FRAMEWORK_SPECIFIC_EXAMPLES.md](FRAMEWORK_SPECIFIC_EXAMPLES.md)

**Purpose**: Complete working examples for Rails and Hanami

**Contents**:

- Rails complete setup (controllers, views, helpers)
- Hanami complete setup (actions, templates, jobs)
- JSON API implementation
- Background job examples
- Testing examples (RSpec)
- Client-side JavaScript examples

**Use this when**: You need production-ready code for specific framework

**Target audience**: Application developers

**Length**: ~600 lines, code-heavy

---

## Feature Summary

### Session Management Features

| Feature | Database | Rails Ready | Hanami Ready | Recommended |
|---------|----------|-------------|--------------|-------------|
| session_expiration | No | Yes | Yes | All apps |
| single_session | Yes | Yes | Yes | Compliance only |
| active_sessions | Yes | Yes | Yes | Enterprise apps |

### Password Security Features

| Feature | Database | Rails Ready | Hanami Ready | Recommended |
|---------|----------|-------------|--------------|-------------|
| password_pepper | No | Yes | Yes | Strongly recommended |
| password_expiration | Yes | Yes | Yes | Compliance only |
| password_complexity | No | Yes | Yes | Not recommended |

## Quick Navigation

### By Use Case

**I want to add basic security (5 minutes)**
→ [QUICK_START_SESSION_PASSWORD.md - 5-Minute Setup](QUICK_START_SESSION_PASSWORD.md#5-minute-setup-basic-security)

**I want session management UI (15 minutes)**
→ [QUICK_START_SESSION_PASSWORD.md - 15-Minute Setup](QUICK_START_SESSION_PASSWORD.md#15-minute-setup-session-management)

**I need compliance features (30 minutes)**
→ [QUICK_START_SESSION_PASSWORD.md - 30-Minute Setup](QUICK_START_SESSION_PASSWORD.md#30-minute-setup-password-expiration-compliance)

**I need to understand session_expiration in depth**
→ [FEATURE_INTEGRATION_PLAN.md - Section 1](FEATURE_INTEGRATION_PLAN.md#1-session-expiration-feature)

**I need to understand password_pepper security**
→ [FEATURE_INTEGRATION_PLAN.md - Section 6](FEATURE_INTEGRATION_PLAN.md#6-password-pepper-feature)

**I want Rails production code**
→ [FRAMEWORK_SPECIFIC_EXAMPLES.md - Rails Implementation](FRAMEWORK_SPECIFIC_EXAMPLES.md#rails-implementation)

**I want Hanami production code**
→ [FRAMEWORK_SPECIFIC_EXAMPLES.md - Hanami Implementation](FRAMEWORK_SPECIFIC_EXAMPLES.md#hanami-implementation)

**I need JSON API examples**
→ [FRAMEWORK_SPECIFIC_EXAMPLES.md - JSON API](FRAMEWORK_SPECIFIC_EXAMPLES.md#json-api-implementation-framework-agnostic)

### By Feature

**session_expiration**

- Integration plan: [FEATURE_INTEGRATION_PLAN.md#1](FEATURE_INTEGRATION_PLAN.md#1-session-expiration-feature)
- Quick setup: [QUICK_START_SESSION_PASSWORD.md](QUICK_START_SESSION_PASSWORD.md#5-minute-setup-basic-security)
- Summary: [SESSION_PASSWORD_FEATURES_SUMMARY.md](SESSION_PASSWORD_FEATURES_SUMMARY.md#1-session-expiration-feature)

**single_session**

- Integration plan: [FEATURE_INTEGRATION_PLAN.md#2](FEATURE_INTEGRATION_PLAN.md#2-single-session-feature)
- Summary: [SESSION_PASSWORD_FEATURES_SUMMARY.md](SESSION_PASSWORD_FEATURES_SUMMARY.md#2-single-session-feature)

**active_sessions**

- Integration plan: [FEATURE_INTEGRATION_PLAN.md#3](FEATURE_INTEGRATION_PLAN.md#3-active-sessions-feature)
- Quick setup: [QUICK_START_SESSION_PASSWORD.md](QUICK_START_SESSION_PASSWORD.md#15-minute-setup-session-management)
- Rails example: [FRAMEWORK_SPECIFIC_EXAMPLES.md](FRAMEWORK_SPECIFIC_EXAMPLES.md#rails-implementation)
- Hanami example: [FRAMEWORK_SPECIFIC_EXAMPLES.md](FRAMEWORK_SPECIFIC_EXAMPLES.md#hanami-implementation)

**password_complexity**

- Integration plan: [FEATURE_INTEGRATION_PLAN.md#4](FEATURE_INTEGRATION_PLAN.md#4-password-complexity-feature)
- Summary: [SESSION_PASSWORD_FEATURES_SUMMARY.md](SESSION_PASSWORD_FEATURES_SUMMARY.md#4-password-complexity-feature)

**password_expiration**

- Integration plan: [FEATURE_INTEGRATION_PLAN.md#5](FEATURE_INTEGRATION_PLAN.md#5-password-expiration-feature)
- Quick setup: [QUICK_START_SESSION_PASSWORD.md](QUICK_START_SESSION_PASSWORD.md#30-minute-setup-password-expiration-compliance)
- Summary: [SESSION_PASSWORD_FEATURES_SUMMARY.md](SESSION_PASSWORD_FEATURES_SUMMARY.md#5-password-expiration-feature)

**password_pepper**

- Integration plan: [FEATURE_INTEGRATION_PLAN.md#6](FEATURE_INTEGRATION_PLAN.md#6-password-pepper-feature)
- Quick setup: [QUICK_START_SESSION_PASSWORD.md - Pepper Management](QUICK_START_SESSION_PASSWORD.md#pepper-management)
- Summary: [SESSION_PASSWORD_FEATURES_SUMMARY.md](SESSION_PASSWORD_FEATURES_SUMMARY.md#6-password-pepper-feature)

### By Framework

**Rails**

- Complete example: [FRAMEWORK_SPECIFIC_EXAMPLES.md - Rails](FRAMEWORK_SPECIFIC_EXAMPLES.md#rails-implementation)
- Controllers: [FRAMEWORK_SPECIFIC_EXAMPLES.md#4-sessions-controller](FRAMEWORK_SPECIFIC_EXAMPLES.md#4-sessions-controller)
- Views: [FRAMEWORK_SPECIFIC_EXAMPLES.md#5-session-management-view](FRAMEWORK_SPECIFIC_EXAMPLES.md#5-session-management-view)
- Tests: [FRAMEWORK_SPECIFIC_EXAMPLES.md#rails-rspec-tests](FRAMEWORK_SPECIFIC_EXAMPLES.md#rails-rspec-tests)

**Hanami**

- Complete example: [FRAMEWORK_SPECIFIC_EXAMPLES.md - Hanami](FRAMEWORK_SPECIFIC_EXAMPLES.md#hanami-implementation)
- Actions: [FRAMEWORK_SPECIFIC_EXAMPLES.md#8-actions-with-authentication](FRAMEWORK_SPECIFIC_EXAMPLES.md#8-actions-with-authentication)
- Templates: [FRAMEWORK_SPECIFIC_EXAMPLES.md#5-sessions-view-template](FRAMEWORK_SPECIFIC_EXAMPLES.md#5-sessions-view-template)
- Tests: [FRAMEWORK_SPECIFIC_EXAMPLES.md#hanami-tests](FRAMEWORK_SPECIFIC_EXAMPLES.md#hanami-tests)

**JSON API**

- Implementation: [FRAMEWORK_SPECIFIC_EXAMPLES.md#json-api-implementation](FRAMEWORK_SPECIFIC_EXAMPLES.md#json-api-implementation-framework-agnostic)
- Examples: [SESSION_PASSWORD_FEATURES_SUMMARY.md#json-api-support](SESSION_PASSWORD_FEATURES_SUMMARY.md#json-api-support)

## Migration Templates

All required database migration templates already exist in rodauth-rack:

```
lib/rodauth/rack/generators/migration/
├── active_record/
│   ├── single_session.erb           # One session per account
│   ├── active_sessions.erb          # Multiple session tracking
│   └── password_expiration.erb      # Password change timestamps
└── sequel/
    ├── single_session.erb
    ├── active_sessions.erb
    └── password_expiration.erb
```

**Generate migrations**:

```bash
rails generate rodauth:migration active_sessions
rails generate rodauth:migration password_expiration
rails db:migrate
```

## Implementation Paths

### Path 1: Standard Web Application (1 hour)

**Features**: session_expiration + password_pepper

**No migrations required**

**Steps**:

1. Generate pepper: `ruby -r securerandom -e 'puts SecureRandom.hex(32)'`
2. Store in environment or credentials
3. Add to rodauth_main.rb: `enable :session_expiration, :password_pepper`
4. Configure timeouts and pepper
5. Add `rodauth.check_session_expiration` to route handler

**Documentation**: [QUICK_START_SESSION_PASSWORD.md](QUICK_START_SESSION_PASSWORD.md#5-minute-setup-basic-security)

---

### Path 2: Enterprise Application (5 hours)

**Features**: session_expiration + active_sessions + password_pepper + disallow_password_reuse

**Migrations required**: active_sessions, disallow_password_reuse

**Steps**:

1. Follow Path 1
2. Generate migrations
3. Enable active_sessions
4. Build session management UI
5. Add background cleanup job
6. Test multi-device scenarios

**Documentation**:

- Setup: [QUICK_START_SESSION_PASSWORD.md](QUICK_START_SESSION_PASSWORD.md#15-minute-setup-session-management)
- Rails code: [FRAMEWORK_SPECIFIC_EXAMPLES.md - Rails](FRAMEWORK_SPECIFIC_EXAMPLES.md#rails-implementation)
- Hanami code: [FRAMEWORK_SPECIFIC_EXAMPLES.md - Hanami](FRAMEWORK_SPECIFIC_EXAMPLES.md#hanami-implementation)

---

### Path 3: High Security / Compliance (8 hours)

**Features**: All six features

**Migrations required**: single_session OR active_sessions, password_expiration, disallow_password_reuse

**Steps**:

1. Follow Path 2
2. Add password_expiration migration
3. Enable password_expiration
4. Build warning system (emails, banners)
5. Consider password_complexity (discouraged)
6. Document policy for users

**Documentation**:

- Setup: [QUICK_START_SESSION_PASSWORD.md](QUICK_START_SESSION_PASSWORD.md#30-minute-setup-password-expiration-compliance)
- Details: [FEATURE_INTEGRATION_PLAN.md](FEATURE_INTEGRATION_PLAN.md)

## Common Tasks

### Generate Secure Pepper

```bash
ruby -r securerandom -e 'puts SecureRandom.hex(32)'
```

### Store Pepper (Rails)

```bash
EDITOR=vim rails credentials:edit
```

```yaml
rodauth:
  password_pepper: <generated-pepper>
```

### Store Pepper (Hanami)

```bash
# .env
RODAUTH_PASSWORD_PEPPER=<generated-pepper>
```

### Generate Migration

```bash
# Rails
rails generate rodauth:migration active_sessions

# Hanami (using rodauth-rack generator)
bundle exec rodauth-rack generate migration active_sessions
```

### Enable Features

```ruby
# lib/rodauth_main.rb
configure do
  enable :session_expiration, :active_sessions, :password_pepper

  max_session_lifetime 30 * 86400
  session_inactivity_timeout 86400
  password_pepper ENV["RODAUTH_PASSWORD_PEPPER"]
end
```

### Add Route Check

```ruby
# Rails: lib/rodauth_app.rb
route do |r|
  rodauth.check_active_session
  r.rodauth
end

# Hanami: lib/rodauth_app.rb (same)
```

## Testing

### Unit Tests

See: [FRAMEWORK_SPECIFIC_EXAMPLES.md - Testing Examples](FRAMEWORK_SPECIFIC_EXAMPLES.md#testing-examples)

### Integration Testing Strategy

See: [SESSION_PASSWORD_FEATURES_SUMMARY.md - Testing Strategy](SESSION_PASSWORD_FEATURES_SUMMARY.md#testing-strategy)

## Security Checklist

- [ ] Password pepper is at least 32 characters
- [ ] Pepper stored separately from database
- [ ] Session timeouts appropriate for application sensitivity
- [ ] Session expiration enforced on protected routes
- [ ] Expired sessions cleaned up regularly
- [ ] Password policy documented for users
- [ ] Users warned before password expiration
- [ ] Password minimum length at least 12 characters
- [ ] Previous passwords prevented from reuse
- [ ] Pepper rotation procedure documented

## Performance Considerations

See: [SESSION_PASSWORD_FEATURES_SUMMARY.md - Performance Impact](SESSION_PASSWORD_FEATURES_SUMMARY.md#performance-impact)

**Summary**:

- session_expiration: 0 DB queries per request
- single_session: 1 query per request
- active_sessions: 1-2 queries per request
- password_pepper: CPU only, no DB queries
- password_expiration: 1 query on login only

## Troubleshooting

See: [QUICK_START_SESSION_PASSWORD.md - Troubleshooting](QUICK_START_SESSION_PASSWORD.md#troubleshooting)

Common issues:

- Session expires immediately → check timeout values
- Password validation fails → add empty string to previous_password_peppers
- Active sessions not updating → ensure check_active_session in route handler
- BCrypt truncation → set password_maximum_bytes

## Support and References

### Internal Documentation

- Migration generator: `/Users/d/Projects/opensource/d/rodauth-rack/lib/rodauth/rack/generators/migration.rb`
- Base adapter: `/Users/d/Projects/opensource/d/rodauth-rack/lib/rodauth/rack/adapter/base.rb`
- Hanami adapter: `/Users/d/Projects/opensource/d/rodauth-rack/lib/rodauth/rack/hanami.rb`
- Example app: `/Users/d/Projects/opensource/d/rodauth-rack/examples/hanami-demo/`

### External Documentation

- Rodauth documentation: <https://rodauth.jeremyevans.net/>
- Rodauth features list: <https://rodauth.jeremyevans.net/features.html>
- Session expiration: <https://rodauth.jeremyevans.net/rdoc/files/doc/session_expiration_rdoc.html>
- Single session: <https://rodauth.jeremyevans.net/rdoc/files/doc/single_session_rdoc.html>
- Active sessions: <https://rodauth.jeremyevans.net/rdoc/files/doc/active_sessions_rdoc.html>
- Password complexity: <https://rodauth.jeremyevans.net/rdoc/files/doc/password_complexity_rdoc.html>
- Password expiration: <https://rodauth.jeremyevans.net/rdoc/files/doc/password_expiration_rdoc.html>
- Password pepper: <https://rodauth.jeremyevans.net/rdoc/files/doc/password_pepper_rdoc.html>

## Contributing

When adding new features or updating documentation:

1. Update FEATURE_INTEGRATION_PLAN.md with comprehensive details
2. Update SESSION_PASSWORD_FEATURES_SUMMARY.md with summary
3. Add quick-start steps to QUICK_START_SESSION_PASSWORD.md
4. Add framework-specific examples to FRAMEWORK_SPECIFIC_EXAMPLES.md
5. Update this index file with navigation links

## License

MIT License - Same as rodauth-rack project
