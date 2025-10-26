# frozen_string_literal: true

module Rodauth
  module Rack
    module Hanami
      module Feature
        module Rom
          def self.included(base)
            base.auth_methods :rom_container, :rom_relation
          end

          # Access to the ROM container from Hanami app.
          def rom_container
            ::Hanami.app["persistence.rom"] if defined?(ROM)
          end

          # Get the ROM relation for accounts table.
          def rom_relation(table_name = accounts_table)
            return nil unless rom_container

            table_sym = table_name.to_sym
            rom_container.relations[table_sym]
          end

          # Override account loading to use ROM if available.
          def account_from_login(login)
            if rom_container && rom_relation
              relation = rom_relation
              account_data = relation.where(login_column => login).one
              account_data&.to_h
            else
              super
            end
          end

          # Override account loading by ID to use ROM if available.
          def account_from_session
            if rom_container && rom_relation && (id = session_value)
              relation = rom_relation
              account_data = relation.where(account_id_column => id).one
              account_data&.to_h
            else
              super
            end
          end

          # Create account using ROM if available.
          def create_account(account_hash)
            if rom_container && rom_relation
              relation = rom_relation
              relation.insert(account_hash)
            else
              super
            end
          end

          # Update account using ROM if available.
          def update_account(updates)
            if rom_container && rom_relation && account_id
              relation = rom_relation
              relation.where(account_id_column => account_id).update(updates)
            else
              super
            end
          end
        end
      end
    end
  end
end
