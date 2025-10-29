# frozen_string_literal: true
# lib/rodauth/features/external_identity.rb

#
# Enable with:
#   enable :external_identity
#
# Configuration (Layer 1 - Basic):
#   external_identity_column :stripe_customer_id
#   external_identity_column :redis_uuid, method_name: :redis_session_key
#   external_identity_on_conflict :warn  # :error, :warn, :skip
#   external_identity_check_columns true  # true (default), false, or :autocreate
#
# Configuration (Layer 2 - Extended Features):
#   external_identity_column :stripe_customer_id,
#     before_create_account: -> { Stripe::Customer.create(email: account[:email]).id },
#     formatter: -> (v) { v.to_s.strip.downcase },
#     validator: -> (v) { v.start_with?('cus_') },
#     verifier: -> (id) { Stripe::Customer.retrieve(id) && !customer.deleted? },
#     handshake: -> (id, token) { session[:oauth_state] == token }
#
# Usage:
#   rodauth.stripe_customer_id  # Auto-generated helper method
#   rodauth.redis_uuid          # Auto-generated helper method
#
# Introspection:
#   rodauth.external_identity_column_list              # [:stripe_customer_id, :redis_uuid]
#   rodauth.external_identity_column_config(:stripe_customer_id)  # {...}
#   rodauth.external_identity_status                   # Complete debug info
#
# Example:
#
#   plugin :rodauth do
#     enable :login, :logout, :external_identity
#
#     # Declare external identity columns
#     external_identity_column :stripe_customer_id
#     external_identity_column :redis_uuid
#
#     # Custom method name
#     external_identity_column :redis_key, method_name: :redis_session_key
#   end
#
#   # In your app
#   rodauth.stripe_customer_id   # => "cus_abc123"
#   rodauth.redis_uuid           # => "550e8400-e29b-41d4-a716-446655440000"

