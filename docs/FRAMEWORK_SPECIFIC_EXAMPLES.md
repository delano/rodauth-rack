# Framework-Specific Implementation Examples

## Rails Implementation

### Complete Rails Setup with Active Sessions

#### 1. Generate Migrations

```bash
# Generate migrations
rails generate rodauth:migration active_sessions disallow_password_reuse
rails db:migrate
```

#### 2. Configure Rodauth

```ruby
# lib/rodauth_main.rb
require "sequel/core"

class RodauthMain < Rodauth::Rails::Auth
  configure do
    enable :create_account, :verify_account, :login, :logout,
           :remember, :reset_password, :change_password,
           :session_expiration, :active_sessions,
           :password_pepper, :disallow_password_reuse

    # Database connection (Rails with Active Record)
    db Sequel.postgres(extensions: :activerecord_connection, keep_reference: false)

    # Session security
    max_session_lifetime 30 * 86400
    session_inactivity_timeout 86400
    update_session_activity_time? true

    # Password security
    password_pepper Rails.application.credentials.dig(:rodauth, :password_pepper)
    password_maximum_bytes 60
    password_minimum_length 12
    previous_passwords_to_check 10

    # UI labels
    global_logout_label "Logout from all devices"

    # Rails integration
    rails_controller { RodauthController }
    title_instance_variable :@page_title
    account_status_column :status
    account_password_hash_column :password_hash

    # Email delivery
    send_email do |email|
      db.after_commit { email.deliver_later }
    end
  end
end
```

#### 3. Update Routes

```ruby
# config/routes.rb
Rails.application.routes.draw do
  # Rodauth routes
  rodauth_route = lambda do |r|
    rodauth.load_memory
    rodauth.check_active_session
    r.rodauth
  end

  # Session management
  resources :sessions, only: [:index, :destroy] do
    collection do
      post :logout_all
    end
  end

  # Dashboard and other routes
  get "dashboard", to: "dashboard#show"

  root "home#index"
end
```

#### 4. Sessions Controller

```ruby
# app/controllers/sessions_controller.rb
class SessionsController < ApplicationController
  before_action :authenticate_user!

  def index
    @sessions = current_sessions
  end

  def destroy
    if rodauth.remove_active_session(params[:id])
      redirect_to sessions_path, notice: "Session terminated successfully"
    else
      redirect_to sessions_path, alert: "Session not found"
    end
  end

  def logout_all
    rodauth.remove_all_active_sessions_except_for(rodauth.active_session_id)
    redirect_to root_path, notice: "All other sessions have been terminated"
  end

  private

  def current_sessions
    rodauth.account_sessions.map do |session|
      {
        session_id: session[:session_id],
        created_at: session[:created_at],
        last_use: session[:last_use],
        current: session[:session_id] == rodauth.active_session_id
      }
    end
  end

  def rodauth
    request.env["rodauth"]
  end
end
```

#### 5. Session Management View

```erb
<!-- app/views/sessions/index.html.erb -->
<div class="container mt-4">
  <h1>Active Sessions</h1>

  <div class="alert alert-info">
    You have <%= @sessions.size %> active session(s).
    Sessions expire after 24 hours of inactivity or 30 days total.
  </div>

  <table class="table table-striped">
    <thead>
      <tr>
        <th>Created</th>
        <th>Last Activity</th>
        <th>Status</th>
        <th>Actions</th>
      </tr>
    </thead>
    <tbody>
      <% @sessions.each do |session| %>
        <tr>
          <td><%= time_ago_in_words(session[:created_at]) %> ago</td>
          <td><%= time_ago_in_words(session[:last_use]) %> ago</td>
          <td>
            <% if session[:current] %>
              <span class="badge bg-success">Current Session</span>
            <% else %>
              <span class="badge bg-secondary">Active</span>
            <% end %>
          </td>
          <td>
            <% unless session[:current] %>
              <%= button_to "Terminate",
                  session_path(session[:session_id]),
                  method: :delete,
                  class: "btn btn-sm btn-danger",
                  data: { confirm: "Terminate this session?" } %>
            <% end %>
          </td>
        </tr>
      <% end %>
    </tbody>
  </table>

  <div class="mt-4">
    <%= button_to "Logout All Other Devices",
        logout_all_sessions_path,
        class: "btn btn-warning",
        data: { confirm: "Terminate all other sessions?" } %>
  </div>

  <%= link_to "Back to Dashboard", dashboard_path, class: "btn btn-secondary mt-3" %>
</div>
```

