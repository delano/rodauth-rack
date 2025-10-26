# frozen_string_literal: true

module Rodauth
  module Rack
    module Hanami
      # Middleware that's added to the Hanami middleware stack. This allows the
      # app class to be reloadable in development mode.
      class Middleware
        def initialize(app)
          @app = app
        end

        def call(env)
          app = Rodauth::Rack::Hanami.app.new(@app)

          # allow the Hanami app to call Rodauth methods that throw :halt
          catch(:halt) do
            app.call(env)
          end
        end
      end
    end
  end
end
