# Gemfile

source "https://rubygems.org"

gemspec

gem "irb"
gem "rake", "~> 13.0"
gem "rspec", "~> 3.0"
gem "dry-inflector"

group :development do
  gem "bundler-audit"
  gem "rubocop", "~> 1.81"
  gem "rubocop-rake"
  gem "rubocop-rspec"
end

group :test do
  gem "bcrypt", "~> 3.1"
  gem "capybara"
  gem "jwt", "~> 3.1"
  gem "rack-test", "~> 2.1"
  gem "rails", ">= 6.0"
  gem "rotp"
  gem "rqrcode"
  gem "sequel-activerecord_connection", "~> 2.0"
  gem "sqlite3", "~> 2.0"
  gem "tilt", "~> 2.4"
  gem "tryouts", "~> 3.0"
  gem "warning"
  gem "webauthn" unless RUBY_ENGINE == "jruby"
end
