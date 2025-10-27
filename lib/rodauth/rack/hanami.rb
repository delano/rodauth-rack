# frozen_string_literal: true

# Hanami adapter entry point
#
# Usage in Hanami apps:
#   gem "rodauth-rack"
#   require "rodauth/rack/hanami"
#
# Or in Gemfile:
#   gem "rodauth-rack", require: "rodauth/rack/hanami"

begin
  require "hanami"
rescue LoadError
  raise LoadError, "Hanami is required to use rodauth-rack Hanami adapter. Add 'gem \"hanami\"' to your Gemfile."
end

require_relative "../rack"
require_relative "hanami/module"
require_relative "hanami/provider"

# Compatibility alias for cleaner generated code
module Rodauth
  Hanami = Rack::Hanami unless defined?(::Rodauth::Hanami)
end
