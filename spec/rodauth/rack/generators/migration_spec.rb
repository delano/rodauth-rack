# frozen_string_literal: true

require "spec_helper"

RSpec.describe Rodauth::Rack::Generators::Migration do
  describe "#initialize" do
    it "accepts features as an array" do
      generator = described_class.new(features: [:base, :verify_account])
      expect(generator.features).to eq([:base, :verify_account])
    end

    it "converts features to symbols" do
      generator = described_class.new(features: ["base", "otp"])
      expect(generator.features).to eq([:base, :otp])
    end

    it "defaults to sequel ORM" do
      generator = described_class.new(features: [:base])
      expect(generator.orm).to eq(:sequel)
    end

    it "accepts custom ORM" do
      generator = described_class.new(features: [:base], orm: :active_record)
      expect(generator.orm).to eq(:active_record)
    end

    it "accepts custom prefix" do
      generator = described_class.new(features: [:base], prefix: "user")
      expect(generator.prefix).to eq("user")
    end

    it "accepts database adapter" do
      generator = described_class.new(features: [:base], db_adapter: :postgresql)
      expect(generator.db_adapter).to eq(:postgresql)
    end

    it "raises error when no features specified" do
      expect {
        described_class.new(features: [])
      }.to raise_error(ArgumentError, /No features specified/)
    end

    it "raises error for invalid ORM" do
      expect {
        described_class.new(features: [:base], orm: :mongoid)
      }.to raise_error(ArgumentError, /Invalid ORM/)
    end
  end

  describe "#configuration" do
    it "returns configuration for base feature" do
      generator = described_class.new(features: [:base], prefix: "account")
      config = generator.configuration

      expect(config).to eq(accounts_table: "accounts")
    end

    it "returns configuration for multiple features" do
      generator = described_class.new(features: [:base, :remember], prefix: "account")
      config = generator.configuration

      expect(config).to include(
        accounts_table: "accounts",
        remember_table: "account_remember_keys"
      )
    end

    it "handles custom table prefix" do
      generator = described_class.new(features: [:base, :otp], prefix: "user")
      config = generator.configuration

      expect(config).to include(
        accounts_table: "users",
        otp_keys_table: "user_otp_keys"
      )
    end

    it "includes all configuration for webauthn feature" do
      generator = described_class.new(features: [:webauthn], prefix: "account")
      config = generator.configuration

      expect(config).to include(
        webauthn_keys_table: "account_webauthn_keys",
        webauthn_user_ids_table: "account_webauthn_user_ids",
        webauthn_keys_account_id_column: "account_id"
      )
    end

    it "includes all configuration for lockout feature" do
      generator = described_class.new(features: [:lockout], prefix: "account")
      config = generator.configuration

      expect(config).to include(
        account_login_failures_table: "account_login_failures",
        account_lockouts_table: "account_lockouts"
      )
    end
  end

  describe "#migration_name" do
    it "generates migration name with default prefix" do
      generator = described_class.new(features: [:base, :verify_account])
      expect(generator.migration_name).to eq("create_rodauth_base_verify_account")
    end

    it "generates migration name with custom prefix" do
      generator = described_class.new(features: [:base], prefix: "user")
      expect(generator.migration_name).to eq("create_rodauth_user_base")
    end

    it "generates migration name for single feature" do
      generator = described_class.new(features: [:otp])
      expect(generator.migration_name).to eq("create_rodauth_otp")
    end
  end

  describe "#generate" do
    context "with Sequel ORM" do
      it "generates migration for base feature" do
        generator = described_class.new(features: [:base], orm: :sequel)
        migration = generator.generate

        expect(migration).to include("create_table :accounts")
        expect(migration).to include("primary_key :id")
        expect(migration).to include("Integer :status")
        expect(migration).to include("String :password_hash")
      end

      it "generates migration for verify_account feature" do
        generator = described_class.new(features: [:verify_account], orm: :sequel)
        migration = generator.generate

        expect(migration).to include("create_table :account_verification_keys")
      end

      it "generates migration for multiple features" do
        generator = described_class.new(features: [:base, :remember], orm: :sequel)
        migration = generator.generate

        expect(migration).to include("create_table :accounts")
        expect(migration).to include("create_table :account_remember_keys")
      end

      it "uses custom table prefix" do
        generator = described_class.new(features: [:base], orm: :sequel, prefix: "user")
        migration = generator.generate

        expect(migration).to include("create_table :users")
      end
    end

    context "with ActiveRecord ORM" do
      it "generates migration for base feature" do
        generator = described_class.new(features: [:base], orm: :active_record)
        migration = generator.generate

        expect(migration).to include("create_table :accounts")
        expect(migration).to include("t.integer :status")
        expect(migration).to include("t.string :password_hash")
      end

      it "generates migration for verify_account feature" do
        generator = described_class.new(features: [:verify_account], orm: :active_record)
        migration = generator.generate

        expect(migration).to include("create_table :account_verification_keys")
      end

      it "generates migration with PostgreSQL adapter" do
        generator = described_class.new(
          features: [:base],
          orm: :active_record,
          db_adapter: :postgresql
        )
        migration = generator.generate

        expect(migration).to include('enable_extension "citext"')
        expect(migration).to include("t.citext :email")
      end

      it "generates migration with MySQL adapter" do
        generator = described_class.new(
          features: [:base],
          orm: :active_record,
          db_adapter: :mysql2
        )
        migration = generator.generate

        expect(migration).to include("t.string :email")
        expect(migration).not_to include("citext")
      end

      it "generates migration with SQLite adapter" do
        generator = described_class.new(
          features: [:base],
          orm: :active_record,
          db_adapter: :sqlite3
        )
        migration = generator.generate

        expect(migration).to include("t.string :email")
      end
    end

    context "with invalid features" do
      it "raises error for unknown feature" do
        expect {
          described_class.new(features: [:unknown_feature])
        }.to raise_error(ArgumentError, /No migration template/)
      end
    end
  end

  describe "all available features" do
    let(:all_features) do
      [
        :base, :remember, :verify_account, :verify_login_change,
        :reset_password, :email_auth, :otp, :otp_unlock, :sms_codes,
        :recovery_codes, :webauthn, :lockout, :active_sessions,
        :account_expiration, :password_expiration, :single_session,
        :audit_logging, :disallow_password_reuse, :jwt_refresh
      ]
    end

    it "has templates for all 19 features in ActiveRecord" do
      all_features.each do |feature|
        expect {
          described_class.new(features: [feature], orm: :active_record)
        }.not_to raise_error
      end
    end

    it "has templates for all 19 features in Sequel" do
      all_features.each do |feature|
        expect {
          described_class.new(features: [feature], orm: :sequel)
        }.not_to raise_error
      end
    end

    it "has configuration for all features" do
      all_features.each do |feature|
        generator = described_class.new(features: [feature])
        expect(generator.configuration).not_to be_empty
      end
    end
  end
end
