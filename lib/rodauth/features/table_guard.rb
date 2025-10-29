# frozen_string_literal: true
# lib/rodauth/features/table_guard.rb

# Ensure dependencies are loaded (they should be via require 'rodauth/tools')
require_relative "../table_inspector" unless defined?(Rodauth::TableInspector)
require_relative "../sequel_generator" unless defined?(Rodauth::SequelGenerator)

#
# Enable with:
#   enable :table_guard
#
# Configuration:
#   table_guard_mode :warn    # :warn, :error, :silent, :skip, :raise, :halt/:exit, or block
#   table_guard_sequel_mode :log    # :log, :migration, :create, :sync
#   table_guard_skip_tables [:some_table]  # Skip checking specific tables
#
# Logging:
#   def logger; MyLogger; end              # Standard Rodauth logger (recommended)
#   table_guard_logger MyLogger            # Feature-specific logger (alternative)
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
#   # Drop and recreate missing tables (dev/test only)
#   table_guard_sequel_mode :sync
#
#   # Drop and recreate ALL tables every startup (dev/test only)
#   table_guard_sequel_mode :recreate

module Rodauth
  Feature.define(:table_guard, :TableGuard) do
    # Configuration methods
    auth_value_method :table_guard_mode, nil
    auth_value_method :table_guard_sequel_mode, nil
    auth_value_method :table_guard_skip_tables, []
    auth_value_method :table_guard_check_columns?, true
    auth_value_method :table_guard_migration_path, "db/migrate"
    auth_value_method :table_guard_logger, nil
    auth_value_method :table_guard_logger_name, nil  # For SemanticLogger integration

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
      # Check if table_guard_mode is defined as a block (has parameters)
      # by checking the method's arity. If arity > 0, it's a block that
      # expects arguments and we can't call it without args.
      mode_method = method(:table_guard_mode)

      # If method expects parameters (arity > 0), it's a custom block handler
      return true if mode_method.arity > 0

      # Safe to call the method - it either returns a symbol or is a 0-arity block
      mode_value = table_guard_mode

      # Always check if mode is a Proc (0-arity custom handler)
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
      rodauth_debug("[table_guard] Discovered #{config.size} required tables") if ENV['RODAUTH_DEBUG']
      config
    end

    # Check required tables and handle based on mode
    #
    # This is the main entry point for table validation
    def check_required_tables!
      missing = missing_tables

      # Special case: :recreate and :drop modes always run, even when no tables are missing
      if missing.empty? && ![:recreate, :drop].include?(table_guard_sequel_mode)
        rodauth_info('')
        rodauth_info("─" * 70)
        rodauth_info("✅ TableGuard: All required tables exist")
        rodauth_info("   #{table_configuration.size} tables validated successfully")
        rodauth_info("─" * 70)
        rodauth_info('')
        return
      end

      # Handle based on validation mode (unless recreate/drop mode which handles its own validation)
      handle_table_guard_mode(missing) unless [:recreate, :drop].include?(table_guard_sequel_mode)

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
    # Temporarily suppresses Sequel's logger to avoid confusing error logs
    # when checking non-existent tables (Sequel logs SQLite exceptions before
    # catching them internally).
    #
    # @param table_name [String, Symbol] Table name
    # @return [Boolean] True if table exists
    def table_exists?(table_name)
      return true if table_guard_skip_tables.include?(table_name.to_sym) ||
                     table_guard_skip_tables.include?(table_name.to_s)

      # Temporarily suppress Sequel's logger to prevent confusing error logs
      # during table existence checks. Sequel's table_exists? implementation
      # attempts a SELECT query and logs the exception if table doesn't exist,
      # even though it catches the error internally.
      original_logger = db.loggers.dup
      db.loggers.clear

      db.table_exists?(table_name)
    rescue StandardError => e
      rodauth_warn("[table_guard] Unable to check table existence for #{table_name}: #{e.message}")
      true # Assume exists to avoid false positives
    ensure
      # Restore original loggers
      if original_logger
        db.loggers.clear
        original_logger.each { |logger| db.loggers << logger }
      end
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
      # Check if table_guard_mode is a block by inspecting method arity
      mode_method = method(:table_guard_mode)

      # If method expects parameters, it's a custom block handler
      if mode_method.arity > 0
        # Call with appropriate arguments based on arity
        result = case mode_method.arity
                 when 1 then table_guard_mode(missing)
                 else table_guard_mode(missing, table_configuration)
                 end

        case result
        when :error, :raise, true
          raise Rodauth::ConfigurationError, build_missing_tables_message(missing)
        when String
          raise Rodauth::ConfigurationError, result
          # :continue, nil, false means don't raise
        end
        return
      end

      # Safe to call without arguments - get the mode value
      mode = table_guard_mode

      # If it's a 0-arity Proc, call it
      if mode.is_a?(Proc)
        result = mode.call

        case result
        when :error, :raise, true
          raise Rodauth::ConfigurationError, build_missing_tables_message(missing)
        when String
          raise Rodauth::ConfigurationError, result
          # :continue, nil, false means don't raise
        end
        return
      end

      # Handle symbol modes
      case mode
      when :silent, :skip, nil
        rodauth_debug("[table_guard] Discovered #{@table_configuration.size} tables, skipping validation")

      when :warn
        rodauth_warn(build_missing_tables_message(missing))

      when :error
        # Print distinctive message to error log but continue execution
        rodauth_error(build_missing_tables_error(missing))

      when :raise
        # Let the error propagate up
        rodauth_error(build_missing_tables_error(missing))
        raise Rodauth::ConfigurationError, build_missing_tables_message(missing)

      when :halt, :exit
        # Exit the process early
        rodauth_error(build_missing_tables_error(missing))
        exit(1)

      else
        raise Rodauth::ConfigurationError,
              "Invalid table_guard_mode: #{mode.inspect}. " \
              "Expected :silent, :skip, :warn, :error, :raise, :halt, or a Proc."
      end
    end

    # Handle Sequel generation based on sequel mode
    #
    # @param missing [Array<Hash>] Missing table information
    def handle_sequel_generation(missing)
      generator = Rodauth::SequelGenerator.new(missing, self)

      case table_guard_sequel_mode
      when :log
        rodauth_info("[table_guard] Sequel migration code:\n\n#{generator.generate_migration}")

      when :migration
        filename = generate_migration_filename
        FileUtils.mkdir_p(File.dirname(filename))
        File.write(filename, generator.generate_migration)
        rodauth_info("[table_guard] Generated migration file: #{filename}")

      when :create
        rodauth_debug("[table_guard] Creating #{missing.size} table(s)...")
        generator.execute_creates(db)
        rodauth_info("[table_guard] Created #{missing.size} table(s)")

        # Re-validate to show success message
        revalidate_after_creation

      when :sync
        unless %w[dev development test].any? { |env| ENV['RACK_ENV']&.start_with?(env) }
          rodauth_error("[table_guard] :sync mode only available in dev/test environments (current: #{ENV['RACK_ENV']})")
          return
        end

        # Drop and recreate only missing tables
        rodauth_info("[table_guard] Syncing #{missing.size} table(s)...")
        generator.execute_drops(db)
        generator.execute_creates(db)
        rodauth_info("[table_guard] Synced #{missing.size} table(s) (dropped and recreated)")

        # Re-validate to show success message
        revalidate_after_creation

      when :recreate
        unless %w[dev development test].any? { |env| ENV['RACK_ENV']&.start_with?(env) }
          rodauth_error("[table_guard] :recreate mode only available in dev/test environments (current: #{ENV['RACK_ENV']})")
          return
        end

        # Get all required tables from configuration
        all_tables = table_configuration.map { |_, info| info[:name] }.uniq

        # Drop all existing tables in reverse dependency order
        rodauth_info("[table_guard] Recreating #{all_tables.size} table(s) (dropping all, creating fresh)...")
        drop_tables(all_tables.reverse)

        # Create all tables fresh (uses missing_tables which should now be all of them)
        current_missing = missing_tables
        if current_missing.any?
          generator_for_all = Rodauth::SequelGenerator.new(current_missing, self)
          generator_for_all.execute_creates(db)
        end

        rodauth_info("[table_guard] Recreated #{all_tables.size} table(s)")

        # Re-validate to show success message
        revalidate_after_creation

        # This is useful when you already have auto migrations that run at start
        # time. This will drop the tables so that the migrations run every time.
      when :drop
        unless %w[dev development test].any? { |env| ENV['RACK_ENV']&.start_with?(env) }
          rodauth_error("[table_guard] :drop mode only available in dev/test environments (current: #{ENV['RACK_ENV']})")
          return
        end

        # Get all required tables from configuration
        all_tables = table_configuration.map { |_, info| info[:name] }.uniq

        # Drop all existing tables in reverse dependency order
        rodauth_info("[table_guard] Dropping #{all_tables.size} table(s)...")
        drop_tables(all_tables.reverse)

        # Drop Sequel migration tracking tables so migrations re-run from scratch
        drop_tables([:schema_info, :schema_migrations])

        rodauth_info("[table_guard] Dropped #{all_tables.size} table(s) and migration tracking")
        rodauth_info("[table_guard] Migrations will run from scratch on next execution")


      else
        rodauth_error("[table_guard] Invalid sequel mode: #{table_guard_sequel_mode.inspect}")
      end
    rescue StandardError => e
      rodauth_error("[table_guard] Sequel generation failed: #{e.class} - #{e.message}")
      rodauth_error("  Location: #{e.backtrace.first}")
      raise if [:raise, :halt, :exit].include?(table_guard_mode)
    end

    # Check if the database supports CASCADE on DELETE
    #
    # @return [Boolean] True if using a db engine that supports DELETE ... CASCADE
    def cascade_supported?
      [:postgres, :mysql].include?(db.database_type)
    end

    # Drop tables with proper CASCADE handling for non-SQLite databases
    #
    # SQLite doesn't support CASCADE on DROP TABLE, so we need to detect
    # the database type and avoid using it. For other databases, CASCADE
    # ensures dependent objects are properly cleaned up.
    #
    # @param table_names [Array<String, Symbol>] Tables to drop
    def drop_tables(table_names)
      table_names.each do |table_name|
        next unless db.table_exists?(table_name)

        # SQLite: simple drop without CASCADE
        # PostgreSQL, MySQL: use CASCADE for proper cleanup
        options = {
          cascade: cascade_supported?
        }
        db.drop_table(table_name, **options)

        rodauth_debug("[table_guard] Dropped #{table_name} (#{options})") if ENV['RODAUTH_DEBUG']
      end
    end

    # Re-validate tables after creation to show success message
    #
    # This runs the validation again after tables are created,
    # which will display the success message instead of leaving
    # the error/warning messages as the last output
    def revalidate_after_creation
      rodauth_info("")  # Blank line for readability

      still_missing = missing_tables

      if still_missing.empty?
        rodauth_info("=" * 70)
        rodauth_info("✓ [table_guard] All required tables now exist")
        rodauth_info("  #{table_configuration.size} tables validated successfully")
        rodauth_info("=" * 70)
      else
        rodauth_error("[table_guard] Still missing #{still_missing.size} table(s) after creation!")
        still_missing.each do |info|
          rodauth_error("  - #{info[:table]} (#{info[:feature]})")
        end
      end
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
      lines = ["Rodauth [table_guard] Missing required database tables!"]
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
      hints = []
      hints << ""
      hints << "⚠️  DATABASE OPERATIONS WILL FAIL UNTIL TABLES ARE CREATED"
      hints << ""

      unique_tables = missing.map { |i| i[:table] }.uniq

      if table_guard_sequel_mode.nil?
        hints << "Quick fix for development (creates tables automatically):"
        hints << "  table_guard_sequel_mode :create"
        hints << ""
        hints << "Other options:"
        hints << "  table_guard_sequel_mode :log        # Show migration code"
        hints << "  table_guard_sequel_mode :migration  # Generate migration file"
        hints << ""
      end

      hints << "Required tables:"
      unique_tables.each do |table|
        hints << "  - #{table}"
      end

      hints << ""
      hints << "To disable checking: table_guard_mode :silent"
      hints << "To skip specific tables: table_guard_skip_tables #{unique_tables.inspect}"

      hints.join("\n")
    end

    # Get logger instance with fallback chain
    #
    # Checks in order:
    # 1. table_guard_logger (feature-specific logger instance)
    # 2. SemanticLogger[table_guard_logger_name] (if name provided)
    # 3. logger (Rodauth instance method if defined by user)
    # 4. scope.logger (Roda app logger if available)
    # 5. nil (no logger available)
    #
    # For SemanticLogger integration, use table_guard_logger_name instead of
    # table_guard_logger to ensure level configuration is preserved:
    #
    #   table_guard_logger_name 'rodauth'  # Looks up SemanticLogger['rodauth']
    #
    # Note: SemanticLogger[] creates a new logger instance each time it's called.
    # If you configure logger levels via YAML or code, use table_guard_logger_name
    # so the feature can look up the logger at runtime and get the configured instance.
    def get_logger
      result = table_guard_logger

      # If no direct logger but name provided, look up SemanticLogger
      if !result && table_guard_logger_name && defined?(SemanticLogger)
        result = SemanticLogger[table_guard_logger_name]
      end

      # Fallback chain if still no logger
      result ||= (respond_to?(:logger) ? logger : nil) ||
                 (respond_to?(:scope) && scope.respond_to?(:logger) ? scope.logger : nil)

      # Warn once if logger appears to be SemanticLogger but has no appenders
      if result && result.class.name&.include?('SemanticLogger') &&
         defined?(SemanticLogger) && SemanticLogger.appenders.empty?
        warn "[table_guard] WARNING: SemanticLogger has no appenders configured. " \
             "Add: SemanticLogger.add_appender(io: STDOUT, level: :info)"
      end

      result
    end

    # Debug logging helper
    def rodauth_debug(msg)
      logger = get_logger
      return unless logger

      if logger.respond_to?(:debug)
        logger.debug(msg)
      elsif ENV['RODAUTH_DEBUG']
        warn "[DEBUG] #{msg}"
      end
    end

    # Info logging helper
    def rodauth_info(msg)
      logger = get_logger

      if logger&.respond_to?(:info)
        logger.info(msg)
      elsif logger&.respond_to?(:<<)
        # Support loggers that only have << method
        logger << "#{msg}\n"
      else
        puts msg
      end
    end

    # Warn logging helper
    def rodauth_warn(msg)
      logger = get_logger

      if logger&.respond_to?(:warn)
        logger.warn(msg)
      elsif logger&.respond_to?(:<<)
        logger << "[WARN] #{msg}\n"
      else
        warn msg
      end
    end

    # Error logging helper
    def rodauth_error(msg)
      logger = get_logger

      if logger&.respond_to?(:error)
        logger.error(msg)
      elsif logger&.respond_to?(:<<)
        logger << "[ERROR] #{msg}\n"
      else
        warn "[ERROR] #{msg}"
      end
    end
  end
end
