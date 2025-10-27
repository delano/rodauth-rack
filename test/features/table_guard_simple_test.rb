# frozen_string_literal: true

require "bundler/setup"
require "minitest/autorun"
require "minitest/pride"
require "sequel"
require "rodauth"
require "roda"
require_relative "../../lib/rodauth/rack"

class TableGuardSimpleTest < Minitest::Test
  def setup
    @db = Sequel.sqlite
  end

  def teardown
    @db.disconnect if @db
  end

  def test_feature_can_be_enabled
    app = create_roda_app do
      enable :table_guard
    end

    assert app
  end

  def test_error_mode_raises_with_missing_tables
    error = assert_raises(Rodauth::ConfigurationError) do
      create_roda_app do
        enable :login, :logout
        enable :table_guard
        table_guard_mode :error
      end
    end

    assert_includes error.message, "Missing required database tables"
    assert_includes error.message, "accounts"
  end

  def test_error_mode_succeeds_when_all_tables_exist
    create_accounts_table(@db)

    app = create_roda_app do
      enable :login, :logout
      enable :table_guard
      table_guard_mode :error
    end

    assert app
  end

  def test_silent_mode_does_not_raise
    app = create_roda_app do
      enable :login, :logout
      enable :table_guard
      table_guard_mode :silent
    end

    assert app
  end

  def test_warn_mode_warns_about_missing_tables
    output = capture_warnings do
      create_roda_app do
        enable :login, :logout
        enable :table_guard
        table_guard_mode :warn
      end
    end

    assert_includes output, "Missing required database tables"
    assert_includes output, "accounts"
  end

  def test_block_handler_continues_without_error
    block_called = false
    received_missing = nil

    app = create_roda_app do
      enable :login
      enable :table_guard
      table_guard_mode do |missing|
        block_called = true
        received_missing = missing
        :continue
      end
    end

    assert app
    assert block_called
    assert received_missing
  end

  def test_block_handler_raises_error_on_error_return
    error = assert_raises(Rodauth::ConfigurationError) do
      create_roda_app do
        enable :login
        enable :table_guard
        table_guard_mode do |missing|
          :error
        end
      end
    end

    assert_includes error.message, "Missing required database tables"
  end

  def test_block_handler_raises_custom_message
    custom_message = "Custom error: Please run migrations!"

    error = assert_raises(Rodauth::ConfigurationError) do
      create_roda_app do
        enable :login
        enable :table_guard
        table_guard_mode do |missing|
          custom_message
        end
      end
    end

    assert_equal custom_message, error.message
  end

  def test_invalid_mode_raises_error
    error = assert_raises(Rodauth::ConfigurationError) do
      create_roda_app do
        enable :table_guard
        table_guard_mode :invalid_mode
      end
    end

    assert_includes error.message, "Invalid table_guard_mode"
  end

  def test_table_guard_disabled_by_default
    app = create_roda_app do
      enable :login
      enable :table_guard
      # No mode specified
    end

    assert app
  end

  private

  def create_roda_app(&rodauth_block)
    db = @db

    Class.new(Roda) do
      plugin :rodauth do
        self.db db
        instance_eval(&rodauth_block) if rodauth_block
      end

      route do |r|
        r.rodauth
      end
    end
  end

  def create_accounts_table(db)
    db.create_table :accounts do
      primary_key :id
      String :email, null: false, unique: true
      String :status, default: "unverified"
    end

    db.create_table :account_password_hashes do
      foreign_key :id, :accounts, primary_key: true
      String :password_hash, null: false
    end
  end

  def capture_warnings
    old_stderr = $stderr
    $stderr = StringIO.new
    yield
    $stderr.string
  ensure
    $stderr = old_stderr
  end
end
