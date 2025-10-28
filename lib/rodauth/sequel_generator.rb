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
    # @return [String] Complete Sequel migration code
    def generate_migration
      <<~RUBY
        # frozen_string_literal: true

        Sequel.migration do
          up do
        #{indent(generate_create_statements, 4)}
          end

          down do
        #{indent(generate_drop_statements, 4)}
          end
        end
      RUBY
    end

    # Generate only the CREATE TABLE statements
    #
    # @return [String] Sequel CREATE TABLE code
    def generate_create_statements
      statements = []

      # Group tables by dependency order (accounts first, then others)
      ordered_tables = order_tables_by_dependency

      ordered_tables.each do |table_info|
        table_name = table_info[:table]
        method_name = table_info[:method]

        structure = TableInspector.infer_table_structure(method_name, table_name)
        statements << generate_create_table(table_name, structure)
      end

      statements.join("\n\n")
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
      ordered_tables = order_tables_by_dependency

      ordered_tables.each do |table_info|
        table_name = table_info[:table]
        method_name = table_info[:method]

        structure = TableInspector.infer_table_structure(method_name, table_name)
        create_table_directly(db, table_name, structure)
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

    # Generate CREATE TABLE statement for a single table
    #
    # @param table_name [String, Symbol] Table name
    # @param structure [Hash] Table structure metadata
    # @return [String] Sequel CREATE TABLE code
    def generate_create_table(table_name, structure)
      lines = []

      # Add comment if known feature
      if structure[:type] == :feature || structure[:type] == :primary
        feature = TableInspector.infer_feature_from_method("#{table_name}_table".to_sym)
        lines << "# Table for #{feature} feature" if feature
      end

      lines << "create_table(:#{table_name}) do"

      # Primary key
      if structure[:primary_key]
        lines << "  primary_key :#{structure[:primary_key]}, type: :Bignum"
      end

      # Columns
      structure[:columns]&.each do |column|
        next if column == structure[:primary_key] # Skip PK, already defined

        lines << "  #{generate_column_definition(column, table_name, structure)}"
      end

      # Indexes
      structure[:indexes]&.each do |index_columns|
        lines << "  #{generate_index_definition(index_columns, structure)}"
      end

      # Foreign keys (if not already defined via foreign_key column type)
      # Only add if using regular column + separate constraint pattern
      # (Most Rodauth tables use foreign_key column type instead)

      lines << "end"

      lines.join("\n")
    end

    # Create a table directly in the database using Sequel DSL
    #
    # @param db [Sequel::Database] Database connection
    # @param table_name [String, Symbol] Table name
    # @param structure [Hash] Table structure metadata
    def create_table_directly(db, table_name, structure)
      db.create_table(table_name.to_sym) do
        # Primary key
        if structure[:primary_key]
          primary_key structure[:primary_key], type: :Bignum
        end

        # Columns
        structure[:columns]&.each do |column|
          next if column == structure[:primary_key]

          add_column_to_table(self, column, table_name, structure)
        end

        # Indexes
        structure[:indexes]&.each do |index_columns|
          add_index_to_table(self, index_columns, structure, db)
        end
      end
    end

    private

    # Add a column to the table being created
    #
    # @param table_def [Sequel::Schema::CreateTableGenerator] Table generator
    # @param column [Symbol] Column name
    # @param table_name [String, Symbol] Table name
    # @param structure [Hash] Table structure
    def add_column_to_table(table_def, column, table_name, structure)
      case column
      when :account_id
        if structure[:type] == :feature
          table_def.foreign_key :account_id, accounts_table_name, type: :Bignum, null: false
        else
          table_def.Integer :account_id, null: false
        end
      when :email
        if postgres?
          table_def.citext :email, null: false
        else
          table_def.String :email, null: false
        end
      when :password_hash
        table_def.String :password_hash
      when :status_id, :status
        table_def.Integer :status, null: false, default: 1
      when :key
        table_def.String :key, null: false
      when :deadline
        table_def.DateTime :deadline, null: false
      when :requested_at
        table_def.DateTime :requested_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      when :created_at
        table_def.DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      when :updated_at
        table_def.DateTime :updated_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      when :last_use, :last_activity_at, :last_login_at
        table_def.Time column, null: false, default: Sequel::CURRENT_TIMESTAMP
      when :num_failures, :number, :sign_count
        table_def.Integer column, null: false, default: 0
      when :code
        table_def.String :code, null: false
      when :phone_number, :login
        table_def.String column, null: false
      when :code_issued_at, :changed_at, :expired_at, :at, :email_last_sent
        table_def.DateTime column
      when :public_key, :metadata
        table_def.String column, text: true
      when :webauthn_id, :session_id
        table_def.String column, null: false
      when :message
        table_def.String :message, null: false
      else
        table_def.String column
      end
    end

    # Add an index to the table being created
    #
    # @param table_def [Sequel::Schema::CreateTableGenerator] Table generator
    # @param columns [Array<Symbol>] Index columns
    # @param structure [Hash] Table structure
    # @param db [Sequel::Database] Database connection
    def add_index_to_table(table_def, columns, structure, db)
      if columns == [:email] && structure[:type] == :primary
        if db.supports_partial_indexes?
          table_def.index :email, unique: true, where: { status: [1, 2] }
        else
          table_def.index :email, unique: true
        end
      elsif columns.length == 1
        table_def.index columns.first
      else
        table_def.index columns
      end
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

    # Generate column definition
    #
    # @param column [Symbol] Column name
    # @param table_name [String, Symbol] Table name
    # @param structure [Hash] Table structure
    # @return [String] Sequel column definition
    def generate_column_definition(column, table_name, structure)
      case column
      when :id
        # Already handled as primary key
        "# id handled by primary_key"
      when :account_id
        # Most feature tables use foreign key to accounts
        if structure[:type] == :feature
          "foreign_key :account_id, :#{accounts_table_name}, type: :Bignum, null: false"
        else
          "Integer :account_id, null: false"
        end
      when :email
        if postgres?
          "citext :email, null: false"
        else
          "String :email, null: false"
        end
      when :password_hash
        "String :password_hash"
      when :status_id, :status
        "Integer :status, null: false, default: 1"
      when :key
        "String :key, null: false"
      when :deadline
        "DateTime :deadline, null: false"
      when :requested_at
        "DateTime :requested_at, null: false, default: Sequel::CURRENT_TIMESTAMP"
      when :created_at
        "DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP"
      when :updated_at
        "DateTime :updated_at, null: false, default: Sequel::CURRENT_TIMESTAMP"
      when :last_use, :last_activity_at, :last_login_at
        "Time :#{column}, null: false, default: Sequel::CURRENT_TIMESTAMP"
      when :num_failures, :number, :sign_count
        "Integer :#{column}, null: false, default: 0"
      when :code
        "String :code, null: false"
      when :phone_number, :login
        "String :#{column}, null: false"
      when :code_issued_at, :changed_at, :expired_at, :at, :email_last_sent
        "DateTime :#{column}"
      when :public_key, :metadata
        "String :#{column}, text: true"
      when :webauthn_id, :session_id
        "String :#{column}, null: false"
      when :message
        "String :message, null: false"
      else
        # Default: string column
        "String :#{column}"
      end
    end

    # Generate index definition
    #
    # @param columns [Array<Symbol>] Index columns
    # @param structure [Hash] Table structure
    # @return [String] Sequel index definition
    def generate_index_definition(columns, structure)
      column_list = columns.map(&:inspect).join(", ")

      if columns == [:email] && structure[:type] == :primary
        if supports_partial_indexes?
          "index :email, unique: true, where: { status: [1, 2] }"
        else
          "index :email, unique: true"
        end
      elsif columns.length == 1
        "index :#{columns.first}"
      else
        "index [#{column_list}]"
      end
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
