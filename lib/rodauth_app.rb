# frozen_string_literal: true

require "roda"
require "rodauth"
require_relative "../config/database"

# Rodauth middleware for MyApp
# This Roda app handles all authentication logic and can be used as middleware
# in your Sinatra application.
class RodauthApp < Roda
  # Enable Roda middleware plugin so we can use this as Rack middleware
  plugin :middleware, forward_response_headers: true

  # Enable CSRF protection
  plugin :route_csrf

  # Configure Rodauth plugin
  plugin :rodauth do
    # Enable authentication features
    enable :login, :logout, :create_account, :verify_account,
           :reset_password, :change_password, :close_account, :remember

    # Database connection
    db DB

    # Account table configuration
    accounts_table :users

    # Security configuration
    hmac_secret ENV.fetch("HMAC_SECRET")

    # Password hashing
    require "bcrypt"

    # Email configuration
    email_from ENV.fetch("EMAIL_FROM", "noreply@example.com")
    email_subject_prefix "[MyApp] "

  end

  route do |r|
    # Route Rodauth requests
    r.rodauth

    # Auto-login remembered users
    rodauth.load_memory

    # Rodauth routes are handled above
    # Your Sinatra app handles all other routes
  end
end
