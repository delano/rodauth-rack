# frozen_string_literal: true

require "roda"
require "rodauth/rack/hanami/auth"

module Rodauth
  module Rack
    module Hanami
      # The superclass for creating a Rodauth middleware.
      class App < Roda
        plugin :middleware, forward_response_headers: true, next_if_not_found: true
        plugin :hooks
        plugin :pass

        def self.configure(*args, render: Rodauth::Rack::Hanami.tilt?, **, &)
          auth_class = args.shift if args[0].is_a?(Class)
          auth_class ||= Class.new(Rodauth::Rack::Hanami::Auth)
          name = args.shift if args[0].is_a?(Symbol)

          if args.any?
            raise ArgumentError,
                  "need to pass optional Rodauth::Auth subclass and optional configuration name"
          end

          # we'll render Rodauth's built-in view templates within Hanami layouts
          plugin :render, layout: false unless render == false

          plugin(:rodauth,
                 auth_class: auth_class, name: name, csrf: false, flash: false, json: true, render: render, **, &)

          # we need to do it after request methods from rodauth have been included
          self::RodaRequest.include RequestMethods
        end

        before do
          opts[:rodauths]&.each_key do |name|
            env[["rodauth", *name].join(".")] = rodauth(name)
          end
        end

        after do
          # Rotate flash messages from :_flash_next to :_flash
          session_obj = hanami_request.session
          if session_obj[:_flash_next]
            session_obj[:_flash] = session_obj.delete(:_flash_next)
          else
            session_obj.delete(:_flash)
          end

          # Finalize session if needed (Hanami auto-commits via middleware)
          session_obj.finalize if session_obj.respond_to?(:finalize)
        end

        # Delegate session to hanami_request
        def session
          hanami_request.session
        end

        def hanami_app
          ::Hanami.app
        end

        def hanami_request
          @hanami_request ||= ::Hanami::Action::Request.new(env)
        end

        def hanami_response
          @hanami_response ||= ::Hanami::Action::Response.new
        end

        def self.rodauth!(name)
          rodauth(name) or raise Rodauth::Rack::Hanami::Error, "unknown rodauth configuration: #{name.inspect}"
        end

        module RequestMethods
          # Automatically route the prefix if it hasn't been routed already. This
          # way people only have to update prefix in their Rodauth configurations.
          def rodauth(name = nil)
            prefix = scope.rodauth(name).prefix

            if prefix.present? && remaining_path == path_info
              on prefix[1..] do
                super
                pass
              end
            else
              super
            end
          end

          # The Rack input might not be rewindable, so ensure we parse the JSON
          # request body in Hanami, and avoid parsing it again in Roda.
          def POST
            env["roda.json_params"] = scope.hanami_request.POST.to_hash if content_type =~ /json/
            super
          end

          # When calling a Rodauth method that redirects inside the Hanami
          # router, Roda's after hook that commits the session would never get
          # called, so we make sure to rotate flash and commit the session beforehand.
          def redirect(*)
            session_obj = scope.hanami_request.session

            # Rotate flash before redirect
            if session_obj[:_flash_next]
              session_obj[:_flash] = session_obj.delete(:_flash_next)
            else
              session_obj.delete(:_flash)
            end

            # Finalize session if needed
            session_obj.finalize if session_obj.respond_to?(:finalize)

            super
          end
        end
      end
    end
  end
end
