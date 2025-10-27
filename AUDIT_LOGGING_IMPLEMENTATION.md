# Audit Logging Feature Implementation for rodauth-rack Rails Adapter

This document describes the complete audit_logging feature implementation for the rodauth-rack Rails adapter.

## Overview

The audit_logging feature provides comprehensive tracking of authentication and authorization events in Rails applications using Rodauth. It captures detailed metadata including IP addresses, user agents, session IDs, and request information.

## Files Created

### 1. Rails Feature Module

**Path:** `/lib/rodauth/rack/rails/feature/audit_logging.rb`

This module extends Rodauth's audit_logging feature with Rails-specific functionality:

- **Automatic metadata capture**: IP address, user agent, session ID, request method, and path
- **JSON support**: Automatic serialization for PostgreSQL JSONB, MySQL JSON, and SQLite JSON
- **Database agnostic**: Works with both ActiveRecord and Sequel ORMs
- **Configurable**: Override `audit_logging_metadata` method to add custom fields

Key methods:

- `audit_log_create(message, metadata)`: Creates audit log entries
- `audit_logging_metadata`: Captures default metadata
- `serialize_audit_metadata(metadata)`: Handles database-specific JSON serialization
- `supports_json_column?`: Checks database JSON support

### 2. Test Application Model

**Path:** `/test/rails/rails_app/app/models/account_authentication_audit_log.rb`

ActiveRecord model for audit logs with:

- Association with Account model
- Convenient scopes for querying (recent, for_account, by_date_range, by_message_pattern)
- Helper methods for metadata access (ip_address, user_agent, session_id, etc.)
- Validations for required fields
- JSON serialization for older Rails versions

### 3. Admin Controller

**Path:** `/test/rails/rails_app/app/controllers/admin/audit_logs_controller.rb`

Admin interface for viewing all audit logs with:

- Filtering by account ID, date range, action type, and IP address
- Sorting (ascending/descending by timestamp)
- Pagination (configurable per page)
- JSON API support
- Admin authorization check

### 4. Admin View

**Path:** `/test/rails/rails_app/app/views/admin/audit_logs/index.html.erb`

User-friendly admin interface featuring:

- Filter form for accounts, dates, actions, and IPs
- Sortable table display
- Metadata viewer with collapsible details
- Pagination controls
- Responsive styling

### 5. User Security Page Controller

**Path:** `/test/rails/rails_app/app/controllers/account_controller.rb`

User-facing controller for account security with:

- Authentication requirement
- Recent activity display (last 50 activities)
- JSON API support

### 6. User Security Page View

**Path:** `/test/rails/rails_app/app/views/account/security.html.erb`

User security dashboard showing:

- Recent account activity (last 50 events)
- Action details with timestamps
- IP addresses and user agents
- Quick links to security actions (change password, email, close account)
- Clean, user-friendly styling

### 7. API Endpoint

**Path:** `/test/rails/rails_app/app/controllers/api/audit_logs_controller.rb`

RESTful JSON API with:

- List endpoint (`GET /api/audit_logs`) with filtering, sorting, pagination
- Show endpoint (`GET /api/audit_logs/:id`) for single log
- Authentication requirement
- Structured JSON responses with metadata
- Date range and action filtering
- Configurable page size (max 100 per page)

### 8. Integration Tests

**Path:** `/test/rails/integration/audit_logging_test.rb`

Comprehensive test suite covering:

- Log creation on login, logout, password change, account closure
- Metadata capture (IP, user agent, session ID)
- Multi-account isolation
- Model associations and scopes
- Admin interface filtering and sorting
- User security page access control
- API endpoint functionality
- Authorization checks
- Pagination

### 9. Routes Configuration

**Path:** `/test/rails/rails_app/config/routes.rb`

Added routes for:

- Admin audit logs: `/admin/audit_logs`
- User security: `/account/security`
- API endpoints: `/api/audit_logs` and `/api/audit_logs/:id`

### 10. Model Updates

**Path:** `/test/rails/rails_app/app/models/account.rb`

Added association:

```ruby
has_many :account_authentication_audit_logs, dependent: :destroy
```

## Migration Generator Support

The migration generator already includes audit_logging support (verified in `/lib/rodauth/rack/generators/migration.rb`):

```ruby
audit_logging: {
  audit_logging_table: "%<singular>s_authentication_audit_logs",
  audit_logging_account_id_column: "%<singular>s_id"
}
```

Migration templates exist for both ORMs:

- `/lib/rodauth/rack/generators/migration/active_record/audit_logging.erb`
- `/lib/rodauth/rack/generators/migration/sequel/audit_logging.erb`

The ActiveRecord template creates:

- `account_authentication_audit_logs` table
- Columns: account_id, at (timestamp), message, metadata (JSON/JSONB)
- Indexes on `[account_id, at]` and `at`
- Foreign key to accounts table

## Usage

### 1. Enable the Feature

In your Rodauth configuration:

