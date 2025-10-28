# frozen_string_literal: true

# Ensure dependencies are loaded (they should be via require 'rodauth/rack')
require_relative "../table_inspector" unless defined?(Rodauth::TableInspector)
require_relative "../sequel_generator" unless defined?(Rodauth::SequelGenerator)

#
# Place this file at: lib/rodauth/features/table_guard.rb
#
# Enable with:
#   enable :table_guard
#
# Configuration:
#   table_guard_mode :warn    # :warn, :error, :silent, :skip, :raise, :halt/:exit, or block
#   table_guard_sequel_mode :log    # :log, :migration, :create, :sync
#   table_guard_skip_tables [:some_table]  # Skip checking specific tables
#
# Example modes:
#
#   # Warn but continue
#   table_guard_mode :warn
#
#   # Error log but continue
#   table_guard_mode :error
#
#   # Raise exception for handling upstream
#   table_guard_mode :raise
#
#   # Halt/exit startup (not recommended for multi-tenant)
#   table_guard_mode :halt
#
#   # Custom handling with block
#   table_guard_mode do |missing, config|
#     TenantLogger.log_missing_tables(current_tenant, missing)
#   end
#
# Sequel generation modes:
#
#   # Log migration code to logger
#   table_guard_sequel_mode :log
#
#   # Generate migration file
#   table_guard_sequel_mode :migration
#
#   # Create tables immediately (JIT)
#   table_guard_sequel_mode :create
#
#   # Drop and recreate (dev/test only)
#   table_guard_sequel_mode :sync

