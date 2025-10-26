# frozen_string_literal: true

module Rodauth
  module Rack
    module Hanami
      module Feature
        module Csrf
          def self.included(base)
            base.auth_methods(
              :hanami_csrf_tag,
              :hanami_csrf_param,
              :hanami_csrf_token,
              :hanami_check_csrf!
            )
          end

          # Render Hanami CSRF tags in Rodauth templates.
          def csrf_tag(*)
            hanami_csrf_tag if hanami_csrf_enabled?
          end

          # Verify Hanami's CSRF token.
          def check_csrf
            hanami_check_csrf! if hanami_csrf_enabled?
          end

          # Have Rodauth call #check_csrf automatically.
          def check_csrf?
            hanami_check_csrf? if hanami_csrf_enabled?
          end

          private

          # Checks whether CSRF protection is enabled in Hanami.
          def hanami_check_csrf?
            hanami_csrf_enabled?
          end

          # Calls Hanami to verify the CSRF token.
          def hanami_check_csrf!
            return unless hanami_csrf_enabled?
            return if only_json?  # Disable CSRF for JSON-only APIs

            expected_token = scope.hanami_request.session[:_csrf_token]
            return unless expected_token # No token in session yet

            # Check both param and header (for JSON APIs)
            token = scope.hanami_request.params[hanami_csrf_param] ||
                    scope.hanami_request.get_header("HTTP_X_CSRF_TOKEN")

            # Timing-safe comparison to prevent timing attacks
            unless ::Rack::Utils.secure_compare(expected_token, token || "")
              raise Rodauth::Rack::Hanami::Error, "CSRF token verification failed"
            end
          end

          # Hidden tag with Hanami CSRF token inserted into Rodauth templates.
          def hanami_csrf_tag
            %(<input type="hidden" name="#{hanami_csrf_param}" value="#{hanami_csrf_token}">)
          end

          # The request parameter under which to send the Hanami CSRF token.
          def hanami_csrf_param
            "_csrf_token"
          end

          # The Hanami CSRF token value inserted into Rodauth templates.
          def hanami_csrf_token
            scope.hanami_request.session[:_csrf_token] ||= SecureRandom.base64(32)
          end

          # Checks whether CSRF protection is enabled in Hanami.
          def hanami_csrf_enabled?
            # Hanami has CSRF protection built-in
            # Check if it's enabled in the configuration
            ::Hanami.app.config.actions.csrf_protection rescue false
          end
        end
      end
    end
  end
end
