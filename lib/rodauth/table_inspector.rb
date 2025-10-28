# frozen_string_literal: true

module Rodauth
  # TableInspector dynamically discovers database tables required by enabled Rodauth features.
  #
  # Unlike the old static CONFIGURATION approach, this module inspects a Rodauth instance
  # at runtime to discover which tables are needed based on the features that have been enabled.
  #
  # @example Discover tables from a Rodauth instance
  #   tables = Rodauth::TableInspector.discover_tables(rodauth_instance)
  #   # => { accounts_table: "accounts", otp_keys_table: "account_otp_keys", ... }
  #
  # @example Get detailed table information
  #   info = Rodauth::TableInspector.table_information(rodauth_instance)
  #   # => {
  #   #   accounts_table: {
  #   #     name: "accounts",
  #   #     feature: :base,
  #   #     columns: [:id, :email, :password_hash, ...]
  #   #   },
  #   #   ...
  #   # }
  module TableInspector
    # Discover all table configuration methods and their values from a Rodauth instance
    #
    # @param rodauth_instance [Rodauth::Auth] A Rodauth auth instance
    # @return [Hash<Symbol, String>] Map of method names to table names
    def self.discover_tables(rodauth_instance)
      table_methods = rodauth_instance.methods.select { |m| m.to_s.end_with?("_table") }

      tables = {}
      table_methods.each do |method|
        begin
          table_name = rodauth_instance.send(method)
          tables[method] = table_name if table_name.is_a?(String) || table_name.is_a?(Symbol)
        rescue StandardError => e
          # Some table methods might fail if called without proper context
          warn "TableInspector: Unable to call #{method}: #{e.message}" if ENV['RODAUTH_DEBUG']
        end
      end

      tables
    end

    # Build detailed table information including inferred structure
    #
    # @param rodauth_instance [Rodauth::Auth] A Rodauth auth instance
    # @return [Hash<Symbol, Hash>] Detailed information about each table
    def self.table_information(rodauth_instance)
      discovered = discover_tables(rodauth_instance)

      discovered.transform_values do |table_name|
        {
          name: table_name,
          feature: infer_feature_from_method(discovered.key(table_name)),
          structure: infer_table_structure(discovered.key(table_name), table_name)
        }
      end
    end

    # Infer which feature owns a table based on the method name
    #
    # @param method_name [Symbol] The table method name (e.g., :otp_keys_table)
    # @return [Symbol] The feature name (e.g., :otp)
    def self.infer_feature_from_method(method_name)
      method_str = method_name.to_s

      # Special case for base feature
      return :base if method_str == "accounts_table"

      # Remove _table suffix
      feature_name = method_str.sub(/_table$/, "")

      # Handle compound names - try to match known patterns
      # e.g., "otp_keys" -> "otp", "account_login_failures" -> "lockout"
      FEATURE_MAPPINGS[feature_name.to_sym] || feature_name.to_sym
    end

    # Infer the structure of a table based on patterns
    #
    # This provides metadata about what columns the table should have.
    # In the future, this can be enhanced by inspecting column-related methods
    # on the Rodauth instance.
    #
    # @param method_name [Symbol] The table method name
    # @param table_name [String, Symbol] The actual table name
    # @return [Hash] Table structure metadata
    def self.infer_table_structure(method_name, table_name)
      method_str = method_name.to_s

      case method_str
      when "accounts_table"
        {
          primary_key: :id,
          columns: [:id, :email, :status_id],
          indexes: [[:email]],
          type: :primary
        }
      when /_table$/
        feature = method_str.sub(/_table$/, "").to_sym
        structure_for_feature(feature, table_name)
      else
        { columns: [], type: :unknown }
      end
    end

    # Map table method names to their owning features
    # This handles cases where the method name doesn't directly match the feature name
    FEATURE_MAPPINGS = {
      otp_keys: :otp,
      otp_unlock: :otp_unlock,
      remember: :remember,
      verify_account: :verify_account,
      verify_login_change: :verify_login_change,
      reset_password: :reset_password,
      email_auth: :email_auth,
      sms_codes: :sms_codes,
      recovery_codes: :recovery_codes,
      webauthn_keys: :webauthn,
      webauthn_user_ids: :webauthn,
      account_login_failures: :lockout,
      account_lockouts: :lockout,
      active_sessions: :active_sessions,
      account_activity: :account_expiration,
      password_expiration: :password_expiration,
      single_session: :single_session,
      audit_logging: :audit_logging,
      previous_password_hash: :disallow_password_reuse,
      jwt_refresh_token: :jwt_refresh
    }.freeze

    # Define table structure for each known feature
    #
    # @param feature [Symbol] Feature name
    # @param table_name [String, Symbol] Table name
    # @return [Hash] Structure metadata
    def self.structure_for_feature(feature, table_name)
      case feature
      when :otp_keys, :otp
        {
          primary_key: :id,
          columns: [:id, :account_id, :key, :num_failures, :last_use],
          foreign_keys: [[:account_id, :accounts, :id]],
          indexes: [[:account_id]],
          type: :feature
        }
      when :remember
        {
          primary_key: :id,
          columns: [:id, :account_id, :key, :deadline],
          foreign_keys: [[:account_id, :accounts, :id]],
          indexes: [[:account_id], [:key]],
          type: :feature
        }
      when :verify_account
        {
          primary_key: :id,
          columns: [:id, :account_id, :key, :requested_at, :email],
          foreign_keys: [[:account_id, :accounts, :id]],
          indexes: [[:account_id], [:key]],
          type: :feature
        }
      when :verify_login_change
        {
          primary_key: :id,
          columns: [:id, :account_id, :key, :login, :requested_at],
          foreign_keys: [[:account_id, :accounts, :id]],
          indexes: [[:account_id], [:key]],
          type: :feature
        }
      when :reset_password
        {
          primary_key: :id,
          columns: [:id, :account_id, :key, :deadline, :email],
          foreign_keys: [[:account_id, :accounts, :id]],
          indexes: [[:account_id], [:key]],
          type: :feature
        }
      when :email_auth
        {
          primary_key: :id,
          columns: [:id, :account_id, :key, :deadline, :email],
          foreign_keys: [[:account_id, :accounts, :id]],
          indexes: [[:account_id], [:key]],
          type: :feature
        }
      when :sms_codes
        {
          primary_key: :id,
          columns: [:id, :account_id, :phone_number, :code, :code_issued_at, :num_failures],
          foreign_keys: [[:account_id, :accounts, :id]],
          indexes: [[:account_id], [:phone_number]],
          type: :feature
        }
      when :recovery_codes
        {
          primary_key: :id,
          columns: [:id, :account_id, :code],
          foreign_keys: [[:account_id, :accounts, :id]],
          indexes: [[:account_id], [:code]],
          type: :feature
        }
      when :webauthn_keys, :webauthn
        {
          primary_key: :id,
          columns: [:id, :account_id, :webauthn_id, :public_key, :sign_count, :last_use],
          foreign_keys: [[:account_id, :accounts, :id]],
          indexes: [[:account_id], [:webauthn_id]],
          type: :feature
        }
      when :webauthn_user_ids
        {
          primary_key: :id,
          columns: [:id, :account_id, :webauthn_id],
          foreign_keys: [[:account_id, :accounts, :id]],
          indexes: [[:account_id], [:webauthn_id]],
          type: :feature
        }
      when :account_login_failures
        {
          primary_key: :id,
          columns: [:id, :account_id, :number],
          foreign_keys: [[:account_id, :accounts, :id]],
          indexes: [[:account_id]],
          type: :feature
        }
      when :account_lockouts
        {
          primary_key: :id,
          columns: [:id, :account_id, :deadline, :email_last_sent],
          foreign_keys: [[:account_id, :accounts, :id]],
          indexes: [[:account_id]],
          type: :feature
        }
      when :active_sessions
        {
          primary_key: :id,
          columns: [:id, :account_id, :session_id, :created_at, :last_activity_at],
          foreign_keys: [[:account_id, :accounts, :id]],
          indexes: [[:account_id], [:session_id]],
          type: :feature
        }
      when :account_activity
        {
          primary_key: :id,
          columns: [:id, :account_id, :last_activity_at, :last_login_at, :expired_at],
          foreign_keys: [[:account_id, :accounts, :id]],
          indexes: [[:account_id]],
          type: :feature
        }
      when :password_expiration
        {
          primary_key: :id,
          columns: [:id, :account_id, :changed_at],
          foreign_keys: [[:account_id, :accounts, :id]],
          indexes: [[:account_id]],
          type: :feature
        }
      when :single_session
        {
          primary_key: :id,
          columns: [:id, :account_id, :key],
          foreign_keys: [[:account_id, :accounts, :id]],
          indexes: [[:account_id], [:key]],
          type: :feature
        }
      when :audit_logging
        {
          primary_key: :id,
          columns: [:id, :account_id, :at, :message, :metadata],
          foreign_keys: [[:account_id, :accounts, :id]],
          indexes: [[:account_id], [:at]],
          type: :feature
        }
      when :previous_password_hash
        {
          primary_key: :id,
          columns: [:id, :account_id, :password_hash],
          foreign_keys: [[:account_id, :accounts, :id]],
          indexes: [[:account_id]],
          type: :feature
        }
      when :jwt_refresh_token
        {
          primary_key: :id,
          columns: [:id, :account_id, :key, :deadline],
          foreign_keys: [[:account_id, :accounts, :id]],
          indexes: [[:account_id], [:key]],
          type: :feature
        }
      else
        # Default structure for unknown features
        {
          primary_key: :id,
          columns: [:id, :account_id, :key, :created_at],
          foreign_keys: [[:account_id, :accounts, :id]],
          indexes: [[:account_id]],
          type: :unknown
        }
      end
    end

    private_class_method :structure_for_feature
  end
end