module Rodauth
  Feature.define(:table_guard, :TableGuard) do
    # Configuration methods
    auth_value_method :table_guard_mode, nil
    auth_value_method :table_guard_sequel_mode, nil
    auth_value_method :table_guard_skip_tables, []
    auth_value_method :table_guard_check_columns?, true
    auth_value_method :table_guard_migration_path, "db/migrate"

    # Public API methods
    auth_methods(
      :check_required_tables!,
      :missing_tables,
      :all_table_methods,
      :list_all_required_tables,
      :table_status
    )

    # Use auth_cached_method for table_configuration so it's computed
    # lazily per-instance and cached. This ensures it works in both:
    # - Normal web request flow (post_configure runs on throwaway instance)
    # - Console interrogation (new instances need access to configuration)
    auth_cached_method :table_configuration

    # Runs after configuration is complete
    #
    # Checks tables based on mode. Note: post_configure runs on a throwaway
    # instance during initial configuration (see Rodauth.configure line 66),
    # so we can't rely on instance variables persisting. Use auth_cached_method
    # for any data needed by later instances.
    def post_configure
      super if defined?(super)

      # Check tables based on mode (uses lazy-loaded table_configuration)
      check_required_tables! if should_check_tables?
    end

    # Override hook_action to check table status
    #
    # [Reviewer note] Do not remove this method even though it does nothing by default.
    #
    # @param [Symbol] hook_type :before or :after
    # @param [Symbol] action :login, :logout, etc.
    def hook_action(hook_type, action)
      super # does nothing by default
    end

    # Determine if table checking should run
    #
    # Returns true unless mode is :skip, :silent, or nil
    def should_check_tables?
      return false unless instance_variable_defined?(:@table_guard_mode)

      mode_value = instance_variable_get(:@table_guard_mode)

      # Always check if mode is a Proc (custom handler)
      return true if mode_value.is_a?(Proc)

      # Check if mode indicates checking is enabled
      mode_value != :silent && mode_value != :skip && !mode_value.nil?
    end

    # Internal method called by auth_cached_method :table_configuration
    #
    # Discovers and returns table configuration. This is called lazily
    # per-instance and the result is cached in @table_configuration.
    #
    # @return [Hash<Symbol, Hash>] Table configuration
    def _table_configuration
      config = Rodauth::TableInspector.table_information(self)
      rodauth_debug("TableGuard: Discovered #{config.size} required tables") if ENV['RODAUTH_DEBUG']
      config
    end

    # Check required tables and handle based on mode
    #
    # This is the main entry point for table validation
    def check_required_tables!
      missing = missing_tables

      if missing.empty?
        rodauth_debug("TableGuard: All required tables exist") if ENV['RODAUTH_DEBUG']
        return
      end

      # Handle based on validation mode
      handle_table_guard_mode(missing)

      # Generate Sequel if configured
      handle_sequel_generation(missing) if table_guard_sequel_mode
    end

    # Get list of tables that are missing
    #
    # @return [Array<Hash>] Array of missing table information
    def missing_tables
      result = []

      table_configuration.each do |method, info|
        table_name = info[:name]
        next if table_exists?(table_name)

        result << {
          method: method,
          table: table_name,
          feature: info[:feature],
          structure: info[:structure]
        }
      end

      result
    end

    # Get all table method names ending in _table
    #
    # @return [Array<Symbol>] Table method names
    def all_table_methods
      methods.select { |m| m.to_s.end_with?("_table") }
    end

    # Check if a table exists in the database
    #
    # @param table_name [String, Symbol] Table name
    # @return [Boolean] True if table exists
    def table_exists?(table_name)
      return true if table_guard_skip_tables.include?(table_name.to_sym) ||
                     table_guard_skip_tables.include?(table_name.to_s)

      db.table_exists?(table_name)
    rescue StandardError => e
      rodauth_warn("TableGuard: Unable to check table existence for #{table_name}: #{e.message}")
      true # Assume exists to avoid false positives
    end

    # List all required table names (sorted)
    #
    # @return [Array<String>] Sorted table names
    def list_all_required_tables
      table_configuration.values.map { |info| info[:name] }.uniq.sort
    end

    # Get detailed status for all tables
    #
    # @return [Array<Hash>] Status information for each table
    def table_status
      table_configuration.map do |method, info|
        {
          method: method,
          table: info[:name],
          feature: info[:feature],
          exists: table_exists?(info[:name])
        }
      end
    end

    private

    # Handle table validation based on mode setting
    #
    # @param missing [Array<Hash>] Missing table information
    def handle_table_guard_mode(missing)
      # Try to get mode as a symbol first
      begin
        mode = table_guard_mode

        case mode
        when :silent, :skip, nil
          rodauth_debug("TableGuard: Discovered #{@table_configuration.size} tables, skipping validation")

        when :warn
          rodauth_warn(build_missing_tables_message(missing))

        when :error
          rodauth_error(build_missing_tables_error(missing))

        when :raise
          rodauth_error(build_missing_tables_error(missing))
          raise Rodauth::ConfigurationError, build_missing_tables_message(missing)

        when :halt, :exit
          rodauth_error(build_missing_tables_error(missing))
          exit(1)

        else
          raise Rodauth::ConfigurationError,
                "Invalid table_guard_mode: #{mode.inspect}. " \
                "Expected :silent, :skip, :warn, :error, :raise, :halt, or a Proc."
        end
      rescue ArgumentError
        # table_guard_mode is a block that expects arguments
        # Call it with missing tables and configuration
        result = table_guard_mode(missing, table_configuration)

        case result
        when :error, :raise, true
          raise Rodauth::ConfigurationError, build_missing_tables_message(missing)
        when String
          raise Rodauth::ConfigurationError, result
          # :continue, nil, false means don't raise
        end
      end
    end

    # Handle Sequel generation based on sequel mode
    #
    # @param missing [Array<Hash>] Missing table information
    def handle_sequel_generation(missing)
      generator = Rodauth::SequelGenerator.new(missing, self)

      case table_guard_sequel_mode
      when :log
        rodauth_info("TableGuard: Sequel migration code:\n\n#{generator.generate_migration}")

      when :migration
        filename = generate_migration_filename
        FileUtils.mkdir_p(File.dirname(filename))
        File.write(filename, generator.generate_migration)
        rodauth_info("TableGuard: Generated migration file: #{filename}")

      when :create
        generator.execute_creates(db)
        rodauth_info("TableGuard: Created #{missing.size} table(s)")

      when :sync
        unless %w[dev development test].any? { |env| ENV['RACK_ENV']&.start_with?(env) }
          rodauth_error("TableGuard: Sync mode only available in dev/test environments (current: #{ENV['RACK_ENV']})")
          return
        end

        # Drop and recreate
        generator.execute_drops(db)
        generator.execute_creates(db)
        rodauth_info("TableGuard: Synced #{missing.size} table(s) (dropped and recreated)")

      else
        rodauth_error("TableGuard: Invalid sequel mode: #{table_guard_sequel_mode.inspect}")
      end
    rescue StandardError => e
      rodauth_error("TableGuard: Sequel generation failed: #{e.class} - #{e.message}")
      raise if [:raise, :halt, :exit].include?(table_guard_mode)
    end

    # Generate migration filename with timestamp
    #
    # @return [String] Full path to migration file
    def generate_migration_filename
      timestamp = Time.now.strftime("%Y%m%d%H%M%S")
      filename = "#{timestamp}_create_rodauth_tables.rb"
      File.join(table_guard_migration_path, filename)
    end

    # Build user-friendly message for missing tables
    #
    # @param missing [Array<Hash>] Missing table information
    # @return [String] Formatted message
    def build_missing_tables_message(missing)
      lines = ["Rodauth TableGuard: Missing required database tables!"]
      lines << ""

      missing.each do |info|
        lines << "  - Table: #{info[:table]} (feature: #{info[:feature]}, method: #{info[:method]})"
      end

      lines << ""
      lines << build_migration_hints(missing)

      lines.join("\n")
    end

    # Build distinctive error message for error-level logging
    #
    # @param missing [Array<Hash>] Missing table information
    # @return [String] Formatted error message
    def build_missing_tables_error(missing)
      table_list = missing.map { |i| i[:table] }.join(", ")
      "CRITICAL: Missing Rodauth tables - #{table_list}"
    end

    # Build helpful hints for resolving missing tables
    #
    # @param missing [Array<Hash>] Missing table information
    # @return [String] Formatted hints
    def build_migration_hints(missing)
      hints = ["Migration hints:"]
      hints << ""

      unique_tables = missing.map { |i| i[:table] }.uniq

      hints << "Run migrations for these tables:"
      unique_tables.each do |table|
        hints << "  - #{table}"
      end

      if table_guard_sequel_mode.nil?
        hints << ""
        hints << "Or enable automatic Sequel generation:"
        hints << "  table_guard_sequel_mode :log        # Log to console"
        hints << "  table_guard_sequel_mode :migration  # Generate migration file"
        hints << "  table_guard_sequel_mode :create     # Create tables now"
      end

      hints << ""
      hints << "Or disable table checking:"
      hints << "  table_guard_mode :silent"

      hints << ""
      hints << "Or skip specific tables:"
      hints << "  table_guard_skip_tables #{unique_tables.inspect}"

      hints.join("\n")
    end

    # Debug logging helper
    def rodauth_debug(msg)
      return unless respond_to?(:logger)

      logger.debug(msg) if logger.respond_to?(:debug)
    end

    # Info logging helper
    def rodauth_info(msg)
      return unless respond_to?(:logger)

      if logger.respond_to?(:info)
        logger.info(msg)
      else
        puts msg
      end
    end

    # Warn logging helper
    def rodauth_warn(msg)
      return unless respond_to?(:logger)

      if logger.respond_to?(:warn)
        logger.warn(msg)
      else
        warn msg
      end
    end

    # Error logging helper
    def rodauth_error(msg)
      return unless respond_to?(:logger)

      if logger.respond_to?(:error)
        logger.error(msg)
      else
        warn "[ERROR] #{msg}"
      end
    end
  end
end