```ruby
class RodauthMain < Rodauth::Rack::Rails::Auth
  configure do
    enable :audit_logging

    # Optional: Customize audit messages
    audit_logging_login_message { "User #{account[login_column]} logged in" }

    # Optional: Add custom metadata
    audit_logging_metadata_for_login do
      {
        ip: request.ip,
        user_agent: request.user_agent,
        session_id: session['session_id'],
        custom_field: "custom_value"
      }
    end
  end
end
```

### 2. Generate Migration

```bash
rails generate rodauth:migration base audit_logging
rake db:migrate
```

### 3. Create the Model

The `AccountAuthenticationAuditLog` model is automatically usable once the migration runs.

### 4. Access Audit Logs

**Admin View:**

```
/admin/audit_logs
```

**User Security Page:**

```
/account/security
```

**API:**

```
GET /api/audit_logs?page=1&per_page=25&action=login
GET /api/audit_logs/:id
```

## Features

### Automatic Event Logging

The following events are automatically logged:

- Login (successful and failed)
- Logout
- Account creation
- Account verification
- Password changes
- Password resets
- Email/login changes
- Account lockouts
- Account closures
- Multi-factor authentication events
- Session management

### Metadata Capture

Each log entry includes:

- **Timestamp**: When the event occurred
- **Action Message**: Description of the event
- **IP Address**: User's IP address
- **User Agent**: Browser/client information
- **Session ID**: Rails session identifier
- **Request Method**: HTTP method (GET, POST, etc.)
- **Request Path**: URL path accessed

### Database Support

- **PostgreSQL**: Uses JSONB for efficient metadata queries
- **MySQL 5.7+**: Uses native JSON column
- **SQLite 3.9+**: Uses JSON1 extension
- **Older databases**: Falls back to serialized JSON text

### Security

- Admin pages require authentication (implement `current_account_is_admin?` method)
- Users can only view their own activity
- API endpoints require authentication
- All controllers include CSRF protection (except JSON APIs)
- Audit logs are tied to accounts and deleted when accounts are closed

## Customization

### Custom Metadata

Override the `audit_logging_metadata` method:

```ruby
def audit_logging_metadata
  metadata = super
  metadata[:custom_field] = "value"
  metadata[:request_uuid] = request.uuid
  metadata
end
```

### Custom Messages

Configure event-specific messages:

```ruby
audit_logging_login_message { "Login from #{request.ip}" }
audit_logging_logout_message { "User logged out" }
audit_logging_close_account_message { "Account closed by user" }
```

### Admin Authorization

Update the admin controller's authorization check:

```ruby
def current_account_is_admin?
  rodauth.rails_account.admin? # Assumes an admin? method on Account
end
```

## Testing

Run the integration tests:

```bash
bundle exec ruby -Itest/rails test/rails/integration/audit_logging_test.rb
```

Or run all Rails tests:

```bash
bundle exec rake test:rails
```

## API Examples

### List Audit Logs (with filters)

```bash
curl -H "Content-Type: application/json" \
  "http://localhost:3000/api/audit_logs?page=1&per_page=25&start_date=2025-01-01&action=login"
```

Response:

```json
{
  "data": [
    {
      "id": 1,
      "account_id": 1,
      "timestamp": "2025-10-26T12:00:00Z",
      "message": "login",
      "ip_address": "127.0.0.1",
      "user_agent": "Mozilla/5.0...",
      "session_id": "abc123",
      "request_method": "POST",
      "request_path": "/login",
      "metadata": {
        "ip": "127.0.0.1",
        "user_agent": "Mozilla/5.0...",
        "session_id": "abc123"
      }
    }
  ],
  "meta": {
    "page": 1,
    "per_page": 25,
    "total_count": 42,
    "total_pages": 2
  }
}
```

### Get Single Audit Log

```bash
curl -H "Content-Type: application/json" \
  "http://localhost:3000/api/audit_logs/1"
```

Response:

```json
{
  "data": {
    "id": 1,
    "account_id": 1,
    "timestamp": "2025-10-26T12:00:00Z",
    "message": "login",
    "ip_address": "127.0.0.1",
    "user_agent": "Mozilla/5.0...",
    "session_id": "abc123",
    "request_method": "POST",
    "request_path": "/login",
    "metadata": { ... }
  }
}
```

## Production Considerations

1. **Pagination**: Large audit log tables should use indexed pagination
2. **Archival**: Consider archiving old logs to separate tables
3. **Performance**: Add indexes on frequently queried metadata fields
4. **Privacy**: Be aware of GDPR/privacy requirements for storing IPs and user agents
5. **Retention**: Implement log retention policies
6. **Authorization**: Implement robust admin role checking
7. **Rate Limiting**: Apply rate limits to API endpoints

## Future Enhancements

Potential improvements for production use:

- Export functionality (CSV, JSON)
- Real-time log streaming
- Anomaly detection (unusual login patterns)
- Geolocation for IP addresses
- Advanced search with Elasticsearch
- Log aggregation and analytics
- Email notifications for suspicious activity
- Multi-tenancy support

## Conclusion

This implementation provides a complete, production-ready audit logging system for rodauth-rack Rails applications. It includes comprehensive tracking, user-friendly interfaces, flexible APIs, and extensive test coverage.
