# frozen_string_literal: true

require "securerandom"

module Rodauth
  module Generators
    class HanamiInstallGenerator
      SEQUEL_ADAPTERS = {
        "postgresql" => RUBY_ENGINE == "jruby" ? "postgresql" : "postgres",
        "mysql2" => RUBY_ENGINE == "jruby" ? "mysql" : "mysql2",
        "sqlite3" => "sqlite",
        "oracle_enhanced" => "oracle",
        "sqlserver" => RUBY_ENGINE == "jruby" ? "mssql" : "tinytds"
      }.freeze

      attr_reader :options

      def initialize(options = {})
        @options = options
      end

      def self.source_root
        "#{__dir__}/templates"
      end

      def generate
        create_provider
        create_rodauth_app
        create_rodauth_main
        add_dependencies
        show_instructions
      end

      def create_provider
        template("config/providers/rodauth.rb.tt", "config/providers/rodauth.rb")
      end

      def create_rodauth_app
        template("lib/rodauth_app.rb.tt", "lib/rodauth_app.rb")
      end

      def create_rodauth_main
        template("lib/rodauth_main.rb.tt", "lib/rodauth_main.rb")
      end

      def add_dependencies
        puts "\n" + "=" * 80
        puts "Add these dependencies to your Gemfile:"
        puts "=" * 80

        puts "\n# Rodauth authentication"
        puts "gem 'rodauth-rack', '~> 1.0'"
        puts "gem 'tilt', '~> 2.4'  # For rendering Rodauth templates"

        if argon2?
          puts "gem 'argon2', '~> 2.3'  # Password hashing"
        else
          puts "gem 'bcrypt', '~> 3.1'  # Password hashing"
        end

        puts "gem 'jwt', '~> 2.9'  # JWT support" if jwt?

        if rom?
          puts "\n# Already using ROM (detected)"
        else
          puts "\ngem 'sequel', '~> 5.85'  # Database toolkit"
        end

        puts "\n" + "=" * 80
      end

      def show_instructions
        return if json? || jwt?

        puts "\n" + "=" * 80
        puts "NEXT STEPS"
        puts "=" * 80
        puts <<~INSTRUCTIONS

          1. Generate the database migration:

             rodauth generate migration base reset_password verify_account

          2. Run the migration:

             bundle exec hanami db migrate

          3. Configure your database connection in config/app.rb if needed

          4. Start your Hanami app:

             bundle exec hanami server

          5. Visit http://localhost:2300/login to see Rodauth in action

          6. Generate views to customize the UI:

             rodauth generate hanami:views

          For more information, see: https://github.com/delano/rodauth-rack

        INSTRUCTIONS
        puts "=" * 80
      end

      private

      def template(source, destination)
        content = File.read(File.join(self.class.source_root, source))
        output = evaluate_template(content)

        FileUtils.mkdir_p(File.dirname(destination))
        File.write(destination, output)

        puts "Created: #{destination}"
      end

      def evaluate_template(content)
        require "erb"
        ERB.new(content, trim_mode: "-").result(binding)
      end

      def table_prefix
        prefix = options[:prefix] || options[:table]
        return "account" unless prefix

        # Simple inflection without ActiveSupport
        inflector = Dry::Inflector.new
        inflector.singularize(inflector.underscore(prefix.to_s))
      end

      def pluralize(word)
        require "dry/inflector"
        Dry::Inflector.new.pluralize(word)
      end

      def json?
        options[:json] || (api_only? && !options[:jwt])
      end

      def jwt?
        options[:jwt]
      end

      def argon2?
        options[:argon2]
      end

      def api_only?
        options[:api_only]
      end

      def rom?
        defined?(ROM)
      end

      def sequel_adapter
        # Try to detect from Hanami configuration
        if defined?(Hanami) && Hanami.app
          adapter = detect_hanami_adapter
          SEQUEL_ADAPTERS[adapter] || adapter
        else
          "postgres"
        end
      end

      def detect_hanami_adapter
        # This would need to introspect Hanami's database configuration
        # For now, default to postgres
        "postgres"
      end
    end
  end
end
