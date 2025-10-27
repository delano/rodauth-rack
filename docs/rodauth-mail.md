# Mail Configuration in Rodauth

This document explains how to configure SMTP and mail settings in Rodauth for sending authentication emails.

## Overview

Rodauth uses the **Mail gem** for email functionality. Email configuration happens at two levels:

1. **Global Mail Configuration** - SMTP settings and delivery method
2. **Rodauth Email Configuration** - Email addresses, subjects, and custom logic

## Global Mail Configuration (SMTP Settings)

Configure SMTP **before** loading Rodauth:

```ruby
require 'mail'

# SMTP configuration
Mail.defaults do
  delivery_method :smtp, {
    address:              'smtp.gmail.com',
    port:                 587,
    domain:               'yoursite.com',
    user_name:            'your-email@gmail.com',
    password:             'your-app-password',
    authentication:       'plain',
    enable_starttls_auto: true
  }
end

# Then configure Rodauth
plugin :rodauth do
  enable :login, :reset_password, :verify_account
  # ... other config
end
```

## Rodauth Email Configuration

Within your Rodauth configuration block:

```ruby
plugin :rodauth do
  enable :reset_password, :verify_account

  # Basic email settings
  email_from 'noreply@yoursite.com'
  email_subject_prefix '[YourSite] '

  # Customize recipient (defaults to account email)
  email_to do
    account[:email] # or custom logic
  end

  # Override email sending for custom delivery
  send_email do |email|
    # Custom delivery logic
    email.deliver!
  end
end
```

## Common SMTP Providers

### Gmail

```ruby
Mail.defaults do
  delivery_method :smtp, {
    address:              'smtp.gmail.com',
    port:                 587,
    user_name:            'your-email@gmail.com',
    password:             'your-app-password',  # Use app password, not account password
    authentication:       'plain',
    enable_starttls_auto: true
  }
end
```

**Note**: For Gmail, you need to use an App Password, not your regular Gmail password.

### SendGrid

```ruby
Mail.defaults do
  delivery_method :smtp, {
    address:        'smtp.sendgrid.net',
    port:           587,
    user_name:      'apikey',
    password:       'your-sendgrid-api-key',
    authentication: 'plain',
    enable_starttls_auto: true
  }
end
```

### Mailgun

```ruby
Mail.defaults do
  delivery_method :smtp, {
    address:        'smtp.mailgun.org',
    port:           587,
    user_name:      'postmaster@your-domain.mailgun.org',
    password:       'your-mailgun-password',
    authentication: 'plain',
    enable_starttls_auto: true
  }
end
```

### Amazon SES

```ruby
Mail.defaults do
  delivery_method :smtp, {
    address:        'email-smtp.us-east-1.amazonaws.com',
    port:           587,
    user_name:      'your-ses-smtp-username',
    password:       'your-ses-smtp-password',
    authentication: 'plain',
    enable_starttls_auto: true
  }
end
```

## Environment-Based Configuration

Configure different delivery methods per environment:

```ruby
case ENV['RACK_ENV']
when 'production'
  Mail.defaults do
    delivery_method :smtp, {
      address:   ENV['SMTP_ADDRESS'],
      port:      ENV['SMTP_PORT'],
      user_name: ENV['SMTP_USERNAME'],
      password:  ENV['SMTP_PASSWORD'],
      authentication: 'plain',
      enable_starttls_auto: true
    }
  end
when 'development'
  Mail.defaults do
    delivery_method :file, location: 'tmp/mails'
  end
when 'test'
  Mail.defaults do
    delivery_method :test
  end
end
```

## Custom Email Templates

Override email content by defining methods in your Rodauth configuration:

### Custom Reset Password Email

```ruby
plugin :rodauth do
  enable :reset_password

  # Custom email subject
  reset_password_email_subject do
    "Reset your #{domain} password"
  end

  # Custom email body
  reset_password_email_body do
    <<~EMAIL
      Hello,

      Someone has requested a password reset for your account.

      Click here to reset: #{reset_password_email_link}

      If you didn't request this, please ignore this email.

      Thanks,
      The #{domain} Team
    EMAIL
  end
end
```

### Custom Verification Email

