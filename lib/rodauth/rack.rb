# frozen_string_literal: true

require_relative "rack/version"
require_relative "rack/adapter/base"
require_relative "rack/middleware"
require_relative "rack/generators/migration"

module Rodauth
  # Rack integration for Rodauth authentication framework
  module Rack
    class Error < StandardError; end

    class << self
      # Get or set the default adapter class
      attr_accessor :adapter_class

      # Get or set the default account model
      attr_accessor :account_model

      # Delegate to the actual Rack gem to avoid namespace collision
      # when Rodauth's features check Rack.release
      delegate :release, to: :"::Rack"

      delegate :release_version, to: :"::Rack"
    end
  end
end
