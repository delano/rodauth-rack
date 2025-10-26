# frozen_string_literal: true

module Rodauth
  module Rack
    # Simple CLI for Rodauth generators
    # Usage: rodauth generate hanami:install
    class CLI
      GENERATORS = {
        "hanami:install" => "generators/rodauth/hanami_install/hanami_install_generator",
        "migration" => "rodauth/rack/generators/migration"
      }.freeze

      def self.run(args = ARGV)
        new(args).run
      end

      def initialize(args)
        @args = args
        @command = args[0]
        @generator_name = args[1]
        @options = parse_options(args[2..-1] || [])
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
          puts "Migration generator not yet integrated with CLI"
          puts "Use: require 'rodauth/rack/generators/migration' directly for now"
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

          Options:
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

          For more information: https://github.com/delano/rodauth-rack
        HELP
      end
    end
  end
end
