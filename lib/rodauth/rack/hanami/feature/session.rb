# frozen_string_literal: true

module Rodauth
  module Rack
    module Hanami
      module Feature
        module Session
          def self.included(base)
            base.auth_methods :hanami_session, :hanami_flash
          end

          # Use Hanami's session for Rodauth.
          def session
            hanami_session
          end

          # Use Hanami's flash for Rodauth.
          def flash
            hanami_flash
          end

          private

          def hanami_session
            scope.hanami_request.session
          end

          def hanami_flash
            # Hanami 2.x uses session-based flash
            scope.hanami_request.session[:_flash] ||= {}
          end

          # Set a flash message that will be available in the next request.
          def set_notice_flash(message)
            hanami_flash[:notice] = message
          end

          def set_error_flash(message)
            hanami_flash[flash_error_key] = message
          end

          def set_notice_now_flash(message)
            hanami_flash[:notice] = message
          end

          def set_error_now_flash(message)
            hanami_flash[flash_error_key] = message
          end
        end
      end
    end
  end
end
