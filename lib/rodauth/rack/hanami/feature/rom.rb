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
              account_struct = relation.where(login_column => login).one
              return nil unless account_struct

              # Convert ROM::Struct to Hash with symbolized keys
              convert_rom_struct_to_hash(account_struct)
            else
              super
            end
          end

          # Override account loading by ID to use ROM if available.
          def account_from_session
            if rom_container && rom_relation && (id = session_value)
              relation = rom_relation
              account_struct = relation.where(account_id_column => id).one
              return nil unless account_struct

              # Convert ROM::Struct to Hash with symbolized keys
              convert_rom_struct_to_hash(account_struct)
            else
              super
            end
          end

          # Create account using ROM if available.
          def create_account(account_hash)
            if rom_container && rom_relation
              relation = rom_relation
              result = relation.insert(account_hash)

              # Return the inserted account (with generated ID)
              # ROM insert returns the primary key or changeset result
              account_id_value = result.is_a?(Hash) ? result[account_id_column] : result
              return nil unless account_id_value

              account_struct = relation.where(account_id_column => account_id_value).one
              convert_rom_struct_to_hash(account_struct)
            else
              super
            end
          end

          # Update account using ROM if available.
          def update_account(updates)
            if rom_container && rom_relation && account_id
              relation = rom_relation
              relation.where(account_id_column => account_id).update(updates)

              # Fetch and return updated account
              updated_struct = relation.where(account_id_column => account_id).one
              convert_rom_struct_to_hash(updated_struct)
            else
              super
            end
          end

          private

          # Convert ROM::Struct to Hash with symbolized keys
          def convert_rom_struct_to_hash(rom_struct)
            return nil unless rom_struct

            if rom_struct.respond_to?(:to_h)
              rom_struct.to_h.transform_keys(&:to_sym)
            else
              # Fallback for ROM structs without to_h
              rom_struct.attributes.transform_keys(&:to_sym)
            end
          end
        end
      end
    end
  end
end
