ENV["HANAMI_ENV"] = "test"

require "bundler/setup"
require "minitest/autorun"
require "minitest/pride"

# Load Rodauth core and Rack integration
require "rodauth"
require "roda"
require_relative "../../lib/rodauth/rack"

# Mock Hanami constant to prevent LoadError
module Hanami
  class App
    def self.config
      @config ||= Struct.new(:actions).new(Struct.new(:csrf_protection).new(true))
    end

    def self.[](_key)
      {}
    end
  end

  module Action
    class Request
      attr_accessor :session, :params, :env

      def initialize
        @session = {}
        @params = {}
        @env = {}
      end
    end

    class Response
    end
  end
end

# Define Rodauth::Rack::Hanami module namespace
module Rodauth
  module Rack
    module Hanami
      class Error < StandardError
      end

      module Feature
      end
    end
  end
end

# Load individual Hanami feature modules
require_relative "../../lib/rodauth/rack/hanami/feature/base"
require_relative "../../lib/rodauth/rack/hanami/feature/csrf"
require_relative "../../lib/rodauth/rack/hanami/feature/session"
require_relative "../../lib/rodauth/rack/hanami/feature/render"
require_relative "../../lib/rodauth/rack/hanami/feature/email"

# Define the :hanami feature for Rodauth
Rodauth::Feature.define(:hanami) do
  Rodauth::Rack::Hanami::Feature::RodauthFeature = self
  Rodauth::Rack::Hanami::FeatureConfiguration = configuration

  include Rodauth::Rack::Hanami::Feature::Base
  include Rodauth::Rack::Hanami::Feature::Csrf
  include Rodauth::Rack::Hanami::Feature::Session
  include Rodauth::Rack::Hanami::Feature::Render
  include Rodauth::Rack::Hanami::Feature::Email
end

class HanamiTestCase < Minitest::Test
  def setup
    super
  end

  def teardown
    super
  end
end
