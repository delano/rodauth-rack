# frozen_string_literal: true

#
# Place this file at: lib/rodauth/features/table_guard.rb
#
# Enable with:
#   enable :table_guard
#
# Configuration:
#   table_guard_mode :warn    # :warn, :error, :silent, or block
#   table_guard_skip_tables [:some_table]  # Skip checking specific tables

module Rodauth
  Feature.define(:table_guard, :TableGuard) do
    # Simplified configuration - mode can be symbol OR block
    auth_value_method :table_guard_mode, nil
    auth_value_method :table_guard_skip_tables, []
    auth_value_method :table_guard_check_columns?, true

    auth_methods(
      :check_required_tables!,
      :missing_tables,
      :all_table_methods,
      :list_all_required_tables,
      :table_status,
    )

    def post_configure
      super if defined?(super)
      check_required_tables! if should_check_tables?
    end

    def should_check_tables?
        # Try to get the mode - if it's a symbol, we can check it
        # If it's a Proc, we'll get an ArgumentError, which means it was configured

        mode = table_guard_mode
        mode != :silent && !mode.nil? && mode != :skip
    rescue ArgumentError
        # table_guard_mode is a block (expects 1 arg), so it was configured
        # We should check tables
        true
    end

    def check_required_tables!
      missing = missing_tables
      return if missing.empty?

      # Try to get mode as a symbol first
      begin
        mode = table_guard_mode

        case mode
        when :silent, :skip, nil
          # Do nothing
        when :warn
          warn build_missing_tables_message(missing)
        when :error
          raise Rodauth::ConfigurationError, build_missing_tables_message(missing)
        else
          raise Rodauth::ConfigurationError,
            "Invalid table_guard_mode: #{mode.inspect}. " \
            'Expected :silent, :warn, :error, or a Proc.'
        end
      rescue ArgumentError
        # table_guard_mode is a block that expects an argument
        # Call it with the missing tables
        result = table_guard_mode(missing)

        case result
        when :error, true
          raise Rodauth::ConfigurationError, build_missing_tables_message(missing)
        when String
          raise Rodauth::ConfigurationError, result
          # :continue, nil, false means don't raise
        end
      end
    end

    def missing_tables
      result = []

      # Check all methods ending in _table on this auth instance
      all_table_methods.each do |table_method|
        table_name = send(table_method)
        next if table_exists?(table_name)

        result << {
          method: table_method,
          table: table_name,
        }
      end

      result
    end

    def all_table_methods
      # Get all methods on this auth instance that end with _table
      methods.select { |m| m.to_s.end_with?('_table') }
    end

    def table_exists?(table_name)
      return true if table_guard_skip_tables.include?(table_name)

      db.table_exists?(table_name)
    rescue StandardError => ex
      warn "TableGuard: Unable to check table existence: #{ex.message}"
      true
    end

    def build_missing_tables_message(missing)
      lines = ["Rodauth TableGuard: Missing required database tables!\n"]

      missing.each do |info|
        lines << "  - Table: #{info[:table]} (configured via #{info[:method]})"
      end

      lines << ("\n" + build_migration_hints(missing))
      lines.join("\n")
    end

    def build_migration_hints(missing)
      hints = ['Migration hints:']

      unique_tables = missing.map { |i| i[:table] }.uniq

      hints << "\nRun migrations for these tables:"
      unique_tables.each do |table|
        hints << "  - #{table}"
      end

      hints << "\nOr disable table checking:"
      hints << '  table_guard_mode :silent'

      hints << "\nOr skip specific tables:"
      hints << "  table_guard_skip_tables #{unique_tables.inspect}"

      hints.join("\n")
    end

    def list_all_required_tables
      all_table_methods.map { |m| send(m) }.uniq.sort
    end

    def table_status
      all_table_methods.map do |method|
        table_name = send(method)
        {
          method: method,
          table: table_name,
          exists: table_exists?(table_name),
        }
      end
    end
  end
end
