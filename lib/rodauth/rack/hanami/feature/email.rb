# frozen_string_literal: true

module Rodauth
  module Rack
    module Hanami
      module Feature
        module Email
          def self.included(base)
            base.depends :email_base if base.respond_to?(:depends)
          end

          private

          # Create emails with Hanami mailer which uses configured delivery method.
          def create_email_to(to, subject, body)
            # Hanami mailer integration
            # This assumes a mailer class exists in the Hanami app
            if defined?(::Hanami::Mailer)
              mailer_class = find_rodauth_mailer
              if mailer_class
                mailer_class.new(
                  to: to,
                  from: email_from,
                  subject: "#{email_subject_prefix}#{subject}",
                  body: body
                )
              else
                # Fallback to basic Mail gem
                require "mail"
                Mail.new do
                  from email_from
                  to to
                  subject "#{email_subject_prefix}#{subject}"
                  body body
                end
              end
            else
              # Use Mail gem directly if Hanami::Mailer is not available
              require "mail"
              Mail.new do
                from email_from
                to to
                subject "#{email_subject_prefix}#{subject}"
                body body
              end
            end
          end

          # Delivers the given email.
          def send_email(email)
            if email.respond_to?(:deliver)
              email.deliver
            elsif email.respond_to?(:deliver_now)
              email.deliver_now
            else
              raise Rodauth::Rack::Hanami::Error, "Email object does not respond to :deliver or :deliver_now"
            end
          end

          # Try to find a Rodauth-specific mailer in the Hanami app.
          def find_rodauth_mailer
            # This should be customized per-app
            "Mailers::Rodauth".safe_constantize rescue nil
          end
        end
      end
    end
  end
end
