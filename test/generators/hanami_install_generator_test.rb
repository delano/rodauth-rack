# frozen_string_literal: true

require "bundler/setup"
require "minitest/autorun"
require "minitest/pride"
require "tmpdir"
require "fileutils"
require "dry/inflector"
require_relative "../../lib/generators/rodauth/hanami_install/hanami_install_generator"

class HanamiInstallGeneratorTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @original_dir = Dir.pwd
    Dir.chdir(@tmpdir)
  end

  def teardown
    Dir.chdir(@original_dir)
    FileUtils.rm_rf(@tmpdir)
  end

  def test_generator_creates_provider_file
    generator = Rodauth::Generators::HanamiInstallGenerator.new

    silence_io do
      generator.create_provider
    end

    assert File.exist?("config/providers/rodauth.rb")

    content = File.read("config/providers/rodauth.rb")
    assert_includes content, "Hanami.app.register_provider :rodauth"
    assert_includes content, "require \"rodauth/rack/hanami\""
    assert_includes content, "Rodauth::Rack::Hanami::Middleware"
  end

  def test_generator_creates_rodauth_app_file
    generator = Rodauth::Generators::HanamiInstallGenerator.new

    silence_io do
      generator.create_rodauth_app
    end

    assert File.exist?("lib/rodauth_app.rb")

    content = File.read("lib/rodauth_app.rb")
    assert_includes content, "class RodauthApp < Rodauth::Rack::Hanami::App"
    assert_includes content, "configure RodauthMain"
    assert_includes content, "r.rodauth"
  end

  def test_generator_creates_rodauth_main_file
    generator = Rodauth::Generators::HanamiInstallGenerator.new

    silence_io do
      generator.create_rodauth_main
    end

    assert File.exist?("lib/rodauth_main.rb")

    content = File.read("lib/rodauth_main.rb")
    assert_includes content, "class RodauthMain < Rodauth::Rack::Hanami::Auth"
    assert_includes content, "enable :hanami"
    assert_includes content, "accounts_table :accounts"
  end

  def test_generator_with_json_option
    generator = Rodauth::Generators::HanamiInstallGenerator.new(json: true)

    silence_io do
      generator.create_rodauth_main
    end

    content = File.read("lib/rodauth_main.rb")
    assert_includes content, "enable :json"
    assert_includes content, "json_response_success_key :data"
  end

  def test_generator_with_jwt_option
    generator = Rodauth::Generators::HanamiInstallGenerator.new(jwt: true)

    silence_io do
      generator.create_rodauth_main
    end

    content = File.read("lib/rodauth_main.rb")
    assert_includes content, "enable :jwt, :jwt_refresh"
    assert_includes content, "jwt_secret"
  end

  def test_generator_with_argon2_option
    generator = Rodauth::Generators::HanamiInstallGenerator.new(argon2: true)

    silence_io do
      generator.create_rodauth_main
    end

    content = File.read("lib/rodauth_main.rb")
    assert_includes content, 'require "argon2"'
    assert_includes content, "password_hash_cost"
  end

  def test_generator_with_custom_table_prefix
    generator = Rodauth::Generators::HanamiInstallGenerator.new(table: "user")

    silence_io do
      generator.create_rodauth_main
    end

    content = File.read("lib/rodauth_main.rb")
    assert_includes content, "accounts_table :users"
  end

  def test_full_generator_run
    generator = Rodauth::Generators::HanamiInstallGenerator.new

    silence_io do
      generator.create_provider
      generator.create_rodauth_app
      generator.create_rodauth_main
    end

    assert File.exist?("config/providers/rodauth.rb")
    assert File.exist?("lib/rodauth_app.rb")
    assert File.exist?("lib/rodauth_main.rb")
  end

  private

  def silence_io
    old_stdout = $stdout
    old_stderr = $stderr
    $stdout = StringIO.new
    $stderr = StringIO.new
    yield
  ensure
    $stdout = old_stdout
    $stderr = old_stderr
  end
end
