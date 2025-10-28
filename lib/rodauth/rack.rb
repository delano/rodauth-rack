# frozen_string_literal: true

require "rack"

# Rodauth must be loaded before our external features can be defined
begin
  require "rodauth"
rescue LoadError
  # Rodauth not available - external features won't be loaded
end

require_relative "rack/version"
require_relative "rack/generators/migration"

# Load external Rodauth features (only if Rodauth is available)
require_relative "../rodauth/features/table_guard" if defined?(Rodauth)

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
