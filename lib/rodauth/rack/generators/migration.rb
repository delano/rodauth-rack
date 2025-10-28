# frozen_string_literal: true

require "erb"

module Rodauth
  module Rack
    module Generators
      # Sequel migration generator for Rodauth database tables.
      #
      # Generates migrations for Sequel ORM, supporting
      # PostgreSQL, MySQL, and SQLite databases.
      #
      # @example Generate a migration
      #   generator = Rodauth::Rack::Generators::Migration.new(
      #     features: [:base, :verify_account, :otp],
      #     orm: :sequel,
      #     prefix: "account",
      #     db_adapter: :postgresql
      #   )
      #
      #   generator.generate # => migration content
      #   generator.configuration # => Rodauth config hash
      class Migration
        attr_reader :features, :orm, :prefix, :db_adapter, :db

        # Feature configuration mapping for Rodauth
        #
        # Maps feature names to their required table configurations
        CONFIGURATION = {
          base: { accounts_table: "%<plural>s" },
          remember: { remember_table: "%<singular>s_remember_keys" },
          verify_account: { verify_account_table: "%<singular>s_verification_keys" },
          verify_login_change: { verify_login_change_table: "%<singular>s_login_change_keys" },
          reset_password: { reset_password_table: "%<singular>s_password_reset_keys" },
          email_auth: { email_auth_table: "%<singular>s_email_auth_keys" },
          otp: { otp_keys_table: "%<singular>s_otp_keys" },
          otp_unlock: { otp_unlock_table: "%<singular>s_otp_unlocks" },
          sms_codes: { sms_codes_table: "%<singular>s_sms_codes" },
          recovery_codes: { recovery_codes_table: "%<singular>s_recovery_codes" },
          webauthn: {
            webauthn_keys_table: "%<singular>s_webauthn_keys",
            webauthn_user_ids_table: "%<singular>s_webauthn_user_ids",
            webauthn_keys_account_id_column: "%<singular>s_id"
          },
          lockout: {
            account_login_failures_table: "%<singular>s_login_failures",
            account_lockouts_table: "%<singular>s_lockouts"
          },
          active_sessions: {
            active_sessions_table: "%<singular>s_active_session_keys",
            active_sessions_account_id_column: "%<singular>s_id"
          },
          account_expiration: { account_activity_table: "%<singular>s_activity_times" },
          password_expiration: { password_expiration_table: "%<singular>s_password_change_times" },
          single_session: { single_session_table: "%<singular>s_session_keys" },
          audit_logging: {
            audit_logging_table: "%<singular>s_authentication_audit_logs",
            audit_logging_account_id_column: "%<singular>s_id"
          },
          disallow_password_reuse: {
            previous_password_hash_table: "%<singular>s_previous_password_hashes",
            previous_password_account_id_column: "%<singular>s_id"
          },
          jwt_refresh: {
            jwt_refresh_token_table: "%<singular>s_jwt_refresh_keys",
            jwt_refresh_token_account_id_column: "%<singular>s_id"
          }
        }.freeze

        # Initialize the migration generator
        #
        # @param features [Array<Symbol>] List of Rodauth features to generate tables for
        # @param orm [Symbol] ORM to use (only :sequel is supported)
        # @param prefix [String] Table name prefix (default: "account")
        # @param db_adapter [Symbol] Database adapter (:postgresql, :mysql2, :sqlite3)
        # @param db [Sequel::Database] Sequel database connection (for Sequel ORM only)
        def initialize(features:, orm: :sequel, prefix: nil, db_adapter: nil, db: nil)
          @features = Array(features).map(&:to_sym)
          @orm = orm.to_sym
          @prefix = prefix
          @db_adapter = db_adapter&.to_sym
          @db = db || (orm == :sequel ? create_mock_db : nil)

          validate_features!
          validate_orm!
          validate_feature_templates!
        end

        # Generate the migration content
        #
        # @return [String] Complete migration file content
        def generate
          features
            .map { |feature| load_template(feature) }
            .map { |content| evaluate_erb(content) }
            .join("\n")
        end

        # Get the Rodauth configuration for the selected features
        #
        # @return [Hash] Configuration hash with table names
        def configuration
          CONFIGURATION.values_at(*features)
                       .compact
                       .reduce({}, :merge)
                       .transform_values do |format|
            format(format, plural: table_prefix.pluralize,
                           singular: table_prefix)
          end
        end

        # Get the migration name
        #
        # @return [String] Migration name
        def migration_name
          parts = ["create_rodauth"]
          parts << prefix if prefix && prefix != "account"
          parts.concat(features)
          parts.join("_")
        end

        private

        def validate_features!
          return if features.any?

          raise ArgumentError, "No features specified"
        end

        def validate_feature_templates!
          features.each do |feature|
            template_path = File.join(template_directory, "#{feature}.erb")
            raise ArgumentError, "No migration template for feature: #{feature}" unless File.exist?(template_path)
          end
        end

        def validate_orm!
          return if orm == :sequel

          raise ArgumentError, "Only Sequel ORM is supported. Got: #{orm}"
        end

        def create_mock_db
          adapter = @db_adapter || :postgres
          MockSequelDatabase.new(adapter)
        end

        def load_template(feature)
          template_path = File.join(template_directory, "#{feature}.erb")
          File.read(template_path)
        end

        def evaluate_erb(content)
          ERB.new(content, trim_mode: "-").result(binding)
        end

        def template_directory
          File.join(__dir__, "migration", orm.to_s)
        end

        def table_prefix
          (@prefix || "account").to_s
        end

        # Methods for ERB templates

        def activerecord_adapter
          @db_adapter&.to_s || "postgresql"
        end

        def primary_key_type(key = :id)
          column_type = default_primary_key_type

          if key
            ", #{key}: :#{column_type}"
          else
            column_type
          end
        end

        def default_primary_key_type
          activerecord_adapter == "sqlite3" ? :integer : :bigint
        end

        def current_timestamp
          if activerecord_adapter =~ /mysql/ && supports_datetime_with_precision?
            "CURRENT_TIMESTAMP(6)"
          else
            "CURRENT_TIMESTAMP"
          end
        end

        def supports_datetime_with_precision?
          # This is a simplified version - actual implementation would check database version
          true
        end

        # Mock database object for Sequel templates when no real db is provided
        class MockSequelDatabase
          attr_reader :database_type

          def initialize(adapter = :postgres)
            @database_type = adapter
          end

          def supports_partial_indexes?
            %i[postgres sqlite].include?(database_type)
          end
        end
      end
    end
  end
end

# String extensions for singularize/pluralize
# Simplified implementation - in production, use ActiveSupport or similar
class String
  unless method_defined?(:pluralize)
    def pluralize
      return self if end_with?("s")

      "#{self}s"
    end
  end

  unless method_defined?(:singularize)
    def singularize
      return self unless end_with?("s")

      self[0..-2]
    end
  end
end
