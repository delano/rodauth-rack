# frozen_string_literal: true

require "bundler/setup"
require "minitest/autorun"
require "sequel"
require "rodauth"
require "roda"
require_relative "../../lib/rodauth/rack"

class TableGuardIntegrationTest < Minitest::Test
  def test_error_mode_raises_during_configuration
    db = Sequel.sqlite

    error = assert_raises(Rodauth::ConfigurationError) do
      Class.new(Roda) do
        plugin :rodauth do
          self.db db
          enable :login, :logout
          enable :table_guard
          table_guard_mode :error
        end

        route do |r|
          r.rodauth
        end
      end
    end

    assert_includes error.message, "Missing required database tables"
    assert_includes error.message, "accounts"
  end

  def test_works_when_tables_exist
    db = Sequel.sqlite
    create_all_tables(db)

    app = Class.new(Roda) do
      plugin :rodauth do
        self.db db
        enable :login, :logout
        enable :table_guard
        table_guard_mode :error
      end

      route do |r|
        r.rodauth
      end
    end

    assert app
  end

  def test_silent_mode_does_not_raise
    db = Sequel.sqlite

    app = Class.new(Roda) do
      plugin :rodauth do
        self.db db
        enable :login, :logout
        enable :table_guard
        table_guard_mode :silent
      end

      route do |r|
        r.rodauth
      end
    end

    assert app
  end

  def test_disabled_by_default
    db = Sequel.sqlite

    app = Class.new(Roda) do
      plugin :rodauth do
        self.db db
        enable :login
        enable :table_guard
        # No mode set
      end

      route do |r|
        r.rodauth
      end
    end

    assert app
  end

  private

  def create_all_tables(db)
    db.create_table :accounts do
      primary_key :id
      String :email, null: false
      String :status, default: "unverified"
    end

    db.create_table :account_password_hashes do
      foreign_key :id, :accounts, primary_key: true
      String :password_hash, null: false
    end
  end
end
