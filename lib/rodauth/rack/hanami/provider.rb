# frozen_string_literal: true

module Rodauth
  module Rack
    module Hanami
      # Provider for integrating Rodauth with Hanami's dependency injection system.
      # This should be registered in config/providers/rodauth.rb
      class Provider < ::Hanami::Provider::Source
        def prepare
          require "rodauth/rack/hanami"
          require "rodauth/rack/hanami/middleware"
        end

        def start
          # Register the Rodauth middleware if enabled
          if Rodauth::Rack::Hanami.middleware?
            target.app.config.middleware.use(
              Rodauth::Rack::Hanami::Middleware,
              env: target.app.config.env
            )
          end

          # Make Rodauth accessible from the container
          register "rodauth" do
            Rodauth::Rack::Hanami
          end
        end

        def stop
          # Cleanup if needed
        end
      end
    end
  end
end