#### 6. Update Logout View

```erb
<!-- app/views/rodauth/logout.html.erb -->
<div class="container mt-4">
  <h1>Logout</h1>

  <%= form_tag rodauth.logout_path, method: :post, class: "card p-4" do %>
    <div class="mb-3">
      <%= render "global_logout_field" %>
    </div>

    <%= submit_tag "Logout", class: "btn btn-primary" %>
  <% end %>
</div>
```

```erb
<!-- app/views/rodauth/_global_logout_field.html.erb -->
<div class="form-check">
  <%= check_box_tag rodauth.global_logout_param, "t", false,
      id: "global-logout", class: "form-check-input" %>
  <%= label_tag "global-logout", rodauth.global_logout_label,
      class: "form-check-label" %>
</div>
```

#### 7. Application Helper

```ruby
# app/helpers/application_helper.rb
module ApplicationHelper
  def rodauth
    request.env["rodauth"]
  end

  def logged_in?
    rodauth.logged_in?
  end

  def current_account
    rodauth.rails_account
  end
end
```

#### 8. Authentication Helper

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  private

  def authenticate_user!
    rodauth.require_authentication
  end

  def rodauth
    request.env["rodauth"]
  end
  helper_method :rodauth
end
```

#### 9. Background Job for Cleanup

```ruby
# app/jobs/cleanup_expired_sessions_job.rb
class CleanupExpiredSessionsJob < ApplicationJob
  queue_as :default

  def perform
    # Access Rodauth through Sequel connection
    db = Sequel.postgres(extensions: :activerecord_connection)

    db.transaction do
      # Remove sessions older than max_session_lifetime (30 days)
      max_lifetime = 30.days.ago
      db[:account_active_session_keys]
        .where { created_at < max_lifetime }
        .delete

      # Remove sessions with inactivity > session_inactivity_timeout (1 day)
      inactivity_limit = 1.day.ago
      db[:account_active_session_keys]
        .where { last_use < inactivity_limit }
        .delete
    end

    Rails.logger.info "Cleaned up expired sessions"
  end
end
```

```ruby
# config/initializers/scheduled_jobs.rb
# Using Sidekiq-Cron
Sidekiq::Cron::Job.create(
  name: "Cleanup expired sessions",
  cron: "0 3 * * *",  # Daily at 3 AM
  class: "CleanupExpiredSessionsJob"
)
```

#### 10. Store Pepper in Credentials

```bash
# Generate pepper
ruby -r securerandom -e 'puts SecureRandom.hex(32)'

# Edit credentials
EDITOR=vim rails credentials:edit
```

```yaml
# config/credentials.yml.enc
rodauth:
  password_pepper: a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456
```

---

## Hanami Implementation

### Complete Hanami Setup with Active Sessions

#### 1. Generate Migrations

```bash
# Using rodauth-rack generator
bundle exec rodauth-rack generate migration active_sessions disallow_password_reuse

# Or manually create Sequel migration
# db/migrations/20250101000001_create_rodauth_active_sessions.rb
```

#### 2. Configure Rodauth Provider

```ruby
# config/providers/rodauth.rb
Hanami.app.register_provider :rodauth do
  prepare do
    require "rodauth/rack/hanami"
  end

  start do
    require "rodauth_app"

    # Register middleware
    target.app.config.middleware.use(
      Rodauth::Rack::Hanami::Middleware
    )

    # Register in container
    register "rodauth" do
      Rodauth::Rack::Hanami
    end
  end
end
```

#### 3. Configure Rodauth Main

```ruby
# lib/rodauth_main.rb
class RodauthMain < Rodauth::Rack::Hanami::Auth
  configure do
    enable :hanami
    enable :create_account, :verify_account, :login, :logout,
           :remember, :reset_password, :change_password,
           :session_expiration, :active_sessions,
           :password_pepper, :disallow_password_reuse

    # Database connection
    db Sequel.connect(ENV.fetch('DATABASE_URL'))

    # Session security
    max_session_lifetime 30 * 86400
    session_inactivity_timeout 86400
    update_session_activity_time? true

    # Password security
    password_pepper ENV.fetch("RODAUTH_PASSWORD_PEPPER")
    password_maximum_bytes 60
    password_minimum_length 12
    previous_passwords_to_check 10

    # Hanami-specific
    accounts_table :accounts
    email_from "noreply@example.com"
    email_subject_prefix "[HanamiApp] "

    # UI labels
    global_logout_label "Logout from all devices"

    # Redirects
    login_redirect "/dashboard"
    logout_redirect "/"
  end
