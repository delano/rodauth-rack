# frozen_string_literal: true

require "rodauth"
require "rodauth/rack/hanami/feature"

module Rodauth
  module Rack
    module Hanami
      # Base auth class that applies some changes to the default configuration.
      class Auth < Rodauth::Auth
        configure do
          enable :hanami

          # database functions are more complex to set up, so disable them by default
          use_database_authentication_functions? false

          # avoid having to set deadline values in column default values
          set_deadline_values? true

          # use HMACs for additional security
          hmac_secret { Rodauth::Rack::Hanami.secret_key_base }
        end
      end
    end
  end
end
