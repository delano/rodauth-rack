#!/usr/bin/env ruby
# frozen_string_literal: true

# Console helper for table_guard demo
#
# Usage:
#   ruby examples/sinatra-table-guard/console.rb
#
# Or from IRB/Pry:
#   load 'examples/sinatra-table-guard/console.rb'

require 'stringio'
require_relative "app"
require "rodauth/rack/console_helpers"

# Console context module that provides rodauth instance access
module ConsoleContext
  extend Rodauth::Rack::ConsoleHelpers

  # Create a Rodauth instance for console use
  #
  # Note: We need a minimal Rack env to initialize Rodauth properly.
  # The table_configuration is computed lazily via auth_cached_method,
  # so it will work correctly even though this instance is created
  # outside the normal request cycle.
  def self.rodauth
    @rodauth ||= begin
      # Minimal Rack env required for Rodauth initialization
      env = {
        'REQUEST_METHOD' => 'GET',
        'PATH_INFO' => '/',
        'SCRIPT_NAME' => '',
        'rack.input' => StringIO.new,
        'rack.errors' => $stderr
      }

      # Create a Roda scope instance
      scope = RodauthApp.new(env)

      # Get the Rodauth instance (this properly initializes it)
      scope.rodauth
    end
  end
end

# Make console helpers available at top level
def rodauth; ConsoleContext.rodauth; end
def config; ConsoleContext.config; end
def missing; ConsoleContext.missing; end
def tables; ConsoleContext.tables; end
def status; ConsoleContext.status; end
def db; ConsoleContext.db; end
def show_config; ConsoleContext.show_config; end
def show_missing; ConsoleContext.show_missing; end
def show_status; ConsoleContext.show_status; end
def create_tables!; ConsoleContext.create_tables!; end
def show_migration; ConsoleContext.show_migration; end
def help; ConsoleContext.help; end

# Start console if run directly
if __FILE__ == $PROGRAM_NAME
  require "irb"

  puts "\n" + "=" * 70
  puts "🚀 Rodauth table_guard Console"
  puts "=" * 70

  # Show the help from console helpers
  # help

  IRB.start
end
