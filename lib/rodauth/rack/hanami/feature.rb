# frozen_string_literal: true

module Rodauth
  Feature.define(:hanami) do
    # Assign feature and feature configuration to constants for introspection.
    Rodauth::Rack::Hanami::Feature              = self
    Rodauth::Rack::Hanami::FeatureConfiguration = configuration

    require "rodauth/rack/hanami/feature/base"
    require "rodauth/rack/hanami/feature/csrf"
    require "rodauth/rack/hanami/feature/render"
    require "rodauth/rack/hanami/feature/session"
    require "rodauth/rack/hanami/feature/email" if defined?(Hanami::Mailer)
    require "rodauth/rack/hanami/feature/rom" if defined?(ROM)

    include Rodauth::Rack::Hanami::Feature::Base
    include Rodauth::Rack::Hanami::Feature::Csrf
    include Rodauth::Rack::Hanami::Feature::Render
    include Rodauth::Rack::Hanami::Feature::Session
    include Rodauth::Rack::Hanami::Feature::Email if defined?(Hanami::Mailer)
    include Rodauth::Rack::Hanami::Feature::Rom if defined?(ROM)

  end
end
