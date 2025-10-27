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
            # Hanami 2.x uses session-based flash with two-bucket pattern
            # :_flash holds current request messages
            # :_flash_next holds next request messages
            scope.hanami_request.session[:_flash] ||= {}
          end

          def hanami_flash_next
            scope.hanami_request.session[:_flash_next] ||= {}
          end

          # Set a flash message that will be available in the NEXT request.
          def set_notice_flash(message)
            hanami_flash_next[:notice] = message
          end

          def set_error_flash(message)
            hanami_flash_next[flash_error_key] = message
          end

          # Set a flash message that is available in the CURRENT request.
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
