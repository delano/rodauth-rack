# frozen_string_literal: true
# lib/rodauth/tools/migration.rb
require 'erb'
require 'dry/inflector'

module Rodauth
  module Tools
    # Sequel migration generator for Rodauth database tables.
    #
    # @deprecated This static migration generator is deprecated in favor of
    #   the dynamic table_guard feature with sequel generation modes.
    #   Use table_guard_sequel_mode instead for automatic migration generation.
    #
    # Generates migrations for Sequel ORM, supporting
    # PostgreSQL, MySQL, and SQLite databases.
    #
    # @example Generate a migration (DEPRECATED)
    #   generator = Rodauth::Tools::Migration.new(
    #     features: [:base, :verify_account, :otp],
    #     prefix: "account",
    #     db_adapter: :postgresql
    #   )
    #
    #   generator.generate # => migration content
    #
    # @example Use table_guard instead (RECOMMENDED)
    #   plugin :rodauth do
    #     enable :base, :verify_account, :otp, :table_guard
    #     table_guard_sequel_mode :migration
    #   end
    class Migration
      attr_reader :features, :prefix, :db_adapter, :db

      # Initialize the migration generator
      #
      # @param features [Array<Symbol>] List of Rodauth features to generate tables for
      # @param prefix [String] Table name prefix (default: "account")
      # @param db_adapter [Symbol] Database adapter (:postgresql, :mysql2, :sqlite3)
      # @param db [Sequel::Database] Sequel database connection
      def initialize(features:, prefix: nil, db_adapter: nil, db: nil)
        @features = Array(features).map(&:to_sym)
        @prefix = prefix
        @db_adapter = db_adapter&.to_sym
        @db = db || create_mock_db

        validate_features!
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

      # Get the migration name
      #
      # @return [String] Migration name
      def migration_name
        parts = ['create_rodauth']
        parts << prefix if prefix && prefix != 'account'
        parts.concat(features)
        parts.join('_')
      end

      private

      def validate_features!
        return if features.any?

        raise ArgumentError, 'No features specified'
      end

      def validate_feature_templates!
        features.each do |feature|
          template_path = File.join(template_directory, "#{feature}.erb")
          raise ArgumentError, "No migration template for feature: #{feature}" unless File.exist?(template_path)
        end
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
        ERB.new(content, trim_mode: '-').result(binding)
      end

      def template_directory
        File.join(__dir__, 'migration', 'sequel')
      end

      def table_prefix
        (@prefix || 'account').to_s
      end

      # Helper method for templates to pluralize table names
      def pluralize(str)
        inflector.pluralize(str)
      end

      # Cached inflector instance
      def inflector
        @inflector ||= Dry::Inflector.new
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
