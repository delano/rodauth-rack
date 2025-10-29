# External Identity Cleanup Cookbook

Production-ready patterns for cleaning up external resources when accounts are deleted or deactivated.

## Why Cleanup is Different from Generation

The `external_identity` feature intentionally does NOT provide an `on_destroy` callback because cleanup is fundamentally different from generation:

1. **Generation is synchronous** - Must succeed before account creation completes
2. **Cleanup is asynchronous** - Must tolerate failures, retries, and eventual consistency
3. **Generation blocks the user** - Fast feedback loop required
4. **Cleanup runs in background** - User doesn't wait for external API calls
5. **Generation failures prevent account creation** - Simple error handling
6. **Cleanup failures require auditing** - Complex error handling with retries

## Pattern 1: Background Job with Retries

Recommended for most use cases. Cleanup happens asynchronously with automatic retries.

```ruby
# app/jobs/cleanup_external_identities_job.rb
class CleanupExternalIdentitiesJob
  include Sidekiq::Job
  sidekiq_options queue: :critical, retry: 5, dead: false

  def perform(account_id, external_identities)
    # external_identities = {stripe_customer_id: "cus_123", redis_uuid: "uuid"}

    external_identities.each do |column, value|
      next if value.nil?

      begin
        cleanup_external_resource(column, value)
        log_cleanup_success(account_id, column, value)
      rescue => e
        log_cleanup_failure(account_id, column, value, e)
        # Sidekiq will retry automatically
        raise
      end
    end
  end

  private

  def cleanup_external_resource(column, value)
    case column
    when :stripe_customer_id
      Stripe::Customer.delete(value)
    when :redis_uuid
      Redis.current.del("session:#{value}")
    when :github_user_id
      # OAuth tokens - revoke or just log
      logger.info "GitHub user #{value} disconnected"
    else
      logger.warn "Unknown external identity: #{column}"
    end
  end

  def log_cleanup_success(account_id, column, value)
    DB[:external_identity_cleanups].insert(
      account_id: account_id,
      column_name: column.to_s,
      external_value: value,
      status: 'success',
      cleaned_at: Time.now
    )
  end

  def log_cleanup_failure(account_id, column, value, error)
    DB[:external_identity_cleanups].insert(
      account_id: account_id,
      column_name: column.to_s,
      external_value: value,
      status: 'failed',
      error_message: error.message,
      error_class: error.class.name,
      failed_at: Time.now
    )
  end
end
```

### Rodauth Integration

```ruby
plugin :rodauth do
  enable :close_account, :external_identity

  external_identity_column :stripe_customer_id,
    verifier: -> (id) {
      customer = Stripe::Customer.retrieve(id)
      customer && !customer.deleted?
    }

  external_identity_column :redis_uuid

  # Hook into account closure
  after_close_account do
    # Collect all external identities
    external_identities = {}
    external_identity_column_list.each do |column|
      value = account[column]
      external_identities[column] = value if value
    end

    # Enqueue cleanup job
    CleanupExternalIdentitiesJob.perform_async(
      account_id,
      external_identities
    )

    # Optional: Mark account for audit
    DB[:account_closures].insert(
      account_id: account_id,
      closed_at: Time.now,
      external_identities: external_identities.to_json
    )
  end
end
```

### Audit Table Schema

```ruby
Sequel.migration do
  up do
    create_table :external_identity_cleanups do
      primary_key :id
      foreign_key :account_id, :accounts, on_delete: :set_null
      String :column_name, null: false
      String :external_value, null: false
      String :status, null: false  # 'success', 'failed', 'pending'
      String :error_message
      String :error_class
      DateTime :cleaned_at
      DateTime :failed_at
      DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP

      index [:account_id, :column_name]
      index :status
      index :created_at
    end

    create_table :account_closures do
      primary_key :id
      Integer :account_id, null: false
      DateTime :closed_at, null: false
      String :external_identities, text: true  # JSON
      DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP

      index :account_id
      index :closed_at
    end
  end

  down do
    drop_table :external_identity_cleanups
    drop_table :account_closures
  end
end
```

## Pattern 2: Nightly Cron for Eventual Consistency

For systems that can tolerate eventual consistency. Cleanup happens nightly.

