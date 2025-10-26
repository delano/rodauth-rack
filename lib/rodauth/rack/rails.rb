# frozen_string_literal: true

# Rails adapter entry point
#
# Usage in Rails apps:
#   gem "rodauth-rack"
#   require "rodauth/rack/rails"
#
# Or in Gemfile:
#   gem "rodauth-rack", require: "rodauth/rack/rails"

begin
  require "rails"
rescue LoadError
  raise LoadError, "Rails is required to use rodauth-rack Rails adapter. Add 'gem \"rails\"' to your Gemfile."
end

require_relative "../rack"
require_relative "rails/module"
require_relative "rails/railtie"