```ruby
plugin :rodauth do
  enable :verify_account

  verify_account_email_subject do
    "Please verify your #{domain} account"
  end

  verify_account_email_body do
    <<~EMAIL
      Welcome to #{domain}!

      Please verify your account by clicking this link:
      #{verify_account_email_link}

      Thanks for signing up!
    EMAIL
  end
end
```

## Email Configuration Methods

Key configuration methods available in Rodauth:

```ruby
plugin :rodauth do
  # Sender email address (defaults to "webmaster@#{domain}")
  email_from 'noreply@yoursite.com'

  # Subject prefix for all emails
  email_subject_prefix '[YourSite] '

  # Customize recipient email address
  email_to do
    account[:email] # or custom logic
  end

  # Custom email creation
  create_email do |subject, body|
    mail = Mail.new
    mail.from = email_from
    mail.to = email_to
    mail.subject = "#{email_subject_prefix}#{subject}"
    mail.body = body
    # Add custom headers, attachments, etc.
    mail
  end

  # Custom email sending
  send_email do |email|
    # Add logging, error handling, etc.
    puts "Sending email to #{email.to}: #{email.subject}"
    email.deliver!
  end
end
```

## Alternative Delivery Methods

### File Delivery (Development)

Saves emails to files instead of sending them:

```ruby
Mail.defaults do
  delivery_method :file, location: 'tmp/mails'
end
```

### Test Delivery

Captures emails in memory for testing:

```ruby
Mail.defaults do
  delivery_method :test
end

# Access sent emails in tests
Mail::TestMailer.deliveries.last
```

### Sendmail

Use local sendmail binary:

```ruby
Mail.defaults do
  delivery_method :sendmail
end
```

## Email Features

Features that send emails and can be customized:

- **reset_password** - Password reset emails
- **verify_account** - Account verification emails
- **verify_login_change** - Login change verification emails
- **change_password_notify** - Password change notifications
- **lockout** - Account lockout notifications
- **email_auth** - Passwordless email authentication
- **otp_lockout_email** - OTP lockout notifications
- **otp_modify_email** - OTP setup/disable notifications
- **webauthn_modify_email** - WebAuthn setup/removal notifications

## Security Considerations

### HMAC Protection

Enable HMAC protection for email tokens:

```ruby
plugin :rodauth do
  # Set an HMAC secret for token security
  hmac_secret 'your-secret-key-here'

  # Disable raw token acceptance (recommended for production)
  allow_raw_email_token? false
end
```

### Rate Limiting

Built-in rate limiting prevents email spam:

```ruby
plugin :rodauth do
  enable :reset_password

  # Don't resend reset email within 5 minutes
  reset_password_skip_resend_email_within 300
end
```

## Testing Email

In your test suite:

```ruby
# Configure test delivery
Mail.defaults do
  delivery_method :test
end

# In tests, check sent emails
def test_password_reset_email
  post '/reset-password', email: 'user@example.com'

  email = Mail::TestMailer.deliveries.last
  assert_includes email.to, 'user@example.com'
  assert_includes email.subject, 'Reset Password'
  assert_includes email.body.to_s, 'reset'
end

# Clear deliveries between tests
def setup
  Mail::TestMailer.deliveries.clear
end
```

## Troubleshooting

### Common Issues

1. **Authentication failures**: Ensure you're using the correct credentials and authentication method
2. **Port blocked**: Try different ports (25, 465, 587, 2525)
3. **Gmail App Passwords**: Regular Gmail passwords won't work with SMTP
4. **Development emails not visible**: Check your delivery method and file location

### Debug Logging

Enable Mail gem logging:

```ruby
Mail.defaults do
  delivery_method :smtp, {
    # ... SMTP settings
    openssl_verify_mode: 'none',
    enable_starttls_auto: true
  }
end

# Enable logging
Mail.defaults do
  retriever_method :imap, {
    # ... settings
  }
end
```

### Testing SMTP Configuration

Test your SMTP settings independently:

```ruby
require 'mail'

Mail.defaults do
  delivery_method :smtp, {
    # your SMTP settings
  }
end

mail = Mail.new do
  from     'test@yoursite.com'
  to       'recipient@example.com'
  subject  'Test email'
  body     'This is a test email'
end

mail.deliver!
puts "Email sent successfully!"
```