end
```

#### 4. Rodauth App

```ruby
# lib/rodauth_app.rb
require "rodauth/rack/hanami"

class RodauthApp < Rodauth::Rack::Hanami::App
  configure RodauthMain

  route do |r|
    rodauth.load_memory
    rodauth.check_active_session

    r.rodauth

    # Session management routes
    r.on "sessions" do
      rodauth.require_authentication

      r.is do
        r.get do
          @sessions = rodauth.account_sessions.map do |session|
            {
              session_id: session[:session_id],
              created_at: session[:created_at],
              last_use: session[:last_use],
              current: session[:session_id] == rodauth.active_session_id
            }
          end

          view "sessions/index", sessions: @sessions
        end
      end

      r.on String do |session_id|
        r.delete do
          if rodauth.remove_active_session(session_id)
            rodauth.flash[:notice] = "Session terminated successfully"
          else
            rodauth.flash[:error] = "Session not found"
          end
          r.redirect "/sessions"
        end
      end

      r.on "logout-all" do
        r.post do
          rodauth.remove_all_active_sessions_except_for(rodauth.active_session_id)
          rodauth.flash[:notice] = "All other sessions terminated"
          r.redirect "/"
        end
      end
    end
  end
end

Rodauth::Rack::Hanami.app = RodauthApp
```

#### 5. Sessions View Template

```erb
<!-- app/templates/sessions/index.html.erb -->
<div class="container">
  <h1>Active Sessions</h1>

  <div class="alert alert-info">
    You have <%= sessions.size %> active session(s).
    Sessions expire after 24 hours of inactivity or 30 days total.
  </div>

  <table class="table">
    <thead>
      <tr>
        <th>Created</th>
        <th>Last Activity</th>
        <th>Status</th>
        <th>Actions</th>
      </tr>
    </thead>
    <tbody>
      <% sessions.each do |session| %>
        <tr>
          <td><%= time_ago(session[:created_at]) %></td>
          <td><%= time_ago(session[:last_use]) %></td>
          <td>
            <% if session[:current] %>
              <span class="badge badge-success">Current</span>
            <% else %>
              <span class="badge badge-secondary">Active</span>
            <% end %>
          </td>
          <td>
            <% unless session[:current] %>
              <form action="/sessions/<%= session[:session_id] %>" method="post">
                <input type="hidden" name="_method" value="delete">
                <button type="submit" class="btn btn-sm btn-danger"
                        onclick="return confirm('Terminate this session?')">
                  Terminate
                </button>
              </form>
            <% end %>
          </td>
        </tr>
      <% end %>
    </tbody>
  </table>

  <div class="mt-4">
    <form action="/sessions/logout-all" method="post">
      <button type="submit" class="btn btn-warning"
              onclick="return confirm('Terminate all other sessions?')">
        Logout All Other Devices
      </button>
    </form>
  </div>

  <a href="/dashboard" class="btn btn-secondary mt-3">Back to Dashboard</a>
</div>
```

#### 6. Logout View with Global Logout

```erb
<!-- app/templates/rodauth/logout.html.erb -->
<div class="container">
  <h1>Logout</h1>

  <form action="<%= rodauth.logout_path %>" method="post" class="card p-4">
    <%= csrf_tag %>

    <div class="form-check mb-3">
      <input type="checkbox"
             name="<%= rodauth.global_logout_param %>"
             value="t"
             id="global-logout"
             class="form-check-input">
      <label for="global-logout" class="form-check-label">
        <%= rodauth.global_logout_label %>
      </label>
    </div>

    <button type="submit" class="btn btn-primary">Logout</button>
  </form>
</div>
```

#### 7. Helper Methods

```ruby
# app/helpers/application_helper.rb
module HanamiApp
  module Helpers
    module ApplicationHelper
      def time_ago(time)
        return "Never" unless time

        seconds = Time.now - time
        case seconds
        when 0..59
          "#{seconds.to_i} seconds ago"
        when 60..3599
          "#{(seconds / 60).to_i} minutes ago"
        when 3600..86399
          "#{(seconds / 3600).to_i} hours ago"
        else
          "#{(seconds / 86400).to_i} days ago"
        end
      end

      def csrf_tag
        %(<input type="hidden" name="_csrf" value="#{Rack::Csrf.token(env)}">)
      end
    end
  end
