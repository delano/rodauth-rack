Sequel.migration do
  change do
    create_table :accounts do
      primary_key :id, type: :Bignum
      String :email, null: false
      Integer :status, null: false, default: 1
      index :email, unique: true
      String :password_hash
    end

    # Used by the password reset feature
    create_table :account_password_reset_keys do
      foreign_key :id, :accounts, primary_key: true, type: :Bignum
      String :key, null: false
      DateTime :deadline, null: false
      DateTime :email_last_sent, null: false, default: Sequel::CURRENT_TIMESTAMP
    end

    # Used by the account verification feature
    create_table :account_verification_keys do
      foreign_key :id, :accounts, primary_key: true, type: :Bignum
      String :key, null: false
      DateTime :requested_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      DateTime :email_last_sent, null: false, default: Sequel::CURRENT_TIMESTAMP
    end

    # Used by the verify login change feature
    create_table :account_login_change_keys do
      foreign_key :id, :accounts, primary_key: true, type: :Bignum
      String :key, null: false
      String :login, null: false
      DateTime :deadline, null: false
    end

    # Used by the remember me feature
    create_table :account_remember_keys do
      foreign_key :id, :accounts, primary_key: true, type: :Bignum
      String :key, null: false
      DateTime :deadline, null: false
    end

    # Used by the email auth feature
    create_table :account_email_auth_keys do
      foreign_key :id, :accounts, primary_key: true, type: :Bignum
      String :key, null: false
      DateTime :deadline, null: false
      DateTime :email_last_sent, null: false, default: Sequel::CURRENT_TIMESTAMP
    end

    # Used by the otp feature
    create_table :account_otp_keys do
      foreign_key :id, :accounts, primary_key: true, type: :Bignum
      String :key, null: false
      Integer :num_failures, null: false, default: 0
      Time :last_use, null: false, default: Sequel::CURRENT_TIMESTAMP
    end

    # Used by the recovery codes feature
    create_table :account_recovery_codes, primary_key: [:id, :code] do
      Integer :id
      foreign_key [:id], :accounts
      String :code
    end

    # Used by the audit logging feature
    create_table :account_authentication_audit_logs do
      primary_key :id, type: :Bignum
      foreign_key :account_id, :accounts, type: :Bignum, null: false
      DateTime :at, null: false, default: Sequel::CURRENT_TIMESTAMP
      String :message, text: true, null: false
      String :metadata, text: true
      index [:account_id, :at]
      index :at
    end
  end
end
