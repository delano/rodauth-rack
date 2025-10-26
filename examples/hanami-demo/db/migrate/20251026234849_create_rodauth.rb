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

# Used by the otp feature
create_table :account_otp_keys do
  foreign_key :id, :accounts, primary_key: true, type: :Bignum
  String :key, null: false
  Integer :num_failures, null: false, default: 0
  Time :last_use, null: false, default: Sequel::CURRENT_TIMESTAMP
end
