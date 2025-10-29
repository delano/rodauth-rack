# frozen_string_literal: true
# lib/rodauth/features/external_identity.rb

#
# Enable with:
#   enable :external_identity
#
# Configuration:
#   external_identity_column :stripe, :stripe_customer_id
#   external_identity_column :redis, method_name: :redis_identifier
#   external_identity_on_conflict :warn  # :error, :warn, :skip, :override
#
# Usage:
#   rodauth.account_stripe_id    # Auto-generated helper method
#   rodauth.account_redis_id     # Auto-generated helper method
#
# Introspection:
#   rodauth.external_identity_column_list       # [:stripe, :redis]
#   rodauth.external_identity_column_config(:stripe)  # {...}
#   rodauth.external_identity_status            # Complete debug info
#
# Example:
#
#   plugin :rodauth do
#     enable :login, :logout, :external_identity
#
#     # Declare external identity columns
#     external_identity_column :stripe, :stripe_customer_id
#     external_identity_column :redis, :redis_uuid
#
#     # Override conflict resolution per-column
#     external_identity_column :custom, :custom_id, override: true
#   end
#
#   # In your app
#   rodauth.account_stripe_id   # => "cus_abc123"
#   rodauth.account_redis_id    # => "550e8400-e29b-41d4-a716-446655440000"

module Rodauth
  Feature.define(:external_identity, :ExternalIdentity) do
    # Configuration methods
    auth_value_method :external_identity_on_conflict, :error
    auth_value_method :external_identity_validate_columns, false

    # Public API methods for introspection
    auth_methods(
      :external_identity_column_list,
      :external_identity_column_config,
      :external_identity_helper_methods,
      :external_identity_column?,
      :external_identity_status
    )

    # Use auth_cached_method for column configuration
    # This ensures it works in both post_configure and runtime
    auth_cached_method :external_identity_columns_config

    # Add external_identity_column method to Configuration class
    # This makes it available during the configuration block
    configuration_module_eval do
      def external_identity_column(name, column = nil, **options)
        # Define the method on the Auth class
        # @auth is the Auth class, not an instance

        # Validate name is a symbol
        unless name.is_a?(Symbol)
          raise ArgumentError, "external_identity_column name must be a Symbol, got #{name.class}"
        end

        # Validate name is a valid Ruby identifier
        unless name.to_s =~ /^[a-z_][a-z0-9_]*$/i
          raise ArgumentError, "external_identity_column name must be a valid Ruby identifier: #{name}"
        end

        # Default column name to :#{name}_id
        column ||= :"#{name}_id"

        # Default method name to :account_#{name}_id
        method_name = options[:method_name] || :"account_#{name}_id"

        # Validate method name is valid Ruby identifier
        unless method_name.to_s =~ /^[a-z_][a-z0-9_]*[?!=]?$/i
          raise ArgumentError, "Method name must be a valid Ruby identifier: #{method_name}"
        end

        # Store configuration on the Auth class
        # Use class instance variable to store per-class configuration
        @auth.instance_variable_set(:@_external_identity_columns, {}) unless @auth.instance_variable_get(:@_external_identity_columns)
        columns = @auth.instance_variable_get(:@_external_identity_columns)

        # Check for duplicate declarations
        if columns.key?(name)
          raise ArgumentError, "external_identity_column :#{name} already declared"
        end

        # Store configuration
        columns[name] = {
          column: column,
          method_name: method_name,
          include_in_select: options.fetch(:include_in_select, true),
          override: options[:override] || false,
          validate: options[:validate] || false,
          options: options
        }

        # Define the helper method on the Auth class
        @auth.send(:define_method, method_name) do
          account ? account[column] : nil
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
      cols = super

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
    # @return [Array<Symbol>] List of identity names
    #
    # @example
    #   external_identity_column_list  # => [:stripe, :redis]
    def external_identity_column_list
      external_identity_columns_config.keys
    end

    # Get configuration for a specific external identity column
    #
    # @param name [Symbol] Identity name
    # @return [Hash, nil] Configuration hash or nil if not found
    #
    # @example
    #   external_identity_column_config(:stripe)
    #   # => {column: :stripe_customer_id, method_name: :account_stripe_id, ...}
    def external_identity_column_config(name)
      external_identity_columns_config[name]
    end

    # Get list of all generated helper method names
    #
    # @return [Array<Symbol>] List of method names
    #
    # @example
    #   external_identity_helper_methods  # => [:account_stripe_id, :account_redis_id]
    def external_identity_helper_methods
      external_identity_columns_config.values.map { |config| config[:method_name] }
    end

    # Check if a column has been declared as an external identity
    #
    # @param name [Symbol] Identity name or column name
    # @return [Boolean] True if declared
    #
    # @example
    #   external_identity_column?(:stripe)      # => true
    #   external_identity_column?(:stripe_id)   # => true (checks column too)
    #   external_identity_column?(:unknown)     # => false
    def external_identity_column?(name)
      return true if external_identity_columns_config.key?(name)

      # Also check if it matches any column name
      external_identity_columns_config.any? { |_k, v| v[:column] == name }
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
    #   #     name: :stripe,
    #   #     column: :stripe_customer_id,
    #   #     method: :account_stripe_id,
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

      external_identity_columns_config.map do |name, config|
        column = config[:column]
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
          name: name,
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

    # Validation hook - runs after configuration is complete
    #
    # Validates configuration and provides helpful warnings/errors
    def post_configure
      super if defined?(super)

      # Validate declared columns if requested
      validate_columns_exist! if external_identity_validate_columns

      # Check that columns are included in account_select if they should be
      validate_account_select_inclusion!
    end

    private

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

    # Validate that declared columns exist in the database
    #
    # Only runs if external_identity_validate_columns is true
    #
    # @raise [ArgumentError] If validation fails
    def validate_columns_exist!
      return unless db  # Skip if no database available

      schema = begin
                 db.schema(accounts_table)
               rescue StandardError
                 # Can't validate - database might not exist yet
                 return
               end

      column_names = schema.map { |col| col[0] }

      missing = []
      external_identity_columns_config.each do |name, config|
        column = config[:column]
        missing << "#{name} (#{column})" unless column_names.include?(column)
      end

      return if missing.empty?

      raise ArgumentError, "External identity columns not found in #{accounts_table} table: #{missing.join(', ')}. " \
                           "Add columns to database or set validate: false"
    end

    # Validate that columns are included in account_select if they should be
    #
    # Provides helpful warnings if configuration might not work as expected
    def validate_account_select_inclusion!
      current_select = account_select

      missing = []
      external_identity_columns_config.each do |name, config|
        column = config[:column]
        if config[:include_in_select] && !current_select.include?(column)
          missing << "#{name} (#{column})"
        end
      end

      return if missing.empty?

      warn "[external_identity] WARNING: Columns #{missing.join(', ')} marked for inclusion " \
           "but not in account_select. This may indicate a configuration order issue. " \
           "The feature should have added them automatically."
    end
  end
end
