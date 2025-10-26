# frozen_string_literal: true

module Rodauth
  module Rack
    module Hanami
      module Feature
        module Base
          def self.included(base)
            base.auth_methods :hanami_action
            base.auth_value_methods :hanami_account_model
            base.auth_cached_method :hanami_action_instance
          end

          def hanami_account
            @hanami_account = nil if account.nil? || @hanami_account&.id != account_id
            @hanami_account ||= instantiate_hanami_account if account!
          end

          # Reset Hanami session to protect from session fixation attacks.
          def clear_session
            scope.hanami_request.session.clear
          end

          # Default the flash error key to :alert.
          def flash_error_key
            :alert
          end

          # Evaluates the block in context of a Rodauth action instance.
          def hanami_action_eval(&block)
            hanami_action_instance.instance_eval(&block)
          end

          def hanami_action
            ::Hanami::Action
          end

          def hanami_account_model
            table = accounts_table
            table = table.column if table.is_a?(Sequel::SQL::QualifiedIdentifier) # schema is specified

            # Try to find ROM repository or entity first
            if defined?(ROM)
              entity_name = table.to_s.singularize.camelize
              begin
                return ::Hanami.app["persistence.rom"].relations[table.to_sym].mapper.entity
              rescue
                # Fall through to Sequel
              end
            end

            # Fallback to Sequel model
            table.to_s.classify.constantize
          rescue NameError
            raise Error, "cannot infer account model, please set `hanami_account_model` in your rodauth configuration"
          end

          def session
            super
          rescue Roda::RodaError
            raise Rodauth::Rack::Hanami::Error,
                  "There is no session middleware configured"
          end

          private

          def instantiate_hanami_account
            if defined?(ROM::Struct) && hanami_account_model < ROM::Struct
              hanami_account_model.new(account.symbolize_keys)
            elsif defined?(Sequel::Model) && hanami_account_model < Sequel::Model
              hanami_account_model.load(account)
            else
              raise Error, "unsupported model type: #{hanami_account_model}"
            end
          end

          # Instance of the configured action with current request's env hash.
          def _hanami_action_instance
            action = hanami_action.new
            action.call(scope.env)
            action
          end
        end
      end
    end
  end
end