module Rodauth
  Feature.define(:external_identity, :ExternalIdentity) do
    # Configuration methods
    auth_value_method :external_identity_on_conflict, :error
    auth_value_method :external_identity_check_columns, true

    # Public API methods for introspection
    auth_methods(
      :external_identity_column_list,
      :external_identity_column_config,
      :external_identity_helper_methods,
      :external_identity_column?,
      :external_identity_status
    )

    # Layer 2: Validation methods
    auth_methods(
      :validate_external_identity,
      :validate_all_external_identities
    )

    # Use auth_cached_method for column configuration
    # This ensures it works in both post_configure and runtime
    auth_cached_method :external_identity_columns_config

    # Add external_identity_column method to Configuration class
    # This makes it available during the configuration block
    configuration_module_eval do
      def external_identity_column(column, **options)
        # Validate column is a symbol
        unless column.is_a?(Symbol)
          raise ArgumentError, "external_identity_column must be a Symbol, got #{column.class}"
        end

        # Validate column is a valid Ruby identifier
        unless column.to_s =~ /^[a-z_][a-z0-9_]*$/i
          raise ArgumentError, "external_identity_column must be a valid Ruby identifier: #{column}"
        end

        # Default method name is the column name itself
        method_name = options[:method_name] || column

        # Validate method name is valid Ruby identifier
        unless method_name.to_s =~ /^[a-z_][a-z0-9_]*[?!=]?$/i
          raise ArgumentError, "Method name must be a valid Ruby identifier: #{method_name}"
        end

        # Store configuration on the Auth class
        # Use class instance variable to store per-class configuration
        @auth.instance_variable_set(:@_external_identity_columns, {}) unless @auth.instance_variable_get(:@_external_identity_columns)
        columns = @auth.instance_variable_get(:@_external_identity_columns)

        # Check for duplicate declarations using column name as key
        if columns.key?(column)
          raise ArgumentError, "external_identity_column :#{column} already declared"
        end

        # Store configuration (using column as both key and value)
        columns[column] = {
          column: column,
          method_name: method_name,
          include_in_select: options.fetch(:include_in_select, true),
          validate: options[:validate] || false,
          # Layer 2: Lifecycle callbacks
          before_create_account: options[:before_create_account],
          formatter: options[:formatter],
          validator: options[:validator],
          verifier: options[:verifier],
          handshake: options[:handshake],
          options: options
        }

        # Define the helper method on the Auth class
        @auth.send(:define_method, method_name) do
          value = account ? account[column] : nil

          # Apply formatter if present (Layer 2)
          config = external_identity_columns_config[column]
          if config && config[:formatter] && value
            instance_exec(value, &config[:formatter])
          else
            value
          end
        end

        nil
      end
    end

    # Note: external_identity_column is defined in configuration_module_eval above
    # It's available during configuration but not as an instance method

    # Override account_select to automatically include declared columns
    #
    # Ensures external identity columns are fetched with the account
    # unless explicitly disabled via include_in_select: false
    def account_select

      # Call defined?(super) safely wraps the super call
      cols = if defined?(super)
               super
             else
               [:id]  # Default if no parent implementation
             end

      # Normalize to array
      cols = case cols
             when Array then cols.dup
             when nil then []
             else [cols]
             end

      # Add external identity columns (idempotent via include? check)
      external_identity_columns_config.each do |_name, config|
        if config[:include_in_select]
          cols << config[:column] unless cols.include?(config[:column])
        end
      end

      cols
    end

    # Get list of all declared external identity column names
    #
    # @return [Array<Symbol>] List of column names
    #
    # @example
    #   external_identity_column_list  # => [:stripe_customer_id, :redis_uuid]
    def external_identity_column_list
      external_identity_columns_config.keys
    end

    # Get configuration for a specific external identity column
    #
    # @param column [Symbol] Column name
    # @return [Hash, nil] Configuration hash or nil if not found
    #
    # @example
    #   external_identity_column_config(:stripe_customer_id)
    #   # => {column: :stripe_customer_id, method_name: :stripe_customer_id, ...}
    def external_identity_column_config(column)
      external_identity_columns_config[column]
    end

    # Get list of all generated helper method names
    #
    # @return [Array<Symbol>] List of method names
    #
    # @example
    #   external_identity_helper_methods  # => [:stripe_customer_id, :redis_uuid]
    def external_identity_helper_methods
      external_identity_columns_config.values.map { |config| config[:method_name] }
    end

    # Check if a column has been declared as an external identity
    #
    # @param column [Symbol] Column name
    # @return [Boolean] True if declared
    #
    # @example
    #   external_identity_column?(:stripe_customer_id)  # => true
    #   external_identity_column?(:redis_uuid)          # => true
    #   external_identity_column?(:unknown)             # => false
    def external_identity_column?(column)
      external_identity_columns_config.key?(column)
    end

    # Get complete status information for all declared external identities
    #
    # Useful for debugging and introspection. Shows configuration,
    # current values, and validation status.
    #
    # @return [Array<Hash>] Array of status hashes
    #
    # @example
    #   external_identity_status
    #   # => [
    #   #   {
    #   #     column: :stripe_customer_id,
    #   #     method: :stripe_customer_id,
    #   #     value: "cus_abc123",
    #   #     present: true,
    #   #     in_select: true,
    #   #     in_account: true,
    #   #     column_exists: true
    #   #   },
    #   #   ...
    #   # ]
    def external_identity_status
      current_select = account_select

      external_identity_columns_config.map do |column, config|
        method_name = config[:method_name]

        # Safely get the value
        value = begin
                  account ? account[column] : nil
                rescue StandardError
                  nil
                end

        # Check if column exists in database
        column_exists = begin
                          db.schema(accounts_table).any? { |col| col[0] == column }
                        rescue StandardError
                          nil  # Unknown if can't check
                        end

        {
          column: column,
          method: method_name,
          value: value,
          present: !value.nil?,
          in_select: current_select.include?(column),
          in_account: account&.key?(column) || false,
          column_exists: column_exists
        }
      end
    end

    # Validate a specific external identity column value
    #
    # Applies formatter (if configured) then validator (if configured).
    # Returns true if valid or no validator configured.
    # Raises ArgumentError if validation fails.
    #
    # @param column [Symbol] Column name
    # @param value [Object] Value to validate
    # @return [Boolean] True if valid
    # @raise [ArgumentError] If validation fails
    #
    # @example
    #   validate_external_identity(:stripe_customer_id, "cus_123")  # => true
    #   validate_external_identity(:stripe_customer_id, "invalid") # => ArgumentError
    def validate_external_identity(column, value)
      config = external_identity_columns_config[column]
      return true unless config
      return true if value.nil? # nil values are not validated

      # Apply formatter if present
      formatted_value = if config[:formatter]
                          instance_exec(value, &config[:formatter])
                        else
                          value
                        end

      # Apply validator if present
      if config[:validator]
        is_valid = instance_exec(formatted_value, &config[:validator])
        unless is_valid
          raise ArgumentError, "Invalid format for #{column}: #{value.inspect}"
        end
      end

      true
    end

    # Validate all configured external identity columns
    #
    # Checks all columns that have validators configured.
    # Returns hash of column => validation result.
    #
    # @return [Hash<Symbol, Boolean>] Results per column
    #
    # @example
    #   validate_all_external_identities
    #   # => {stripe_customer_id: true, redis_uuid: true}
    def validate_all_external_identities
      results = {}
      external_identity_columns_config.each do |column, config|
        next unless config[:validator]

        value = account ? account[column] : nil
        next if value.nil? # Skip nil values

        begin
          validate_external_identity(column, value)
          results[column] = true
        rescue ArgumentError => e
          results[column] = false
          # Re-raise to fail the operation
          raise e
        end
      end
      results
    end

    # Generate external identities during account creation
    #
    # Runs in before_create_account hook. For each column with
    # before_create_account callback configured:
    # - Skip if value already set (manual override)
    # - Execute callback to generate value
    # - Apply formatter if configured
    # - Apply validator if configured
    # - Set account column
    #
    # Errors during generation will prevent account creation.
    def before_create_account
      super if defined?(super)
      generate_external_identities
    end

    # Validation hook - runs after configuration is complete
    #
    # Validates configuration and provides helpful warnings/errors
    def post_configure
      super if defined?(super)

      # Check columns based on configuration
      case external_identity_check_columns
      when true
        # Check existence and raise if missing
        check_columns_exist!
      when :autocreate
        # Check existence and inform table_guard if missing
        check_and_autocreate_columns!
      when false
        # Skip checking entirely
      else
        raise ArgumentError, "external_identity_check_columns must be true, false, or :autocreate, got: #{external_identity_check_columns.inspect}"
      end

      # Always check that columns are included in account_select if they should be
      validate_account_select_inclusion!
    end

    private

    # Generate external identities for columns with before_create_account callbacks
    #
    # Called during before_create_account hook
    def generate_external_identities
      external_identity_columns_config.each do |column, config|
        next unless config[:before_create_account]

        # Skip if value already set (manual override)
        next if account[column]

        # Execute generator callback
        generated_value = instance_exec(&config[:before_create_account])

        # Skip if generator returned nil (intentionally not setting)
        next if generated_value.nil?

        # Apply formatter if configured
        value = if config[:formatter]
                  instance_exec(generated_value, &config[:formatter])
                else
                  generated_value
                end

        # Apply validator if configured
        if config[:validator]
          is_valid = instance_exec(value, &config[:validator])
          unless is_valid
            raise ArgumentError, "Generated value for #{column} failed validation: #{value.inspect}"
          end
        end

        # Set the account column
        account[column] = value
      end
    end

    # Internal method called by auth_cached_method
    #
    # Retrieves the storage hash for external identity configurations from the Auth class
    # This is called lazily per-instance and cached
    #
    # @return [Hash] Configuration hash from the Auth class
    def _external_identity_columns_config
      # Get from class instance variable set during configuration
      self.class.instance_variable_get(:@_external_identity_columns) || {}
    end

    # Check that declared columns exist in the database
    #
    # Runs when external_identity_check_columns is true
    #
    # @raise [ArgumentError] If columns are missing
    def check_columns_exist!
      missing = find_missing_columns
      return if missing.empty?

      column_list = missing.map { |col| ":#{col}" }.join(', ')
      raise ArgumentError, "External identity columns not found in #{accounts_table} table: #{column_list}. " \
                           "Add columns to database, set external_identity_check_columns to false, or use :autocreate mode."
    end

    # Check columns and inform table_guard if any are missing
    #
    # Runs when external_identity_check_columns is :autocreate
    def check_and_autocreate_columns!
      missing = find_missing_columns
      return if missing.empty?

      # If table_guard is enabled, inform it about missing columns
      if respond_to?(:table_guard_mode)
        # Register missing external identity columns with table_guard
        register_external_columns_with_table_guard(missing)
      else
        # No table_guard available - provide helpful error with migration code
        raise ArgumentError, build_missing_columns_error(missing)
      end
    end

    # Find columns that don't exist in the database
    #
    # @return [Array<Symbol>] Array of missing column names
    def find_missing_columns
      return [] unless db  # Skip if no database available

      schema = begin
                 db.schema(accounts_table)
               rescue StandardError
                 # Can't check - database might not exist yet
                 return []
               end

      column_names = schema.map { |col| col[0] }

      missing = []
      external_identity_columns_config.each do |column, _config|
        missing << column unless column_names.include?(column)
      end

      missing
    end

    # Register missing external identity columns with table_guard
    #
    # @param missing [Array<Symbol>] Array of missing column names
    def register_external_columns_with_table_guard(missing)
      # Add missing columns to table_guard's configuration
      # This allows table_guard to generate migrations or create columns
      # based on its sequel_mode setting

      missing.each do |column|
        # Determine column type - default to String for external IDs
        # TODO: Could make this configurable per column in future
        column_def = {
          name: column,
          type: :String,
          null: true,  # External IDs are optional
          feature: :external_identity
        }

        # If table_guard has a method to register additional columns, use it
        # Otherwise, we'll need to ensure table_guard can discover these
        if respond_to?(:register_required_column, true)
          register_required_column(accounts_table, column_def)
        end
      end

      # Trigger table_guard's validation which will handle creation/logging
      # based on table_guard_mode and table_guard_sequel_mode
      if respond_to?(:check_required_tables!, true)
        # Let table_guard know we need to check again
        # This will cause it to generate ALTER TABLE statements if in :create mode
      end
    end

    # Build error message for missing columns with migration example
    #
    # @param missing [Array<Symbol>] Array of missing column names
    # @return [String] Error message with migration code
    def build_missing_columns_error(missing)
      column_list = missing.map { |col| ":#{col}" }.join(', ')

      migration_code = generate_migration_code(missing)

      <<~ERROR
        External identity columns not found in #{accounts_table} table: #{column_list}

        With external_identity_check_columns set to :autocreate but table_guard not enabled.

        Either:
        1. Enable table_guard feature with sequel_mode to auto-create
        2. Create migration manually:

        #{migration_code}

        3. Set external_identity_check_columns to false to skip checking
      ERROR
    end

    # Generate migration code for missing columns
    #
    # @param missing [Array<Symbol>] Array of missing column names
    # @return [String] Sequel migration code
    def generate_migration_code(missing)
      lines = ["Sequel.migration do", "  up do", "    alter_table :#{accounts_table} do"]

      missing.each do |column|
        lines << "      add_column :#{column}, String"
      end

      lines += ["    end", "  end", "", "  down do", "    alter_table :#{accounts_table} do"]

      missing.each do |column|
        lines << "      drop_column :#{column}"
      end

      lines += ["    end", "  end", "end"]

      lines.join("\n")
    end

    # Validate that columns are included in account_select if they should be
    #
    # Provides helpful warnings if configuration might not work as expected
    def validate_account_select_inclusion!
      current_select = account_select

      missing = []
      external_identity_columns_config.each do |column, config|
        if config[:include_in_select] && !current_select.include?(column)
          missing << ":#{column}"
        end
      end

      return if missing.empty?

      warn "[external_identity] WARNING: Columns #{missing.join(', ')} marked for inclusion " \
           "but not in account_select. This may indicate a configuration order issue. " \
           "The feature should have added them automatically."
    end
  end
end
