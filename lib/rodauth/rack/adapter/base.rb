# frozen_string_literal: true

module Rodauth
  module Rack
    module Adapter
      # Abstract base class defining the interface for framework adapters.
      #
      # Framework-specific adapters (Rails, Hanami, Sinatra, Roda) must inherit
      # from this class and implement all abstract methods.
      #
      # The adapter serves as a bridge between Rodauth and the host framework,
      # handling framework-specific concerns like view rendering, CSRF protection,
      # session management, and email delivery.
      #
      # @abstract Subclass and override abstract methods to implement a framework adapter
      class Base
        attr_reader :request, :response

        # Initialize the adapter with request and response objects
        #
        # @param request [Rack::Request] The request object
        # @param response [Rack::Response] The response object
        def initialize(request, response)
          @request = request
          @response = response
        end

        # ====================
        # View Rendering
        # ====================

        # Render a view template with locals
        #
        # @param template [String] Template name (e.g., "login", "create_account")
        # @param locals [Hash] Local variables for the template
        # @return [String] Rendered HTML
        # @abstract
        def render(template, locals = {})
          raise NotImplementedError, "#{self.class}#render must be implemented"
        end

        # Get the base path for Rodauth view templates
        #
        # @return [String] Path to view templates directory
        # @abstract
        def view_path
          raise NotImplementedError, "#{self.class}#view_path must be implemented"
        end

        # ====================
        # CSRF Protection
        # ====================

        # Get the CSRF token for the current session
        #
        # @return [String] CSRF token
        # @abstract
        def csrf_token
          raise NotImplementedError, "#{self.class}#csrf_token must be implemented"
        end

        # Get the CSRF field name (e.g., "authenticity_token")
        #
        # @return [String] CSRF field name
        # @abstract
        def csrf_field
          raise NotImplementedError, "#{self.class}#csrf_field must be implemented"
        end

        # Check if the CSRF token is valid
        #
        # @param token [String] Token to validate
        # @return [Boolean] True if valid
        # @abstract
        def valid_csrf_token?(token)
          raise NotImplementedError, "#{self.class}#valid_csrf_token? must be implemented"
        end

        # ====================
        # Session Management
        # ====================

        # Get the session object
        #
        # @return [Hash] Session hash
        delegate :session, to: :request

        # Clear the session
        #
        # @return [void]
        def clear_session
          request.session.clear
        end

        # ====================
        # Flash Messages
        # ====================

        # Get the flash hash
        #
        # @return [Hash] Flash messages
        # @abstract
        def flash
          raise NotImplementedError, "#{self.class}#flash must be implemented"
        end

        # Set a flash message
        #
        # @param key [Symbol] Message type (:notice, :error, etc.)
        # @param message [String] The message
        # @return [void]
        def flash_now(key, message)
          flash[key] = message
        end

        # ====================
        # URL Generation
        # ====================

        # Generate a URL for a given path
        #
        # @param path [String] The path
        # @param options [Hash] URL options (host, protocol, etc.)
        # @return [String] Full URL
        # @abstract
        def url_for(path, **options)
          raise NotImplementedError, "#{self.class}#url_for must be implemented"
        end

        # Get the current request path
        #
        # @return [String] Request path
        delegate :path, to: :request, prefix: true

        # ====================
        # Email Delivery
        # ====================

        # Deliver an email
        #
        # @param mailer [Symbol] Mailer method name
        # @param args [Array] Arguments for the mailer
        # @return [void]
        # @abstract
        def deliver_email(mailer, *args)
          raise NotImplementedError, "#{self.class}#deliver_email must be implemented"
        end

        # ====================
        # Model Integration
        # ====================

        # Get the account model class
        #
        # @return [Class] Account model class
        # @abstract
        def account_model
          raise NotImplementedError, "#{self.class}#account_model must be implemented"
        end

        # Find an account by ID
        #
        # @param id [Integer] Account ID
        # @return [Object, nil] Account model instance or nil
        def find_account(id)
          account_model.find(id)
        end

        # ====================
        # Configuration
        # ====================

        # Get the Rodauth configuration
        #
        # @return [Hash] Configuration hash
        # @abstract
        def rodauth_config
          raise NotImplementedError, "#{self.class}#rodauth_config must be implemented"
        end

        # Get the database connection
        #
        # @return [Sequel::Database] Database connection
        # @abstract
        def db
          raise NotImplementedError, "#{self.class}#db must be implemented"
        end

        # ====================
        # Request/Response
        # ====================

        # Get request parameters
        #
        # @return [Hash] Request parameters
        delegate :params, to: :request

        # Get request environment
        #
        # @return [Hash] Rack environment
        delegate :env, to: :request

        # Redirect to a path
        #
        # @param path [String] Path to redirect to
        # @param status [Integer] HTTP status code (default: 302)
        # @return [void]
        def redirect(path, status: 302)
          response.redirect(path, status)
        end

        # Set response status
        #
        # @param status [Integer] HTTP status code
        # @return [void]
        delegate :status=, to: :response
      end
    end
  end
end
