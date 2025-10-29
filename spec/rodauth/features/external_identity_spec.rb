# frozen_string_literal: true

require "spec_helper"
require "sequel"
require "rodauth"
require "roda"

RSpec.describe "Rodauth external_identity feature" do
  let(:db) { Sequel.sqlite }

  after do
    db.disconnect if db
  end

  def create_roda_app(&rodauth_block)
    test_db = db

    Class.new(Roda) do
      plugin :rodauth do
        self.db test_db
        instance_eval(&rodauth_block) if rodauth_block
      end

      route do |r|
        r.rodauth
      end
    end
  end

  # Helper to create accounts table with external identity columns
  def create_accounts_table_with_columns(columns: [])
    db.create_table :accounts do
      primary_key :id
      String :email, null: false, unique: true
      String :status, default: "unverified"

      # Add external identity columns
      columns.each do |col|
        String col
      end
    end

    db.create_table :account_password_hashes do
      foreign_key :id, :accounts, primary_key: true
      String :password_hash, null: false
    end
  end

  describe "configuration methods" do
    context "single column declaration" do
      it "declares a column with default naming" do
        create_accounts_table_with_columns(columns: [:stripe_id])
        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :stripe
        end

        rodauth = app_class.allocate.rodauth
        expect(rodauth.external_identity_column_list).to eq([:stripe])
        expect(rodauth.external_identity_column_config(:stripe)).to include(
          column: :stripe_id,
          method_name: :account_stripe_id,
          include_in_select: true
        )
      end

      it "declares a column with explicit column name" do
        create_accounts_table_with_columns(columns: [:stripe_customer_id])
        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :stripe, :stripe_customer_id
        end

        rodauth = app_class.allocate.rodauth
        expect(rodauth.external_identity_column_config(:stripe)[:column]).to eq(:stripe_customer_id)
      end

      it "declares a column with custom method name" do
        create_accounts_table_with_columns(columns: [:stripe_id])
        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :stripe, method_name: :stripe_identifier
        end

        rodauth = app_class.allocate.rodauth
        expect(rodauth.external_identity_column_config(:stripe)[:method_name]).to eq(:stripe_identifier)
      end
    end

    context "multiple column declarations" do
      it "declares multiple columns" do
        create_accounts_table_with_columns(columns: [:stripe_id, :redis_id, :auth0_id])
        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :stripe
          external_identity_column :redis
          external_identity_column :auth0
        end

        rodauth = app_class.allocate.rodauth
        expect(rodauth.external_identity_column_list).to match_array([:stripe, :redis, :auth0])
      end

      it "maintains declaration order" do
        create_accounts_table_with_columns(columns: [:stripe_id, :redis_id])
        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :stripe
          external_identity_column :redis
        end

        rodauth = app_class.allocate.rodauth
        expect(rodauth.external_identity_column_list).to eq([:stripe, :redis])
      end
    end

    context "custom method names" do
      it "accepts valid Ruby identifier" do
        create_accounts_table_with_columns(columns: [:stripe_id])
        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :stripe, method_name: :my_stripe_id
        end

        rodauth = app_class.allocate.rodauth
        expect(rodauth.external_identity_helper_methods).to include(:my_stripe_id)
      end

      it "accepts method names with underscores" do
        create_accounts_table_with_columns(columns: [:stripe_id])
        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :stripe, method_name: :account_stripe_customer_id
        end

        rodauth = app_class.allocate.rodauth
        expect(rodauth.external_identity_helper_methods).to include(:account_stripe_customer_id)
      end

      it "accepts method names with question marks" do
        create_accounts_table_with_columns(columns: [:stripe_id])
        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :stripe, method_name: :has_stripe?
        end

        rodauth = app_class.allocate.rodauth
        expect(rodauth.external_identity_helper_methods).to include(:has_stripe?)
      end
    end

    context "invalid method names" do
      it "rejects non-symbol names" do
        create_accounts_table_with_columns(columns: [:stripe_id])

        expect {
          create_roda_app do
            enable :external_identity
            external_identity_column "stripe"
          end
        }.to raise_error(ArgumentError, /must be a Symbol/)
      end

      it "rejects invalid Ruby identifiers" do
        create_accounts_table_with_columns(columns: [:stripe_id])

        expect {
          create_roda_app do
            enable :external_identity
            external_identity_column :"stripe-id"
          end
        }.to raise_error(ArgumentError, /must be a valid Ruby identifier/)
      end

      it "rejects method names starting with numbers" do
        create_accounts_table_with_columns(columns: [:stripe_id])

        expect {
          create_roda_app do
            enable :external_identity
            external_identity_column :stripe, method_name: :"123_stripe"
          end
        }.to raise_error(ArgumentError, /must be a valid Ruby identifier/)
      end

      it "rejects method names with invalid special characters" do
        create_accounts_table_with_columns(columns: [:stripe_id])

        expect {
          create_roda_app do
            enable :external_identity
            external_identity_column :stripe, method_name: :"stripe@id"
          end
        }.to raise_error(ArgumentError, /must be a valid Ruby identifier/)
      end
    end

    context "duplicate column declarations" do
      it "raises error on duplicate declaration" do
        create_accounts_table_with_columns(columns: [:stripe_id])

        expect {
          create_roda_app do
            enable :external_identity
            external_identity_column :stripe
            external_identity_column :stripe
          end
        }.to raise_error(ArgumentError, /already declared/)
      end

      it "allows same column with different names" do
        create_accounts_table_with_columns(columns: [:stripe_id])
        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :stripe, :stripe_id
          external_identity_column :stripe_alt, :stripe_id, method_name: :alternate_stripe_id
        end

        rodauth = app_class.allocate.rodauth
        expect(rodauth.external_identity_column_list).to match_array([:stripe, :stripe_alt])
      end
    end

    context "options validation" do
      it "accepts include_in_select option" do
        create_accounts_table_with_columns(columns: [:stripe_id])
        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :stripe, include_in_select: false
        end

        rodauth = app_class.allocate.rodauth
        expect(rodauth.external_identity_column_config(:stripe)[:include_in_select]).to be false
      end

      it "accepts override option" do
        create_accounts_table_with_columns(columns: [:stripe_id])
        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :stripe, override: true
        end

        rodauth = app_class.allocate.rodauth
        expect(rodauth.external_identity_column_config(:stripe)[:override]).to be true
      end

      it "accepts validate option" do
        create_accounts_table_with_columns(columns: [:stripe_id])
        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :stripe, validate: true
        end

        rodauth = app_class.allocate.rodauth
        expect(rodauth.external_identity_column_config(:stripe)[:validate]).to be true
      end
    end
  end

  describe "account_select integration" do
    it "adds columns to account_select" do
      create_accounts_table_with_columns(columns: [:stripe_id, :redis_id])
      app_class = create_roda_app do
        enable :external_identity
        external_identity_column :stripe
        external_identity_column :redis
      end

      rodauth = app_class.allocate.rodauth
      select_cols = rodauth.account_select
      expect(select_cols).to include(:stripe_id, :redis_id)
    end

    it "does not add duplicates to account_select" do
      create_accounts_table_with_columns(columns: [:stripe_id])
      app_class = create_roda_app do
        enable :external_identity
        external_identity_column :stripe
        external_identity_column :stripe_alt, :stripe_id, method_name: :alt_stripe
      end

      rodauth = app_class.allocate.rodauth
      select_cols = rodauth.account_select
      expect(select_cols.count(:stripe_id)).to eq(1)
    end

    it "respects include_in_select: false option" do
      create_accounts_table_with_columns(columns: [:stripe_id, :redis_id])
      app_class = create_roda_app do
        enable :external_identity
        external_identity_column :stripe, include_in_select: false
        external_identity_column :redis
      end

      rodauth = app_class.allocate.rodauth
      select_cols = rodauth.account_select
      expect(select_cols).not_to include(:stripe_id)
      expect(select_cols).to include(:redis_id)
    end

    it "works with other Rodauth features" do
      create_accounts_table_with_columns(columns: [:stripe_id])
      app_class = create_roda_app do
        enable :login
        enable :external_identity
        external_identity_column :stripe
      end

      rodauth = app_class.allocate.rodauth
      select_cols = rodauth.account_select
      # Verify that external_identity column is included
      expect(select_cols).to include(:stripe_id)
      # Verify that the feature works alongside other Rodauth features
      expect(app_class).not_to be_nil
    end

    it "preserves order of columns" do
      create_accounts_table_with_columns(columns: [:stripe_id, :redis_id, :auth0_id])
      app_class = create_roda_app do
        enable :external_identity
        external_identity_column :stripe
        external_identity_column :redis
        external_identity_column :auth0
      end

      rodauth = app_class.allocate.rodauth
      select_cols = rodauth.account_select

      # External identity columns should be added in order
      stripe_idx = select_cols.index(:stripe_id)
      redis_idx = select_cols.index(:redis_id)
      auth0_idx = select_cols.index(:auth0_id)

      expect(stripe_idx).to be < redis_idx
      expect(redis_idx).to be < auth0_idx
    end
  end

  describe "helper method generation" do
    it "generates helper methods with correct names" do
      create_accounts_table_with_columns(columns: [:stripe_id, :redis_id])
      db[:accounts].insert(email: 'test@example.com', stripe_id: 'cus_abc123', redis_id: 'redis-uuid-456')

      app_class = create_roda_app do
        enable :external_identity
        external_identity_column :stripe
        external_identity_column :redis
      end

      rodauth = app_class.allocate.rodauth
      expect(rodauth.respond_to?(:account_stripe_id)).to be true
      expect(rodauth.respond_to?(:account_redis_id)).to be true
    end

    it "helper methods return correct values" do
      create_accounts_table_with_columns(columns: [:stripe_id, :redis_id])
      db[:accounts].insert(email: 'test@example.com', stripe_id: 'cus_abc123', redis_id: 'redis-uuid-456')

      app_class = create_roda_app do
        enable :external_identity
        external_identity_column :stripe
        external_identity_column :redis
      end

      rodauth = app_class.allocate.rodauth
      rodauth.instance_variable_set(:@account, db[:accounts].first)

      expect(rodauth.account_stripe_id).to eq('cus_abc123')
      expect(rodauth.account_redis_id).to eq('redis-uuid-456')
    end

    it "helper methods handle nil account gracefully" do
      create_accounts_table_with_columns(columns: [:stripe_id])
      app_class = create_roda_app do
        enable :external_identity
        external_identity_column :stripe
      end

      rodauth = app_class.allocate.rodauth
      expect(rodauth.account_stripe_id).to be_nil
    end

    it "custom method names work correctly" do
      create_accounts_table_with_columns(columns: [:stripe_id])
      db[:accounts].insert(email: 'test@example.com', stripe_id: 'cus_abc123')

      app_class = create_roda_app do
        enable :external_identity
        external_identity_column :stripe, method_name: :stripe_customer_id
      end

      rodauth = app_class.allocate.rodauth
      rodauth.instance_variable_set(:@account, db[:accounts].first)

      expect(rodauth.respond_to?(:stripe_customer_id)).to be true
      expect(rodauth.stripe_customer_id).to eq('cus_abc123')
    end

    it "generates methods for all declared columns" do
      create_accounts_table_with_columns(columns: [:stripe_id, :redis_id])
      app_class = create_roda_app do
        enable :external_identity
        external_identity_column :stripe
        external_identity_column :redis
      end

      rodauth = app_class.allocate.rodauth
      methods = rodauth.external_identity_helper_methods

      expect(methods).to match_array([:account_stripe_id, :account_redis_id])
    end
  end

  describe "introspection methods" do
    describe "#external_identity_column_list" do
      it "returns list of declared column names" do
        create_accounts_table_with_columns(columns: [:stripe_id, :redis_id])
        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :stripe
          external_identity_column :redis
        end

        rodauth = app_class.allocate.rodauth
        expect(rodauth.external_identity_column_list).to match_array([:stripe, :redis])
      end

      it "returns empty array when no columns declared" do
        create_accounts_table_with_columns(columns: [])
        app_class = create_roda_app do
          enable :external_identity
        end

        rodauth = app_class.allocate.rodauth
        expect(rodauth.external_identity_column_list).to eq([])
      end
    end

    describe "#external_identity_column_config" do
      it "returns configuration for specific column" do
        create_accounts_table_with_columns(columns: [:stripe_customer_id])
        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :stripe, :stripe_customer_id, method_name: :stripe_id
        end

        rodauth = app_class.allocate.rodauth
        config_hash = rodauth.external_identity_column_config(:stripe)

        expect(config_hash).to include(
          column: :stripe_customer_id,
          method_name: :stripe_id,
          include_in_select: true
        )
      end

      it "returns nil for unknown column" do
        create_accounts_table_with_columns(columns: [:stripe_id])
        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :stripe
        end

        rodauth = app_class.allocate.rodauth
        expect(rodauth.external_identity_column_config(:unknown)).to be_nil
      end
    end

    describe "#external_identity_helper_methods" do
      it "returns list of generated method names" do
        create_accounts_table_with_columns(columns: [:stripe_id, :redis_id])
        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :stripe
          external_identity_column :redis, method_name: :redis_uuid
        end

        rodauth = app_class.allocate.rodauth
        expect(rodauth.external_identity_helper_methods).to match_array([:account_stripe_id, :redis_uuid])
      end

      it "returns empty array when no columns declared" do
        create_accounts_table_with_columns(columns: [])
        app_class = create_roda_app do
          enable :external_identity
        end

        rodauth = app_class.allocate.rodauth
        expect(rodauth.external_identity_helper_methods).to eq([])
      end
    end

    describe "#external_identity_column?" do
      it "returns true for declared column name" do
        create_accounts_table_with_columns(columns: [:stripe_id])
        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :stripe
        end

        rodauth = app_class.allocate.rodauth
        expect(rodauth.external_identity_column?(:stripe)).to be true
      end

      it "returns true for actual column name" do
        create_accounts_table_with_columns(columns: [:stripe_customer_id])
        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :stripe, :stripe_customer_id
        end

        rodauth = app_class.allocate.rodauth
        expect(rodauth.external_identity_column?(:stripe_customer_id)).to be true
      end

      it "returns false for unknown column" do
        create_accounts_table_with_columns(columns: [:stripe_id])
        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :stripe
        end

        rodauth = app_class.allocate.rodauth
        expect(rodauth.external_identity_column?(:unknown)).to be false
      end
    end

    describe "#external_identity_status" do
      it "returns complete status information" do
        create_accounts_table_with_columns(columns: [:stripe_id, :redis_id])
        db[:accounts].insert(email: 'test@example.com', stripe_id: 'cus_abc123', redis_id: nil)

        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :stripe
          external_identity_column :redis
        end

        rodauth = app_class.allocate.rodauth
        rodauth.instance_variable_set(:@account, db[:accounts].first)

        status = rodauth.external_identity_status
        expect(status).to be_an(Array)
        expect(status.length).to eq(2)
      end

      it "includes all required fields in status hash" do
        create_accounts_table_with_columns(columns: [:stripe_id])
        db[:accounts].insert(email: 'test@example.com', stripe_id: 'cus_abc123')

        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :stripe
        end

        rodauth = app_class.allocate.rodauth
        rodauth.instance_variable_set(:@account, db[:accounts].first)

        status = rodauth.external_identity_status.first
        expect(status).to include(
          :name, :column, :method, :value, :present,
          :in_select, :in_account, :column_exists
        )
      end

      it "correctly reports present values" do
        create_accounts_table_with_columns(columns: [:stripe_id])
        db[:accounts].insert(email: 'test@example.com', stripe_id: 'cus_abc123')

        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :stripe
        end

        rodauth = app_class.allocate.rodauth
        rodauth.instance_variable_set(:@account, db[:accounts].first)

        status = rodauth.external_identity_status.first
        expect(status[:value]).to eq('cus_abc123')
        expect(status[:present]).to be true
      end

      it "correctly reports nil values" do
        create_accounts_table_with_columns(columns: [:redis_id])
        db[:accounts].insert(email: 'test@example.com', redis_id: nil)

        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :redis
        end

        rodauth = app_class.allocate.rodauth
        rodauth.instance_variable_set(:@account, db[:accounts].first)

        status = rodauth.external_identity_status.first
        expect(status[:value]).to be_nil
        expect(status[:present]).to be false
      end

      it "reports column existence in database" do
        create_accounts_table_with_columns(columns: [:stripe_id])
        db[:accounts].insert(email: 'test@example.com', stripe_id: 'cus_abc123')

        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :stripe
        end

        rodauth = app_class.allocate.rodauth
        rodauth.instance_variable_set(:@account, db[:accounts].first)

        status = rodauth.external_identity_status.first
        expect(status[:column_exists]).to be true
      end

      it "handles missing account gracefully" do
        create_accounts_table_with_columns(columns: [:stripe_id])
        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :stripe
        end

        rodauth = app_class.allocate.rodauth

        status = rodauth.external_identity_status.first
        expect(status[:value]).to be_nil
        expect(status[:present]).to be false
      end
    end
  end

  describe "validation" do
    context "column existence validation" do
      it "does not validate columns by default" do
        create_accounts_table_with_columns(columns: [])

        expect {
          create_roda_app do
            enable :external_identity
            external_identity_column :stripe
          end
        }.not_to raise_error
      end

      it "validates columns when validate option is true" do
        create_accounts_table_with_columns(columns: [])

        expect {
          create_roda_app do
            enable :external_identity
            external_identity_validate_columns true
            external_identity_column :stripe
          end
        }.to raise_error(ArgumentError, /not found in accounts table/)
      end

      it "passes validation when columns exist" do
        create_accounts_table_with_columns(columns: [:stripe_id])

        expect {
          create_roda_app do
            enable :external_identity
            external_identity_validate_columns true
            external_identity_column :stripe
          end
        }.not_to raise_error
      end

      it "provides helpful error message for missing columns" do
        create_accounts_table_with_columns(columns: [])

        expect {
          create_roda_app do
            enable :external_identity
            external_identity_validate_columns true
            external_identity_column :stripe
            external_identity_column :redis
          end
        }.to raise_error(ArgumentError, /stripe.*redis/)
      end
    end

    context "invalid method names" do
      it "rejects empty symbol" do
        create_accounts_table_with_columns(columns: [:stripe_id])

        expect {
          create_roda_app do
            enable :external_identity
            external_identity_column :""
          end
        }.to raise_error(ArgumentError, /valid Ruby identifier/)
      end

      it "rejects symbols with spaces" do
        create_accounts_table_with_columns(columns: [:stripe_id])

        expect {
          create_roda_app do
            enable :external_identity
            external_identity_column :"stripe id"
          end
        }.to raise_error(ArgumentError, /valid Ruby identifier/)
      end
    end
  end

  describe "edge cases" do
    it "handles no columns declared (no-op feature)" do
      create_accounts_table_with_columns(columns: [])
      app_class = create_roda_app do
        enable :external_identity
      end

      rodauth = app_class.allocate.rodauth
      expect(rodauth.external_identity_column_list).to eq([])
      expect(rodauth.external_identity_helper_methods).to eq([])
      expect(rodauth.external_identity_status).to eq([])
    end

    it "handles multiple columns with various options" do
      create_accounts_table_with_columns(columns: [:stripe_id, :redis_id, :auth0_id, :custom_id])

      app_class = create_roda_app do
        enable :external_identity
        external_identity_column :stripe
        external_identity_column :redis, include_in_select: false
        external_identity_column :auth0, method_name: :auth0_user
        external_identity_column :custom, :custom_id, override: true, validate: false
      end

      rodauth = app_class.allocate.rodauth

      expect(rodauth.external_identity_column_list.length).to eq(4)
      expect(rodauth.account_select).to include(:stripe_id, :auth0_id, :custom_id)
      expect(rodauth.account_select).not_to include(:redis_id)
      expect(rodauth.respond_to?(:auth0_user)).to be true
    end

    it "handles symbols with underscores and numbers" do
      create_accounts_table_with_columns(columns: [:oauth2_id, :api_v2_key])

      app_class = create_roda_app do
        enable :external_identity
        external_identity_column :oauth2
        external_identity_column :api_v2, :api_v2_key
      end

      rodauth = app_class.allocate.rodauth
      expect(rodauth.external_identity_column_list).to match_array([:oauth2, :api_v2])
    end

    it "handles nil values in account hash" do
      create_accounts_table_with_columns(columns: [:stripe_id])
      db[:accounts].insert(email: 'test@example.com', stripe_id: nil)

      app_class = create_roda_app do
        enable :external_identity
        external_identity_column :stripe
      end

      rodauth = app_class.allocate.rodauth
      rodauth.instance_variable_set(:@account, db[:accounts].first)

      expect(rodauth.account_stripe_id).to be_nil
    end
  end

  describe "configuration value methods" do
    it "external_identity_on_conflict defaults to :error" do
      create_accounts_table_with_columns(columns: [])
      app_class = create_roda_app do
        enable :external_identity
      end

      rodauth = app_class.allocate.rodauth
      expect(rodauth.external_identity_on_conflict).to eq(:error)
    end

    it "external_identity_validate_columns defaults to false" do
      create_accounts_table_with_columns(columns: [])
      app_class = create_roda_app do
        enable :external_identity
      end

      rodauth = app_class.allocate.rodauth
      expect(rodauth.external_identity_validate_columns).to be false
    end

    it "allows customizing external_identity_on_conflict" do
      create_accounts_table_with_columns(columns: [])
      app_class = create_roda_app do
        enable :external_identity
        external_identity_on_conflict :warn
      end

      rodauth = app_class.allocate.rodauth
      expect(rodauth.external_identity_on_conflict).to eq(:warn)
    end

    it "allows customizing external_identity_validate_columns" do
      create_accounts_table_with_columns(columns: [:stripe_id])
      app_class = create_roda_app do
        enable :external_identity
        external_identity_validate_columns true
        external_identity_column :stripe
      end

      rodauth = app_class.allocate.rodauth
      expect(rodauth.external_identity_validate_columns).to be true
    end
  end
end
