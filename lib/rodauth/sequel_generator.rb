# frozen_string_literal: true

require_relative "table_inspector"
require_relative "template_inspector"

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
    # Uses TemplateInspector to extract ALL tables from ERB templates,
    # including "hidden" tables that don't have corresponding *_table methods
    # (like account_statuses and account_password_hashes from base.erb).
    #
    # @return [String] Sequel DROP TABLE code
    def generate_drop_statements
      # Extract all tables from ERB templates (not just discovered methods)
      all_tables = extract_all_tables_from_templates

      # Drop in reverse order to handle foreign key dependencies
      # (child tables first, then parent tables)
      ordered_tables = order_tables_for_drop(all_tables).reverse

      statements = ordered_tables.map do |table_name|
        "drop_table?(:#{table_name})"
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
    # Uses TemplateInspector to extract ALL tables from ERB templates.
    #
    # @param db [Sequel::Database] Database connection
    def execute_drops(db)
      # Extract all tables from ERB templates
      all_tables = extract_all_tables_from_templates

      # Drop in reverse order to handle foreign key dependencies
      ordered_tables = order_tables_for_drop(all_tables).reverse

      ordered_tables.each do |table_name|
        db.drop_table?(table_name.to_sym)
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

    # Extract all tables from ERB templates for the enabled features
    #
    # This discovers ALL tables that will be created, including "hidden" tables
    # like account_statuses and account_password_hashes that don't have
    # corresponding *_table methods in Rodauth.
    #
    # @return [Array<Symbol>] Array of all table names
    def extract_all_tables_from_templates
      features = extract_features_from_missing_tables
      table_prefix = extract_table_prefix
      db_type = extract_db_type

      TemplateInspector.all_tables_for_features(
        features,
        table_prefix: table_prefix,
        db_type: db_type
      )
    end

    # Extract table prefix from rodauth instance
    #
    # @return [String] Table prefix (singular form, e.g., "account")
    def extract_table_prefix
      if rodauth_instance.respond_to?(:accounts_table)
        table_name = rodauth_instance.accounts_table.to_s
        require 'dry/inflector'
        Dry::Inflector.new.singularize(table_name)
      else
        'account'
      end
    end

    # Extract database type for template evaluation
    #
    # @return [Symbol] Database type (:postgres, :mysql, :sqlite)
    def extract_db_type
      if db
        db.database_type
      else
        :postgres  # Default
      end
    end

    # Order tables for dropping (reverse dependency order)
    #
    # Rules:
    # - Feature tables first (have foreign keys to parent tables)
    # - Then account_password_hashes (foreign key to accounts)
    # - Then accounts (foreign key to account_statuses)
    # - Finally account_statuses (no dependencies)
    #
    # @param tables [Array<Symbol>] Table names
    # @return [Array<Symbol>] Ordered table names
    def order_tables_for_drop(tables)
      # Categorize tables by dependency level
      statuses_tables = []
      accounts_tables = []
      password_hash_tables = []
      feature_tables = []

      tables.each do |table_name|
        table_str = table_name.to_s
        if table_str.end_with?('_statuses')
          statuses_tables << table_name
        elsif table_str.match?(/^accounts?$/)
          accounts_tables << table_name
        elsif table_str.match?(/_password_hashes?$/)
          password_hash_tables << table_name
        else
          feature_tables << table_name
        end
      end

      # Return in creation order (statuses, then accounts, then others)
      # Caller will reverse this for dropping
      statuses_tables + accounts_tables + password_hash_tables + feature_tables
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
