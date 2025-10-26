# frozen_string_literal: true

module Rodauth
  module Rack
    module Rails
      # Rails-specific adapter implementation
      #
      # Implements all required methods from Rodauth::Rack::Adapter::Base
      # for Rails integration.
      #
      # @example
      #   # Automatically used in Rails apps via Railtie
      #   # No manual configuration needed
      class Adapter < Rodauth::Rack::Adapter::Base
        # ====================
        # View Rendering
        # ====================

        def render(template, locals = {})
          # TODO: Implement Rails view rendering
          # Try user template first, fall back to Rodauth built-in
          raise NotImplementedError, "Rails adapter rendering not yet implemented"
        end

        def view_path
          # TODO: Return Rails view path
          "app/views/rodauth"
        end

        # ====================
        # CSRF Protection
        # ====================

        def csrf_token
          # TODO: Delegate to Rails CSRF token
          rails_controller_instance.send(:form_authenticity_token)
        end

        def csrf_field
          # TODO: Return Rails CSRF field name
          ::Rails.application.config.action_controller.request_forgery_protection_token.to_s
        end

        def valid_csrf_token?(token)
          # TODO: Delegate to Rails CSRF validation
          rails_controller_instance.send(:valid_authenticity_token?, session, token)
        end

        # ====================
        # Flash Messages
        # ====================

        def flash
          request.env["action_dispatch.request.flash_hash"] ||= ::ActionDispatch::Flash::FlashHash.new
        end

        # ====================
        # URL Generation
        # ====================

        def url_for(path, **options)
          # TODO: Use Rails URL helpers
          "#{request.base_url}#{path}"
        end

        # ====================
        # Email Delivery
        # ====================

        def deliver_email(mailer, *args)
          # TODO: Integrate with ActionMailer
          raise NotImplementedError, "Rails adapter email delivery not yet implemented"
        end

        # ====================
        # Model Integration
        # ====================

        def account_model
          # TODO: Auto-detect or allow configuration
          # Infer from table name: accounts -> Account
          raise NotImplementedError, "Rails adapter account model not yet implemented"
        end

        # ====================
        # Configuration
        # ====================

        def rodauth_config
          # TODO: Return Rodauth configuration
          {}
        end

        def db
          # TODO: Return Sequel database connection
          # Uses sequel-activerecord_connection gem
          raise NotImplementedError, "Rails adapter database connection not yet implemented"
        end

        private

        def rails_controller_instance
          @rails_controller_instance ||= create_rails_controller_instance
        end

        def create_rails_controller_instance
          # TODO: Create ActionController instance with request/response
          controller = ::ActionController::Base.new
          controller.set_request!(request)
          controller.set_response!(::ActionController::Base.make_response!(request))
          controller
        end
      end
    end
  end
end
