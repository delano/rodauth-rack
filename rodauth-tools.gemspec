# rodauth-tools.gemspec

require_relative 'lib/rodauth/tools/version'

Gem::Specification.new do |spec|
  spec.name = 'rodauth-tools'
  spec.version = Rodauth::Tools::VERSION
  spec.authors = ['delano']
  spec.summary = 'Framework-agnostic Rodauth tools'
  spec.required_ruby_version = '>= 3.2.0'

  spec.files = Dir['lib/**/*', 'LICENSE*', 'README*']
  spec.require_paths = ['lib']

  # Runtime dependencies only - needed by projects that use this via git
  spec.add_dependency 'dry-inflector', '~> 1.1'
  spec.add_dependency 'rack', '~> 3.2'
  spec.add_dependency 'roda', '~> 3.96'
  spec.add_dependency 'rodauth', '~> 2.41'
  spec.add_dependency 'rodauth-model', '~> 0.2'
  spec.add_dependency 'sequel', '~> 5.0'
end