```ruby
# lib/tasks/cleanup_orphaned_identities.rake
namespace :external_identity do
  desc "Cleanup orphaned external identities"
  task cleanup_orphaned: :environment do
    # Find accounts closed in last 30 days without successful cleanup
    cutoff = Time.now - 30 * 24 * 60 * 60

    orphaned = DB[:account_closures]
      .left_join(:external_identity_cleanups, account_id: :account_id)
      .where(Sequel[:account_closures][:closed_at] > cutoff)
      .where(Sequel[:external_identity_cleanups][:status] => nil)
      .or(status: 'failed')
      .select(Sequel[:account_closures][:account_id],
              Sequel[:account_closures][:external_identities])

    orphaned.each do |row|
      external_identities = JSON.parse(row[:external_identities], symbolize_names: true)

      CleanupExternalIdentitiesJob.perform_async(
        row[:account_id],
        external_identities
      )
    end

    puts "Enqueued #{orphaned.count} cleanup jobs"
  end
end
```

### Cron Configuration

```ruby
# config/schedule.rb (whenever gem)
every 1.day, at: '3:00 am' do
  rake "external_identity:cleanup_orphaned"
end
```

## Pattern 3: GDPR Compliance Workflow

For legal compliance requirements (GDPR right to erasure).

```ruby
# app/jobs/gdpr_erasure_job.rb
class GDPRErasureJob
  include Sidekiq::Job
  sidekiq_options queue: :critical, retry: 10

  def perform(account_id)
    account = DB[:accounts].where(id: account_id).first
    return unless account

    # 1. Collect all external identities
    external_identities = collect_external_identities(account)

    # 2. Create erasure request record
    erasure_id = create_erasure_request(account_id, external_identities)

    # 3. Delete external resources with verification
    external_identities.each do |column, value|
      delete_and_verify_external_resource(erasure_id, column, value)
    end

    # 4. Verify all external resources deleted
    verify_complete_erasure(erasure_id, external_identities)

    # 5. Anonymize account record
    anonymize_account(account_id)

    # 6. Mark erasure complete
    complete_erasure_request(erasure_id)
  end

  private

  def collect_external_identities(account)
    # Use Rodauth introspection if available
    identities = {}

    # Stripe
    identities[:stripe_customer_id] = account[:stripe_customer_id] if account[:stripe_customer_id]

    # Redis
    identities[:redis_uuid] = account[:redis_uuid] if account[:redis_uuid]

    # GitHub
    identities[:github_user_id] = account[:github_user_id] if account[:github_user_id]

    identities
  end

  def create_erasure_request(account_id, external_identities)
    DB[:gdpr_erasure_requests].insert(
      account_id: account_id,
      status: 'in_progress',
      external_identities: external_identities.to_json,
      started_at: Time.now
    )
  end

  def delete_and_verify_external_resource(erasure_id, column, value)
    case column
    when :stripe_customer_id
      delete_stripe_customer(erasure_id, value)
    when :redis_uuid
      delete_redis_session(erasure_id, value)
    when :github_user_id
      revoke_github_oauth(erasure_id, value)
    end
  end

  def delete_stripe_customer(erasure_id, customer_id)
    # Delete with verification
    Stripe::Customer.delete(customer_id)

    # Verify deletion
    begin
      customer = Stripe::Customer.retrieve(customer_id)
      unless customer.deleted?
        raise "Stripe customer #{customer_id} not deleted"
      end
    rescue Stripe::InvalidRequestError => e
      # Customer not found = successfully deleted
    end

    log_erasure_step(erasure_id, :stripe_customer_id, customer_id, 'deleted')
  end

  def delete_redis_session(erasure_id, uuid)
    keys_deleted = Redis.current.del("session:#{uuid}")
    log_erasure_step(erasure_id, :redis_uuid, uuid, "deleted #{keys_deleted} keys")
  end

  def revoke_github_oauth(erasure_id, user_id)
    # GitHub OAuth tokens - revoke via API
    # Note: Most OAuth providers don't support token revocation
    # Just log the disconnection
    log_erasure_step(erasure_id, :github_user_id, user_id, 'logged')
  end

  def verify_complete_erasure(erasure_id, external_identities)
    # Verify each resource is actually deleted
    external_identities.each do |column, value|
      case column
      when :stripe_customer_id
        verify_stripe_deleted(value)
      when :redis_uuid
        verify_redis_deleted(value)
      end
    end
  end

  def verify_stripe_deleted(customer_id)
    customer = Stripe::Customer.retrieve(customer_id)
    raise "Stripe customer still exists" unless customer.deleted?
  rescue Stripe::InvalidRequestError
    # Not found = deleted successfully
  end

  def verify_redis_deleted(uuid)
    exists = Redis.current.exists("session:#{uuid}")
    raise "Redis session still exists" if exists > 0
  end

  def anonymize_account(account_id)
    DB[:accounts].where(id: account_id).update(
      email: "deleted+#{account_id}@example.com",
      status_id: 'closed',
      stripe_customer_id: nil,
      redis_uuid: nil,
      github_user_id: nil,
      anonymized_at: Time.now
    )
  end

  def complete_erasure_request(erasure_id)
    DB[:gdpr_erasure_requests].where(id: erasure_id).update(
      status: 'completed',
      completed_at: Time.now
    )
  end

  def log_erasure_step(erasure_id, column, value, action)
    DB[:gdpr_erasure_steps].insert(
      erasure_id: erasure_id,
      column_name: column.to_s,
      external_value: value,
      action: action,
      performed_at: Time.now
    )
  end
end
```

