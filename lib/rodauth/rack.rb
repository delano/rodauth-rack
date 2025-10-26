# frozen_string_literal: true

require_relative "rack/version"
require_relative "rack/adapter/base"
require_relative "rack/middleware"
require_relative "rack/generators/migration"

module Rodauth
  module Rack
    class Error < StandardError; end

    class << self
      # Get or set the default adapter class
      attr_accessor :adapter_class

      # Get or set the default account model
      attr_accessor :account_model
    end
  end
end
