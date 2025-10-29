# frozen_string_literal: true

require_relative "table_inspector"

module Rodauth
  # SequelGenerator generates Sequel migration code for missing Rodauth tables.
  #
  # It uses table structure information from TableInspector to generate
  # appropriate CREATE TABLE statements with proper columns, foreign keys,
  # and indexes.
  #
  # @example Generate migration for missing tables
  #   missing = rodauth.missing_tables
  #   generator = Rodauth::SequelGenerator.new(missing, rodauth)
  #   puts generator.generate_migration
  #
  # @example Generate only CREATE statements
  #   puts generator.generate_create_statements
  class SequelGenerator
    attr_reader :missing_tables, :rodauth_instance, :db

    # Initialize the Sequel generator
    #
    # @param missing_tables [Array<Hash>] Array of missing table info from table_guard
    # @param rodauth_instance [Rodauth::Auth] Rodauth instance for context
    def initialize(missing_tables, rodauth_instance)
      @missing_tables = missing_tables
      @rodauth_instance = rodauth_instance
      @db = rodauth_instance.respond_to?(:db) ? rodauth_instance.db : nil
    end

    # Generate a complete Sequel migration with up and down blocks
    #
    # @param idempotent [Boolean] Use create_table? for idempotency (default: true)
    # @return [String] Complete Sequel migration code
    def generate_migration(idempotent: true)
      # Extract unique features from missing tables
      features_needed = extract_features_from_missing_tables

      # Use Migration class to generate from ERB templates
      migration = create_migration_generator(features_needed)

      # Generate the migration content
      migration_content = migration.generate

      # Wrap in Sequel.migration block with up/down
      <<~RUBY
        # frozen_string_literal: true

        Sequel.migration do
          up do
        #{indent(migration_content, 4)}
          end

          down do
        #{indent(generate_drop_statements, 4)}
          end
        end
      RUBY
    end

    # Generate only the CREATE TABLE statements
    #
    # @param idempotent [Boolean] Use create_table? for idempotency (default: true)
    # @return [String] Sequel CREATE TABLE code
    def generate_create_statements(idempotent: true)
      # Extract unique features from missing tables
      features_needed = extract_features_from_missing_tables

      # Use Migration class to generate from ERB templates
      migration = create_migration_generator(features_needed)

      # Generate the migration content
      migration.generate
    end

    # Generate DROP TABLE statements
    #
    # @return [String] Sequel DROP TABLE code
    def generate_drop_statements
      # Drop in reverse order to handle foreign key dependencies
      ordered_tables = order_tables_by_dependency.reverse

      statements = ordered_tables.map do |table_info|
        "drop_table?(:#{table_info[:table]})"
      end

      statements.join("\n")
    end

    # Execute CREATE TABLE operations directly against the database
    #
    # @param db [Sequel::Database] Database connection
    def execute_creates(db)
      # Extract unique features from missing tables
      features_needed = extract_features_from_missing_tables

      # Use Migration class to execute ERB templates directly
      migration = create_migration_generator(features_needed)

      begin
        migration.execute_create_tables(db)
      rescue => e
        raise "Failed to execute table creation: #{e.class} - #{e.message}\n  #{e.backtrace.first(5).join("\n  ")}"
      end
    end

    # Execute DROP TABLE operations directly against the database
    #
    # @param db [Sequel::Database] Database connection
    def execute_drops(db)
      ordered_tables = order_tables_by_dependency.reverse

      ordered_tables.each do |table_info|
        db.drop_table?(table_info[:table].to_sym)
      end
    end

    private

    # Extract unique features from missing tables
    #
    # @return [Array<Symbol>] Array of unique feature names
    def extract_features_from_missing_tables
      features = missing_tables.map { |t| t[:feature] }.compact.uniq

      # Ensure :base feature is included if accounts table is missing
      if missing_tables.any? { |t| t[:table].to_s.match?(/^accounts?$/) }
        features.unshift(:base) unless features.include?(:base)
      end

      features
    end

    # Create a Migration generator instance
    #
    # @param features [Array<Symbol>] Features to generate migrations for
    # @return [Rodauth::Tools::Migration] Migration generator instance
    def create_migration_generator(features)
      # Get table prefix from rodauth instance or use default
      # The prefix should be singular (e.g., "account" not "accounts")
      prefix = if rodauth_instance.respond_to?(:accounts_table)
                 table_name = rodauth_instance.accounts_table.to_s
                 # Use dry-inflector to singularize the table name
                 require 'dry/inflector'
                 Dry::Inflector.new.singularize(table_name)
               else
                 'account'
               end

      Rodauth::Tools::Migration.new(
        features: features,
        prefix: prefix,
        db: db || create_mock_db
      )
    end

    # Create a mock database for template generation when no real DB is available
    #
    # @return [Rodauth::Tools::Migration::MockSequelDatabase] Mock database
    def create_mock_db
      adapter = if db
                  db.database_type
                else
                  :postgres  # Default to PostgreSQL
                end

      Rodauth::Tools::Migration::MockSequelDatabase.new(adapter)
    end

    # Order tables by dependency (accounts table first, then feature tables)
    def order_tables_by_dependency
      primary_tables = []
      feature_tables = []

      missing_tables.each do |table_info|
        table_name = table_info[:table].to_s
        method_name = table_info[:method]

        structure = TableInspector.infer_table_structure(method_name, table_name)

        if structure[:type] == :primary || table_name.match?(/^accounts?$/)
          primary_tables << table_info
        else
          feature_tables << table_info
        end
      end

      primary_tables + feature_tables
    end

    # Get the accounts table name from Rodauth instance
    def accounts_table_name
      if rodauth_instance.respond_to?(:accounts_table)
        rodauth_instance.accounts_table
      else
        :accounts
      end
    end

    # Check if database is PostgreSQL
    def postgres?
      return false unless db

      db.database_type == :postgres
    rescue StandardError
      false
    end

    # Check if database supports partial indexes
    def supports_partial_indexes?
      return false unless db

      %i[postgres sqlite].include?(db.database_type)
    rescue StandardError
      false
    end

    # Indent each line of text
    #
    # @param text [String] Text to indent
    # @param spaces [Integer] Number of spaces
    # @return [String] Indented text
    def indent(text, spaces)
      text.lines.map { |line| line.strip.empty? ? line : (" " * spaces) + line }.join
    end
  end
end