end
```

#### 8. Actions with Authentication

```ruby
# app/actions/dashboard/show.rb
module HanamiApp
  module Actions
    module Dashboard
      class Show < HanamiApp::Action
        before :authenticate!

        def handle(request, response)
          @account = rodauth.account
          response.render view
        end

        private

        def authenticate!
          rodauth.require_authentication
        end

        def rodauth
          request.env["rodauth"]
        end
      end
    end
  end
end
```

#### 9. Background Job for Cleanup

```ruby
# lib/hanami_app/jobs/cleanup_expired_sessions.rb
module HanamiApp
  module Jobs
    class CleanupExpiredSessions
      def call
        db = Sequel.connect(ENV.fetch('DATABASE_URL'))

        db.transaction do
          # Remove sessions older than max_session_lifetime (30 days)
          max_lifetime = Time.now - (30 * 86400)
          db[:account_active_session_keys]
            .where { created_at < max_lifetime }
            .delete

          # Remove sessions with inactivity > session_inactivity_timeout (1 day)
          inactivity_limit = Time.now - 86400
          db[:account_active_session_keys]
            .where { last_use < inactivity_limit }
            .delete
        end

        puts "Cleaned up expired sessions at #{Time.now}"
      end
    end
  end
end
```

```ruby
# config/puma.rb (or separate scheduler)
# Using Sidekiq or Rufus-Scheduler
require "rufus-scheduler"

scheduler = Rufus::Scheduler.new

scheduler.cron "0 3 * * *" do  # Daily at 3 AM
  HanamiApp::Jobs::CleanupExpiredSessions.new.call
end
```

#### 10. Environment Variables

```bash
# .env.development
DATABASE_URL=sqlite://db/hanami_app_development.db
RODAUTH_PASSWORD_PEPPER=a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456

# .env.production (or use secret management)
DATABASE_URL=postgres://user:pass@localhost/hanami_app_production
RODAUTH_PASSWORD_PEPPER=<production-pepper-from-vault>
```

---

## JSON API Implementation (Framework Agnostic)

### Rails API-Only Configuration

```ruby
# lib/rodauth_main.rb
class RodauthMain < Rodauth::Rails::Auth
  configure do
    enable :create_account, :verify_account, :login, :logout,
           :reset_password, :change_password,
           :session_expiration, :active_sessions,
           :password_pepper, :json, :jwt

    # JSON-only mode
    only_json? true
    jwt_secret Rails.application.credentials.dig(:rodauth, :jwt_secret)

    # Session settings
    max_session_lifetime 30 * 86400
    session_inactivity_timeout 3600
    inactive_session_error_status 401

    # Password settings
    password_pepper Rails.application.credentials.dig(:rodauth, :password_pepper)
    password_maximum_bytes 60

    # Disable HTML requirements for JSON API
    require_password_confirmation? false
    require_login_confirmation? false
  end
end
```

### API Sessions Controller

```ruby
# app/controllers/api/sessions_controller.rb
module Api
  class SessionsController < ApiController
    before_action :authenticate_user!

    def index
      sessions = rodauth.account_sessions.map do |session|
        {
          session_id: session[:session_id],
          created_at: session[:created_at].iso8601,
          last_use: session[:last_use].iso8601,
          current: session[:session_id] == rodauth.active_session_id
        }
      end

      render json: { sessions: sessions }
    end

    def destroy
      if rodauth.remove_active_session(params[:id])
        render json: { message: "Session terminated" }
      else
        render json: { error: "Session not found" }, status: :not_found
      end
    end

    def logout_all
      count = rodauth.remove_all_active_sessions_except_for(rodauth.active_session_id)
      render json: { message: "All other sessions terminated", count: count }
    end
  end
end
```

### API Routes

```ruby
# config/routes.rb
namespace :api do
  resources :sessions, only: [:index, :destroy] do
    collection do
      post :logout_all
    end
  end
end
```

### API Client Example

```javascript
// JavaScript client
class SessionManager {
  constructor(apiUrl, authToken) {
    this.apiUrl = apiUrl;
    this.authToken = authToken;
  }

  async getSessions() {
    const response = await fetch(`${this.apiUrl}/api/sessions`, {
      headers: {
        'Authorization': `Bearer ${this.authToken}`,
        'Content-Type': 'application/json'
      }
    });
    return response.json();
  }

