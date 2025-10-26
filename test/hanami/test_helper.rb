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

  def self.app
    App
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
    end
  end
end

# Load Hanami Auth and App classes (which load the feature modules)
require_relative "../../lib/rodauth/rack/hanami/auth"
require_relative "../../lib/rodauth/rack/hanami/app"

class HanamiTestCase < Minitest::Test
  def setup
    super
  end

  def teardown
    super
  end
end
