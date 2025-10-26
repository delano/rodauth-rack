# frozen_string_literal: true

module Rodauth
  module Rack
    # Simple CLI for Rodauth generators
    # Usage: rodauth generate hanami:install
    class CLI
      GENERATORS = {
        "hanami:install" => "generators/rodauth/hanami_install/hanami_install_generator",
        "migration" => "generators/migration"
      }.freeze

      def self.run(args = ARGV)
        new(args).run
      end

      def initialize(args)
        @args = args
        @command = args[0]
        @generator_name = args[1]
        @generator_args = []
        @options = {}

        if @generator_name == "migration"
          # For migration, args after generator name are features
          @generator_args = args[2..-1] || []
        else
          @options = parse_options(args[2..-1] || [])
        end
      end

      def run
        case @command
        when "generate", "g"
          generate
        when "help", "--help", "-h", nil
          show_help
        else
          puts "Unknown command: #{@command}"
          show_help
          exit 1
        end
      end

      private

      def generate_migration
        unless @generator_args.any?
          puts "Error: At least one feature required"
          puts "Usage: rr generate migration FEATURE [FEATURE...]"
          puts ""
          puts "Available features:"
          puts "  base, remember, verify_account, verify_login_change,"
          puts "  reset_password, email_auth, otp, otp_unlock, sms_codes,"
          puts "  recovery_codes, webauthn, lockout, active_sessions,"
          puts "  audit_logging, jwt_refresh, single_session,"
          puts "  account_expiration, password_expiration, disallow_password_reuse"
          exit 1
        end

        # Convert feature names to symbols
        features = @generator_args.map(&:to_sym)

        # Detect ORM (prefer Sequel)
        orm = detect_orm

        # Create generator
        generator = Rodauth::Rack::Generators::Migration.new(
          features: features,
          orm: orm,
          prefix: "account",
          db_adapter: :postgresql  # Default, could be made configurable
        )

        # Create migration file
        timestamp = Time.now.utc.strftime('%Y%m%d%H%M%S')
        filename = "#{timestamp}_create_rodauth.rb"
        migration_dir = "db/migrate"

        # Create directory if it doesn't exist
        require "fileutils"
        FileUtils.mkdir_p(migration_dir)

        # Generate migration content with proper wrapper
        content = if orm == :sequel
          sequel_migration_wrapper(generator.generate)
        else
          activerecord_migration_wrapper(generator.generate, timestamp)
        end

        # Write migration file
        filepath = File.join(migration_dir, filename)
        File.write(filepath, content)

        puts "Created migration: #{filepath}"
      end

      def sequel_migration_wrapper(migration_content)
        lines = migration_content.lines.map { |line| "    #{line.rstrip}" }.join("\n")
        <<~MIGRATION
          Sequel.migration do
            change do
          #{lines}
            end
          end
        MIGRATION
      end

      def activerecord_migration_wrapper(migration_content, timestamp)
        class_name = "CreateRodauth#{timestamp}"
        lines = migration_content.lines.map { |line| "    #{line.rstrip}" }.join("\n")
        <<~MIGRATION
          class #{class_name} < ActiveRecord::Migration[7.0]
            def change
          #{lines}
            end
          end
        MIGRATION
      end

      def detect_orm
        # Check if ROM is available
        if defined?(ROM)
          :sequel  # ROM uses Sequel
        elsif defined?(ActiveRecord)
          :active_record
        elsif defined?(Sequel)
          :sequel
        else
          :sequel  # Default to Sequel
        end
      end

      def generate
        unless @generator_name
          puts "Error: Generator name required"
          puts "Usage: rodauth generate GENERATOR [options]"
          exit 1
        end

        generator_path = GENERATORS[@generator_name]
        unless generator_path
          puts "Error: Unknown generator '#{@generator_name}'"
          puts "Available generators: #{GENERATORS.keys.join(', ')}"
          exit 1
        end

        require_relative generator_path

        case @generator_name
        when "hanami:install"
          Rodauth::Generators::HanamiInstallGenerator.new(@options).generate
        when "migration"
          generate_migration
        end
      end

      def parse_options(args)
        options = {}

        args.each do |arg|
          case arg
          when "--json"
            options[:json] = true
          when "--jwt"
            options[:jwt] = true
          when "--argon2"
            options[:argon2] = true
          when "--api-only"
            options[:api_only] = true
          when /--prefix=(.+)/
            options[:prefix] = $1
          when /--table=(.+)/
            options[:table] = $1
          end
        end

        options
      end

      def show_help
        puts <<~HELP
          Rodauth-Rack Generators CLI

          Usage:
            rr generate GENERATOR [options]
            rr g GENERATOR [options]

          Available Generators:
            hanami:install    Generate Rodauth configuration for Hanami 2.x apps
            migration         Generate database migration for Rodauth features

          Options (for hanami:install):
            --json           Configure JSON API support
            --jwt            Configure JWT authentication
            --argon2         Use Argon2 for password hashing (instead of bcrypt)
            --api-only       Configure for API-only application
            --prefix=NAME    Set custom prefix for account tables
            --table=NAME     Set custom name for accounts table

          Examples:
            # Basic Hanami installation
            rr generate hanami:install

            # API-only with JWT
            rr generate hanami:install --jwt --api-only

            # JSON API with custom table
            rr generate hanami:install --json --table=user

            # With Argon2 password hashing
            rr generate hanami:install --argon2

            # Generate migration for basic features
            rr generate migration base reset_password verify_account

            # Generate migration for additional features
            rr generate migration otp recovery_codes webauthn

          For more information: https://github.com/delano/rodauth-rack
        HELP
      end
    end
  end
end