  async terminateSession(sessionId) {
    const response = await fetch(`${this.apiUrl}/api/sessions/${sessionId}`, {
      method: 'DELETE',
      headers: {
        'Authorization': `Bearer ${this.authToken}`,
        'Content-Type': 'application/json'
      }
    });
    return response.json();
  }

  async logoutAll() {
    const response = await fetch(`${this.apiUrl}/api/sessions/logout_all`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${this.authToken}`,
        'Content-Type': 'application/json'
      }
    });
    return response.json();
  }
}

// Usage
const manager = new SessionManager('https://api.example.com', userToken);
const sessions = await manager.getSessions();
console.log(sessions);
```

---

## Testing Examples

### Rails RSpec Tests

```ruby
# spec/features/session_management_spec.rb
require 'rails_helper'

RSpec.describe "Session Management", type: :feature do
  let(:user) { create(:account) }

  describe "viewing sessions" do
    it "displays current session" do
      login_as(user)
      visit sessions_path

      expect(page).to have_content("Active Sessions")
      expect(page).to have_content("Current Session")
    end

    it "shows multiple sessions from different devices" do
      # Create sessions
      session1 = create_session_for(user)
      session2 = create_session_for(user)

      login_as(user)
      visit sessions_path

      expect(page).to have_css("tr", count: 3) # 2 old + 1 current
    end
  end

  describe "terminating sessions" do
    it "terminates specific session" do
      other_session = create_session_for(user)
      login_as(user)
      visit sessions_path

      within("tr", text: time_ago(other_session.created_at)) do
        click_button "Terminate"
      end

      expect(page).to have_content("Session terminated")
      expect(DB[:account_active_session_keys].count).to eq(1)
    end

    it "cannot terminate current session" do
      login_as(user)
      visit sessions_path

      within("tr", text: "Current") do
        expect(page).not_to have_button("Terminate")
      end
    end
  end

  describe "global logout" do
    it "terminates all sessions" do
      create_session_for(user)
      create_session_for(user)

      login_as(user)
      visit logout_path

      check "Logout from all devices"
      click_button "Logout"

      expect(DB[:account_active_session_keys].count).to eq(0)
    end
  end

  describe "session expiration" do
    it "expires after inactivity" do
      login_as(user)
      travel 25.hours

      visit dashboard_path
      expect(page).to have_current_path(login_path)
      expect(page).to have_content("session has expired")
    end

    it "expires after max lifetime" do
      login_as(user)
      travel 31.days

      visit dashboard_path
      expect(page).to have_current_path(login_path)
    end
  end
end

# spec/support/session_helpers.rb
module SessionHelpers
  def create_session_for(user)
    db[:account_active_session_keys].insert(
      account_id: user.id,
      session_id: SecureRandom.hex(32),
      created_at: Time.now,
      last_use: Time.now
    )
  end
end
```

### Hanami Tests

```ruby
# spec/features/session_management_spec.rb
require "spec_helper"

RSpec.describe "Session Management" do
  let(:user) { Factory[:account] }
  let(:db) { Sequel.connect(ENV['DATABASE_URL']) }

  describe "viewing sessions" do
    it "displays current session" do
      login_as(user)
      visit "/sessions"

      expect(page).to have_content("Active Sessions")
      expect(page).to have_content("Current")
    end
  end

  describe "terminating sessions" do
    it "removes session from database" do
      other_session = create_session(user)
      login_as(user)

      visit "/sessions"
      within("tr", text: session_id_prefix(other_session)) do
        click_button "Terminate"
      end

      expect(page).to have_content("terminated")
      expect(db[:account_active_session_keys]
        .where(session_id: other_session).count).to eq(0)
    end
  end

  def create_session(user)
    session_id = SecureRandom.hex(32)
    db[:account_active_session_keys].insert(
      account_id: user.id,
      session_id: session_id,
      created_at: Time.now,
      last_use: Time.now
    )
    session_id
  end

  def session_id_prefix(session_id)
    session_id[0..7]
  end
end
```

---

## Additional Resources

- Full integration plan: `/Users/d/Projects/opensource/d/rodauth-rack/docs/FEATURE_INTEGRATION_PLAN.md`
- Quick start guide: `/Users/d/Projects/opensource/d/rodauth-rack/docs/QUICK_START_SESSION_PASSWORD.md`
- Summary document: `/Users/d/Projects/opensource/d/rodauth-rack/docs/SESSION_PASSWORD_FEATURES_SUMMARY.md`
