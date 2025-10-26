# frozen_string_literal: true

require_relative "lib/rodauth/rack/version"

Gem::Specification.new do |spec|
  spec.name = "rodauth-rack"
  spec.version = Rodauth::Rack::VERSION
  spec.authors = ["delano"]
  spec.email = ["delano@onetimesecret.com"]

  spec.summary = "Framework-agnostic Rodauth integration for Rack 3 applications"
  spec.description = "Provides core Rodauth authentication functionality for any Rack framework (Rails, Hanami, Sinatra, Roda, etc.) through a flexible adapter interface."
  spec.homepage = "https://github.com/delano/rodauth-rack"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/delano/rodauth-rack"
  spec.metadata["changelog_uri"] = "https://github.com/delano/rodauth-rack/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Core dependencies
  spec.add_dependency "rodauth", "~> 2.0"
  spec.add_dependency "roda", "~> 3.0"
  spec.add_dependency "sequel", "~> 5.0"
  spec.add_dependency "rack", "~> 3.0"

  # Development dependencies
  spec.add_development_dependency "rack-test", "~> 2.1"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
