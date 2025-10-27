# frozen_string_literal: true

require_relative "../version"
require "rodauth/model"

module Rodauth
  module Rack
    module Hanami
      class Error < StandardError
      end

      # This allows avoiding loading Rodauth at boot time.
      autoload :App, "rodauth/rack/hanami/app"
      autoload :Auth, "rodauth/rack/hanami/auth"

      @app = nil
      @middleware = true
      @tilt = true

      class << self
        def lib(**options, &block)
          c = Class.new(Rodauth::Rack::Hanami::App)
          c.configure(json: false, **options) do
            enable :internal_request
            instance_exec(&block)
          end
          c.freeze
          c.rodauth
        end

        def rodauth(name = nil, account: nil, **options)
          auth_class = app.rodauth!(name)

          unless auth_class.features.include?(:internal_request)
            raise Rodauth::Rack::Hanami::Error,
                  "Rodauth::Rack::Hanami.rodauth requires internal_request feature to be enabled"
          end

          options[:account_id] = account.id if account

          instance = auth_class.internal_request_eval(options) do
            if defined?(ROM::Struct) && account.is_a?(ROM::Struct)
              @account = account.to_h.transform_keys(&:to_sym)
            elsif defined?(Sequel::Model) && account.is_a?(Sequel::Model)
              @account = account.values
            end
            self
          end

          # clean up inspect output
          instance.remove_instance_variable(:@internal_request_block)
          instance.remove_instance_variable(:@internal_request_return_value)

          instance
        end

        def model(name = nil, **)
          Rodauth::Model.new(app.rodauth!(name), **)
        end

        # Routing constraint that requires authenticated account.
        def authenticate(name = nil, &condition)
          lambda do |request|
            rodauth = request.env.fetch ["rodauth", *name].join(".")
            rodauth.require_account
            condition.nil? || condition.call(rodauth)
          end
        end

        def secret_key_base
          ::Hanami.app["settings"].secret_key_base
        end

        def configure
          yield self
        end

        attr_writer :app, :middleware, :tilt

        def app
          raise Rodauth::Rack::Hanami::Error, "app was not configured" unless @app

          @app.constantize
        end

        def middleware?
          @middleware
        end

        def tilt?
          @tilt
        end
      end
    end
  end
end
