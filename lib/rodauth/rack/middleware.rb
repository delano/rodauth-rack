# frozen_string_literal: true

module Rodauth
  module Rack
    # Rack middleware that integrates Rodauth authentication into the request/response cycle.
    #
    # This middleware wraps the Rodauth Roda app and delegates authentication
    # requests to it, while passing through all other requests to the main application.
    #
    # @example Basic usage
    #   use Rodauth::Rack::Middleware, auth_class: RodauthApp
    #
    # @example With custom adapter
    #   use Rodauth::Rack::Middleware,
    #     auth_class: RodauthApp,
    #     adapter: MyFramework::RodauthAdapter
    class Middleware
      attr_reader :app, :auth_class, :adapter_class

      # Initialize the middleware
      #
      # @param app [#call] The Rack application
      # @param auth_class [Class] The Rodauth Roda app class
      # @param adapter [Class] The adapter class (optional)
      def initialize(app, auth_class:, adapter: nil)
        @app = app
        @auth_class = auth_class
        @adapter_class = adapter
      end

      # Process the request
      #
      # @param env [Hash] Rack environment
      # @return [Array] Rack response tuple [status, headers, body]
      def call(env)
        request = ::Rack::Request.new(env)

        # Check if this is a Rodauth request
        if rodauth_request?(request)
          process_rodauth_request(env)
        else
          # Pass through to the main app
          response = app.call(env)
          attach_rodauth_instance(env, response)
          response
        end
      end

      private

      # Check if this request should be handled by Rodauth
      #
      # @param request [Rack::Request] The request
      # @return [Boolean] True if Rodauth should handle this request
      def rodauth_request?(request)
        # Check if the path matches any Rodauth route
        # This can be customized based on the Rodauth configuration
        path = request.path

        # Common Rodauth paths
        rodauth_paths.any? { |prefix| path.start_with?(prefix) }
      end

      # Get the list of Rodauth path prefixes
      #
      # @return [Array<String>] List of path prefixes
      def rodauth_paths
        # These are common Rodauth paths, but should be configurable
        # based on the actual Rodauth configuration
        %w[
          /login
          /logout
          /create-account
          /verify-account
          /reset-password
          /change-password
          /change-login
          /close-account
        ]
      end

      # Process a Rodauth request
      #
      # @param env [Hash] Rack environment
      # @return [Array] Rack response tuple
      def process_rodauth_request(env)
        auth_class.call(env)
      end

      # Attach the Rodauth instance to the environment for access in the app
      #
      # @param env [Hash] Rack environment
      # @param response [Array] Rack response
      # @return [void]
      def attach_rodauth_instance(env, _response)
        # Store the Rodauth instance in the environment
        # so it can be accessed in the main application
        env["rodauth"] ||= auth_class.rodauth
        env["rodauth.adapter"] = adapter_class if adapter_class
      end
    end
  end
end
