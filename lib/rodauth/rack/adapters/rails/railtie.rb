# frozen_string_literal: true

module Rodauth
  module Rack
    module Rails
      # Railtie for automatic Rails integration
      #
      # Automatically configures Rodauth in Rails applications:
      # - Sets Rails adapter as default
      # - Adds middleware to Rails stack
      # - Includes controller helper methods
      class Railtie < ::Rails::Railtie
        # Set Rails adapter as default for this Rails app
        config.before_configuration do
          Rodauth::Rack.adapter_class = Rodauth::Rack::Rails::Adapter
        end

        # Add middleware after Rails loads but before user initializers
        initializer "rodauth.rack.middleware", after: :load_config_initializers do |app|
          # TODO: Add Rodauth::Rack::Middleware to Rails middleware stack
          # app.middleware.use Rodauth::Rack::Middleware, auth_class: RodauthApp
        end

        # Add controller helper methods
        initializer "rodauth.rack.controller_methods" do
          ActiveSupport.on_load(:action_controller) do
            # TODO: Include controller methods
            # include Rodauth::Rack::Rails::ControllerMethods
          end
        end

        # Configure test environment
        initializer "rodauth.rack.test" do
          if ::Rails.env.test?
            # Reduce bcrypt cost for faster tests
            ENV["RACK_ENV"] = "test"
          end
        end
      end
    end
  end
end