### GDPR Schema

```ruby
Sequel.migration do
  up do
    create_table :gdpr_erasure_requests do
      primary_key :id
      Integer :account_id, null: false
      String :status, null: false  # 'pending', 'in_progress', 'completed', 'failed'
      String :external_identities, text: true  # JSON
      DateTime :started_at
      DateTime :completed_at
      DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP

      index :account_id
      index :status
      index :created_at
    end

    create_table :gdpr_erasure_steps do
      primary_key :id
      foreign_key :erasure_id, :gdpr_erasure_requests, on_delete: :cascade
      String :column_name, null: false
      String :external_value, null: false
      String :action, null: false
      DateTime :performed_at, null: false

      index :erasure_id
    end
  end

  down do
    drop_table :gdpr_erasure_steps
    drop_table :gdpr_erasure_requests
  end
end
```

## Best Practices

### 1. Always Use Audit Logging

```ruby
def cleanup_external_resource(column, value)
  # Log before deletion
  logger.info "Deleting #{column}: #{value}"

  # Perform deletion
  delete_resource(column, value)

  # Log after deletion
  logger.info "Deleted #{column}: #{value}"

  # Store in audit table
  DB[:external_identity_cleanups].insert(
    column_name: column.to_s,
    external_value: value,
    status: 'success',
    cleaned_at: Time.now
  )
end
```

### 2. Handle Idempotency

```ruby
def delete_stripe_customer(customer_id)
  Stripe::Customer.delete(customer_id)
rescue Stripe::InvalidRequestError => e
  # Already deleted - that's fine
  raise unless e.message.include?('No such customer')
end
```

### 3. Use Dead Letter Queue

```ruby
class CleanupExternalIdentitiesJob
  include Sidekiq::Job
  sidekiq_options retry: 5, dead: false  # Never send to dead queue

  sidekiq_retries_exhausted do |msg, _ex|
    # Custom handling after all retries
    ManualReviewJob.perform_async(msg['args'])
  end
end
```

### 4. Monitor Cleanup Jobs

```ruby
# Monitor failed cleanups
def alert_on_failed_cleanups
  failed_count = DB[:external_identity_cleanups]
    .where(status: 'failed')
    .where(Sequel.lit('failed_at > ?', Time.now - 24 * 60 * 60))
    .count

  if failed_count > 10
    AlertService.notify(
      "#{failed_count} external identity cleanups failed in last 24h"
    )
  end
end
```

### 5. Test Cleanup in Staging

```ruby
# spec/jobs/cleanup_external_identities_job_spec.rb
RSpec.describe CleanupExternalIdentitiesJob do
  it "deletes Stripe customer" do
    customer = Stripe::Customer.create(email: 'test@example.com')

    CleanupExternalIdentitiesJob.new.perform(
      123,
      { stripe_customer_id: customer.id }
    )

    expect {
      Stripe::Customer.retrieve(customer.id)
    }.to raise_error(Stripe::InvalidRequestError)
  end
end
```

## Why Not Include Cleanup in Core Feature?

The `external_identity` feature could theoretically provide an `on_destroy` or `after_close_account` callback option, but it's intentionally excluded because:

1. **One-size-fits-none** - Every app has different cleanup requirements (immediate vs eventual, sync vs async, with/without verification)

2. **Error handling complexity** - Cleanup failures need app-specific retry logic, dead letter queues, manual review processes

3. **Legal requirements** - GDPR and similar regulations require specific audit trails that vary by jurisdiction

4. **External service differences** - Each service has different deletion semantics (hard delete, soft delete, anonymization)

5. **Background job frameworks** - Apps use different job systems (Sidekiq, Resque, Good Job, Delayed Job) with incompatible APIs

6. **Business logic** - Some apps want to preserve external resources for audit/analytics even after account deletion

This cookbook provides battle-tested patterns instead of a rigid, opinionated implementation.
