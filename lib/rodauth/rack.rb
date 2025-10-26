# frozen_string_literal: true

require "rack"

require_relative "rack/version"
require_relative "rack/adapter/base"
require_relative "rack/middleware"
require_relative "rack/generators/migration"

module Rodauth
  # Rack integration for Rodauth authentication framework
  module Rack
    class Error < StandardError; end

    # Aliases to avoid namespace collision with ::Rack gem
    # When Rodauth code references Rack constants, it should find ::Rack constants
    Request = ::Rack::Request unless const_defined?(:Request)
    Utils = ::Rack::Utils unless const_defined?(:Utils)
    Response = ::Rack::Response unless const_defined?(:Response)

    class << self
      # Get or set the default adapter class
      attr_accessor :adapter_class

      # Get or set the default account model
      attr_accessor :account_model

      # Delegate to the actual Rack gem to avoid namespace collision
      # when Rodauth's features check Rack.release
      def release
        ::Rack.release
      end

      def release_version
        ::Rack.release_version
      end
    end
  end
end
