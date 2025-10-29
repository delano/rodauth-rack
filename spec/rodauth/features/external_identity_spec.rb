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
          external_identity_column :stripe_id
        end

        rodauth = app_class.allocate.rodauth
        expect(rodauth.external_identity_column_list).to eq([:stripe_id])
        expect(rodauth.external_identity_column_config(:stripe_id)).to include(
          column: :stripe_id,
          method_name: :stripe_id,
          include_in_select: true
        )
      end

      it "declares a column with exact column name" do
        create_accounts_table_with_columns(columns: [:stripe_customer_id])
        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :stripe_customer_id
        end

        rodauth = app_class.allocate.rodauth
        expect(rodauth.external_identity_column_config(:stripe_customer_id)[:column]).to eq(:stripe_customer_id)
      end

      it "declares a column with custom method name" do
        create_accounts_table_with_columns(columns: [:stripe_id])
        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :stripe_id, method_name: :stripe_identifier
        end

        rodauth = app_class.allocate.rodauth
        expect(rodauth.external_identity_column_config(:stripe_id)[:method_name]).to eq(:stripe_identifier)
      end
    end

    context "multiple column declarations" do
      it "declares multiple columns" do
        create_accounts_table_with_columns(columns: [:stripe_id, :redis_id, :auth0_id])
        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :stripe_id
          external_identity_column :redis_id
          external_identity_column :auth0_id
        end

        rodauth = app_class.allocate.rodauth
        expect(rodauth.external_identity_column_list).to match_array([:stripe_id, :redis_id, :auth0_id])
      end

      it "maintains declaration order" do
        create_accounts_table_with_columns(columns: [:stripe_id, :redis_id])
        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :stripe_id
          external_identity_column :redis_id
        end

        rodauth = app_class.allocate.rodauth
        expect(rodauth.external_identity_column_list).to eq([:stripe_id, :redis_id])
      end
    end

    context "custom method names" do
      it "accepts valid Ruby identifier" do
        create_accounts_table_with_columns(columns: [:stripe_id])
        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :stripe_id, method_name: :my_stripe_id
        end

        rodauth = app_class.allocate.rodauth
        expect(rodauth.external_identity_helper_methods).to include(:my_stripe_id)
      end

      it "accepts method names with underscores" do
        create_accounts_table_with_columns(columns: [:stripe_id])
        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :stripe_id, method_name: :account_stripe_customer_id
        end

        rodauth = app_class.allocate.rodauth
        expect(rodauth.external_identity_helper_methods).to include(:account_stripe_customer_id)
      end

      it "accepts method names with question marks" do
        create_accounts_table_with_columns(columns: [:stripe_id])
        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :stripe_id, method_name: :has_stripe?
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
            external_identity_column "stripe_id"
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
            external_identity_column :stripe_id, method_name: :"123_stripe"
          end
        }.to raise_error(ArgumentError, /must be a valid Ruby identifier/)
      end

      it "rejects method names with invalid special characters" do
        create_accounts_table_with_columns(columns: [:stripe_id])

        expect {
          create_roda_app do
            enable :external_identity
            external_identity_column :stripe_id, method_name: :"stripe@id"
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
            external_identity_column :stripe_id
            external_identity_column :stripe_id
          end
        }.to raise_error(ArgumentError, /already declared/)
      end

      it "cannot reuse same column even with different method names" do
        create_accounts_table_with_columns(columns: [:stripe_id])

        expect {
          create_roda_app do
            enable :external_identity
            external_identity_column :stripe_id
            external_identity_column :stripe_id, method_name: :alternate_stripe_id
          end
        }.to raise_error(ArgumentError, /already declared/)
      end
    end

    context "options validation" do
      it "accepts include_in_select option" do
        create_accounts_table_with_columns(columns: [:stripe_id])
        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :stripe_id, include_in_select: false
        end

        rodauth = app_class.allocate.rodauth
        expect(rodauth.external_identity_column_config(:stripe_id)[:include_in_select]).to be false
      end

      it "accepts validate option" do
        create_accounts_table_with_columns(columns: [:stripe_id])
        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :stripe_id, validate: true
        end

        rodauth = app_class.allocate.rodauth
        expect(rodauth.external_identity_column_config(:stripe_id)[:validate]).to be true
      end
    end
  end

  describe "account_select integration" do
    it "adds columns to account_select" do
      create_accounts_table_with_columns(columns: [:stripe_id, :redis_id])
      app_class = create_roda_app do
        enable :external_identity
        external_identity_column :stripe_id
        external_identity_column :redis_id
      end

      rodauth = app_class.allocate.rodauth
      select_cols = rodauth.account_select
      expect(select_cols).to include(:stripe_id, :redis_id)
    end

    it "does not add duplicates to account_select" do
      create_accounts_table_with_columns(columns: [:stripe_id])
      app_class = create_roda_app do
        enable :external_identity
        external_identity_column :stripe_id
      end

      rodauth = app_class.allocate.rodauth
      select_cols = rodauth.account_select
      expect(select_cols.count(:stripe_id)).to eq(1)
    end

    it "respects include_in_select: false option" do
      create_accounts_table_with_columns(columns: [:stripe_id, :redis_id])
      app_class = create_roda_app do
        enable :external_identity
        external_identity_column :stripe_id, include_in_select: false
        external_identity_column :redis_id
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
        external_identity_column :stripe_id
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
        external_identity_column :stripe_id
        external_identity_column :redis_id
        external_identity_column :auth0_id
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
        external_identity_column :stripe_id
        external_identity_column :redis_id
      end

      rodauth = app_class.allocate.rodauth
      expect(rodauth.respond_to?(:stripe_id)).to be true
      expect(rodauth.respond_to?(:redis_id)).to be true
    end

    it "helper methods return correct values" do
      create_accounts_table_with_columns(columns: [:stripe_id, :redis_id])
      db[:accounts].insert(email: 'test@example.com', stripe_id: 'cus_abc123', redis_id: 'redis-uuid-456')

      app_class = create_roda_app do
        enable :external_identity
        external_identity_column :stripe_id
        external_identity_column :redis_id
      end

      rodauth = app_class.allocate.rodauth
      rodauth.instance_variable_set(:@account, db[:accounts].first)

      expect(rodauth.stripe_id).to eq('cus_abc123')
      expect(rodauth.redis_id).to eq('redis-uuid-456')
    end

    it "helper methods handle nil account gracefully" do
      create_accounts_table_with_columns(columns: [:stripe_id])
      app_class = create_roda_app do
        enable :external_identity
        external_identity_column :stripe_id
      end

      rodauth = app_class.allocate.rodauth
      expect(rodauth.stripe_id).to be_nil
    end

    it "custom method names work correctly" do
      create_accounts_table_with_columns(columns: [:stripe_id])
      db[:accounts].insert(email: 'test@example.com', stripe_id: 'cus_abc123')

      app_class = create_roda_app do
        enable :external_identity
        external_identity_column :stripe_id, method_name: :stripe_customer_id
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
        external_identity_column :stripe_id
        external_identity_column :redis_id
      end

      rodauth = app_class.allocate.rodauth
      methods = rodauth.external_identity_helper_methods

      expect(methods).to match_array([:stripe_id, :redis_id])
    end
  end

  describe "introspection methods" do
    describe "#external_identity_column_list" do
      it "returns list of declared column names" do
        create_accounts_table_with_columns(columns: [:stripe_id, :redis_id])
        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :stripe_id
          external_identity_column :redis_id
        end

        rodauth = app_class.allocate.rodauth
        expect(rodauth.external_identity_column_list).to match_array([:stripe_id, :redis_id])
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
          external_identity_column :stripe_customer_id, method_name: :stripe_id
        end

        rodauth = app_class.allocate.rodauth
        config_hash = rodauth.external_identity_column_config(:stripe_customer_id)

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
          external_identity_column :stripe_id
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
          external_identity_column :stripe_id
          external_identity_column :redis_id, method_name: :redis_uuid
        end

        rodauth = app_class.allocate.rodauth
        expect(rodauth.external_identity_helper_methods).to match_array([:stripe_id, :redis_uuid])
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
          external_identity_column :stripe_id
        end

        rodauth = app_class.allocate.rodauth
        expect(rodauth.external_identity_column?(:stripe_id)).to be true
      end

      it "returns true for declared column with custom method name" do
        create_accounts_table_with_columns(columns: [:stripe_customer_id])
        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :stripe_customer_id
        end

        rodauth = app_class.allocate.rodauth
        expect(rodauth.external_identity_column?(:stripe_customer_id)).to be true
      end

      it "returns false for unknown column" do
        create_accounts_table_with_columns(columns: [:stripe_id])
        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :stripe_id
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
          external_identity_column :stripe_id
          external_identity_column :redis_id
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
          external_identity_column :stripe_id
        end

        rodauth = app_class.allocate.rodauth
        rodauth.instance_variable_set(:@account, db[:accounts].first)

        status = rodauth.external_identity_status.first
        expect(status).to include(
          :column, :method, :value, :present,
          :in_select, :in_account, :column_exists
        )
      end

      it "correctly reports present values" do
        create_accounts_table_with_columns(columns: [:stripe_id])
        db[:accounts].insert(email: 'test@example.com', stripe_id: 'cus_abc123')

        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :stripe_id
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
          external_identity_column :redis_id
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
          external_identity_column :stripe_id
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
          external_identity_column :stripe_id
        end

        rodauth = app_class.allocate.rodauth

        status = rodauth.external_identity_status.first
        expect(status[:value]).to be_nil
        expect(status[:present]).to be false
      end
    end
  end

  describe "validation" do
    context "column existence checking" do
      it "checks columns by default (true)" do
        create_accounts_table_with_columns(columns: [])

        expect {
          create_roda_app do
            enable :external_identity
            external_identity_column :stripe_id
          end
        }.to raise_error(ArgumentError, /not found in accounts table/)
      end

      it "skips checking when set to false" do
        create_accounts_table_with_columns(columns: [])

        expect {
          create_roda_app do
            enable :external_identity
            external_identity_check_columns false
            external_identity_column :stripe_id
          end
        }.not_to raise_error
      end

      it "passes checking when columns exist" do
        create_accounts_table_with_columns(columns: [:stripe_id])

        expect {
          create_roda_app do
            enable :external_identity
            external_identity_check_columns true
            external_identity_column :stripe_id
          end
        }.not_to raise_error
      end

      it "provides helpful error message for missing columns" do
        create_accounts_table_with_columns(columns: [])

        expect {
          create_roda_app do
            enable :external_identity
            external_identity_check_columns true
            external_identity_column :stripe_id
            external_identity_column :redis_id
          end
        }.to raise_error(ArgumentError, /stripe.*redis/)
      end

      it "supports :autocreate mode with helpful migration code" do
        create_accounts_table_with_columns(columns: [])

        expect {
          create_roda_app do
            enable :external_identity
            external_identity_check_columns :autocreate
            external_identity_column :stripe_id
          end
        }.to raise_error(ArgumentError) do |error|
          expect(error.message).to match(/autocreate/)
          expect(error.message).to match(/Sequel\.migration/)
          expect(error.message).to match(/add_column :stripe_id/)
        end
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
        external_identity_column :stripe_id
        external_identity_column :redis_id, include_in_select: false
        external_identity_column :auth0_id, method_name: :auth0_user
        external_identity_column :custom_id, validate: false
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
        external_identity_column :oauth2_id
        external_identity_column :api_v2_key
      end

      rodauth = app_class.allocate.rodauth
      expect(rodauth.external_identity_column_list).to match_array([:oauth2_id, :api_v2_key])
    end

    it "handles nil values in account hash" do
      create_accounts_table_with_columns(columns: [:stripe_id])
      db[:accounts].insert(email: 'test@example.com', stripe_id: nil)

      app_class = create_roda_app do
        enable :external_identity
        external_identity_column :stripe_id
      end

      rodauth = app_class.allocate.rodauth
      rodauth.instance_variable_set(:@account, db[:accounts].first)

      expect(rodauth.stripe_id).to be_nil
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

    it "external_identity_check_columns defaults to true" do
      create_accounts_table_with_columns(columns: [:stripe_id])
      app_class = create_roda_app do
        enable :external_identity
        external_identity_column :stripe_id
      end

      rodauth = app_class.allocate.rodauth
      expect(rodauth.external_identity_check_columns).to be true
    end

    it "allows customizing external_identity_on_conflict" do
      create_accounts_table_with_columns(columns: [])
      app_class = create_roda_app do
        enable :external_identity
        external_identity_check_columns false
        external_identity_on_conflict :warn
      end

      rodauth = app_class.allocate.rodauth
      expect(rodauth.external_identity_on_conflict).to eq(:warn)
    end

    it "allows customizing external_identity_check_columns to false" do
      create_accounts_table_with_columns(columns: [])
      app_class = create_roda_app do
        enable :external_identity
        external_identity_check_columns false
        external_identity_column :stripe_id
      end

      rodauth = app_class.allocate.rodauth
      expect(rodauth.external_identity_check_columns).to be false
    end

    it "allows customizing external_identity_check_columns to :autocreate" do
      create_accounts_table_with_columns(columns: [])
      app_class = create_roda_app do
        enable :external_identity
        external_identity_check_columns :autocreate
      end

      rodauth = app_class.allocate.rodauth
      expect(rodauth.external_identity_check_columns).to eq(:autocreate)
    end
  end

  describe "Layer 2: Lifecycle callbacks" do
    describe "formatter callback" do
      it "formats value when accessed via helper method" do
        create_accounts_table_with_columns(columns: [:stripe_customer_id])

        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :stripe_customer_id,
            formatter: ->(v) { v.to_s.strip.downcase }
        end

        # Create an account with non-normalized value
        account = db[:accounts].insert(
          email: "user@example.com",
          stripe_customer_id: "  CUS_ABC123  "
        )
        account_record = db[:accounts].first

        rodauth = app_class.allocate.rodauth
        rodauth.instance_variable_set(:@account, account_record)

        # Helper method should return formatted value
        expect(rodauth.stripe_customer_id).to eq("cus_abc123")
      end

      it "applies strip formatting" do
        create_accounts_table_with_columns(columns: [:redis_uuid])

        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :redis_uuid,
            formatter: ->(v) { v.to_s.strip }
        end

        account_record = db[:accounts].insert(
          email: "user@example.com",
          redis_uuid: "  550e8400-e29b-41d4-a716-446655440000  "
        )
        account = db[:accounts].first

        rodauth = app_class.allocate.rodauth
        rodauth.instance_variable_set(:@account, account)

        expect(rodauth.redis_uuid).to eq("550e8400-e29b-41d4-a716-446655440000")
      end

      it "applies downcase formatting" do
        create_accounts_table_with_columns(columns: [:external_id])

        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :external_id,
            formatter: ->(v) { v.downcase }
        end

        account = db[:accounts].insert(
          email: "user@example.com",
          external_id: "ABC-123-XYZ"
        )
        account_record = db[:accounts].first

        rodauth = app_class.allocate.rodauth
        rodauth.instance_variable_set(:@account, account_record)

        expect(rodauth.external_id).to eq("abc-123-xyz")
      end

      it "chains multiple formatting operations" do
        create_accounts_table_with_columns(columns: [:api_key])

        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :api_key,
            formatter: ->(v) { v.to_s.strip.downcase.gsub(/[^a-z0-9]/, '') }
        end

        account = db[:accounts].insert(
          email: "user@example.com",
          api_key: "  API-KEY-123  "
        )
        account_record = db[:accounts].first

        rodauth = app_class.allocate.rodauth
        rodauth.instance_variable_set(:@account, account_record)

        expect(rodauth.api_key).to eq("apikey123")
      end

      it "returns nil when value is nil" do
        create_accounts_table_with_columns(columns: [:optional_id])

        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :optional_id,
            formatter: ->(v) { v.to_s.strip }
        end

        account = db[:accounts].insert(
          email: "user@example.com",
          optional_id: nil
        )
        account_record = db[:accounts].first

        rodauth = app_class.allocate.rodauth
        rodauth.instance_variable_set(:@account, account_record)

        # Should not apply formatter to nil
        expect(rodauth.optional_id).to be_nil
      end

      it "returns nil when account is nil" do
        create_accounts_table_with_columns(columns: [:stripe_customer_id])

        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :stripe_customer_id,
            formatter: ->(v) { v.to_s.strip }
        end

        rodauth = app_class.allocate.rodauth
        # No account set

        expect(rodauth.stripe_customer_id).to be_nil
      end

      it "works without formatter (backward compatibility)" do
        create_accounts_table_with_columns(columns: [:legacy_id])

        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :legacy_id
        end

        account = db[:accounts].insert(
          email: "user@example.com",
          legacy_id: "  LEGACY  "
        )
        account_record = db[:accounts].first

        rodauth = app_class.allocate.rodauth
        rodauth.instance_variable_set(:@account, account_record)

        # Should return raw value without formatting
        expect(rodauth.legacy_id).to eq("  LEGACY  ")
      end

      it "supports custom formatter logic" do
        create_accounts_table_with_columns(columns: [:phone_number])

        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :phone_number,
            formatter: ->(v) {
              # Remove all non-digits, add +1 prefix
              digits = v.gsub(/\D/, '')
              "+1#{digits}"
            }
        end

        account = db[:accounts].insert(
          email: "user@example.com",
          phone_number: "(555) 123-4567"
        )
        account_record = db[:accounts].first

        rodauth = app_class.allocate.rodauth
        rodauth.instance_variable_set(:@account, account_record)

        expect(rodauth.phone_number).to eq("+15551234567")
      end
    end

    describe "validator callback" do
      it "validates value format successfully" do
        create_accounts_table_with_columns(columns: [:stripe_customer_id])

        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :stripe_customer_id,
            validator: ->(v) { v.start_with?('cus_') && v.length >= 10 }
        end

        rodauth = app_class.allocate.rodauth

        # Valid value should pass ("cus_abc123" is exactly 10 chars)
        expect(rodauth.validate_external_identity(:stripe_customer_id, "cus_abc123")).to be true
      end

      it "raises ArgumentError for invalid format" do
        create_accounts_table_with_columns(columns: [:stripe_customer_id])

        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :stripe_customer_id,
            validator: ->(v) { v.start_with?('cus_') }
        end

        rodauth = app_class.allocate.rodauth

        # Invalid value should raise error
        expect {
          rodauth.validate_external_identity(:stripe_customer_id, "invalid")
        }.to raise_error(ArgumentError, /Invalid format for stripe_customer_id/)
      end

      it "applies formatter before validation" do
        create_accounts_table_with_columns(columns: [:api_key])

        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :api_key,
            formatter: ->(v) { v.to_s.strip.downcase },
            validator: ->(v) { v.start_with?('api_') }
        end

        rodauth = app_class.allocate.rodauth

        # Formatter should run first (uppercase -> lowercase)
        expect(rodauth.validate_external_identity(:api_key, "  API_KEY123  ")).to be true
      end

      it "skips validation for nil values" do
        create_accounts_table_with_columns(columns: [:optional_id])

        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :optional_id,
            validator: ->(v) { v.length > 5 }
        end

        rodauth = app_class.allocate.rodauth

        # nil should not be validated
        expect(rodauth.validate_external_identity(:optional_id, nil)).to be true
      end

      it "returns true when no validator configured" do
        create_accounts_table_with_columns(columns: [:legacy_id])

        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :legacy_id
        end

        rodauth = app_class.allocate.rodauth

        # Should always pass without validator
        expect(rodauth.validate_external_identity(:legacy_id, "anything")).to be true
      end

      it "validates complex format rules" do
        create_accounts_table_with_columns(columns: [:phone_number])

        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :phone_number,
            validator: ->(v) {
              # Must be exactly 12 characters (+1 + 10 digits)
              v =~ /^\+1\d{10}$/
            }
        end

        rodauth = app_class.allocate.rodauth

        expect(rodauth.validate_external_identity(:phone_number, "+15551234567")).to be true
        expect {
          rodauth.validate_external_identity(:phone_number, "555-1234")
        }.to raise_error(ArgumentError)
      end

      it "validates all configured external identities" do
        create_accounts_table_with_columns(columns: [:stripe_customer_id, :redis_uuid])

        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :stripe_customer_id,
            validator: ->(v) { v.start_with?('cus_') }
          external_identity_column :redis_uuid,
            validator: ->(v) { v.length == 36 }
        end

        account = db[:accounts].insert(
          email: "user@example.com",
          stripe_customer_id: "cus_abc123",
          redis_uuid: "550e8400-e29b-41d4-a716-446655440000"
        )
        account_record = db[:accounts].first

        rodauth = app_class.allocate.rodauth
        rodauth.instance_variable_set(:@account, account_record)

        results = rodauth.validate_all_external_identities
        expect(results[:stripe_customer_id]).to be true
        expect(results[:redis_uuid]).to be true
      end

      it "raises on first validation failure" do
        create_accounts_table_with_columns(columns: [:stripe_customer_id, :redis_uuid])

        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :stripe_customer_id,
            validator: ->(v) { v.start_with?('cus_') }
          external_identity_column :redis_uuid,
            validator: ->(v) { v.length == 36 }
        end

        account = db[:accounts].insert(
          email: "user@example.com",
          stripe_customer_id: "invalid",  # Will fail validation
          redis_uuid: "550e8400-e29b-41d4-a716-446655440000"
        )
        account_record = db[:accounts].first

        rodauth = app_class.allocate.rodauth
        rodauth.instance_variable_set(:@account, account_record)

        expect {
          rodauth.validate_all_external_identities
        }.to raise_error(ArgumentError, /Invalid format for stripe_customer_id/)
      end

      it "skips columns without validators in validate_all" do
        create_accounts_table_with_columns(columns: [:stripe_customer_id, :legacy_id])

        app_class = create_roda_app do
          enable :external_identity
          external_identity_column :stripe_customer_id,
            validator: ->(v) { v.start_with?('cus_') }
          external_identity_column :legacy_id
          # No validator for legacy_id
        end

        account = db[:accounts].insert(
          email: "user@example.com",
          stripe_customer_id: "cus_abc123",
          legacy_id: "anything_goes"
        )
        account_record = db[:accounts].first

        rodauth = app_class.allocate.rodauth
        rodauth.instance_variable_set(:@account, account_record)

        results = rodauth.validate_all_external_identities
        expect(results[:stripe_customer_id]).to be true
        expect(results).not_to have_key(:legacy_id)  # Not included
      end
    end
  end
end
