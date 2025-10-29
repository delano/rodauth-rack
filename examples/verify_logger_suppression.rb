#!/usr/bin/env ruby
# frozen_string_literal: true

# Verification script for logger suppression during table_exists? checks
#
# This demonstrates that table_guard suppresses Sequel's error logs
# when checking for non-existent tables.

require 'bundler/setup'
require 'sequel'
require 'logger'

# Create in-memory database with logger
DB = Sequel.sqlite
DB.loggers << Logger.new($stdout)

puts "=" * 70
puts "Demonstrating logger suppression in table_exists? checks"
puts "=" * 70
puts

# Part 1: Show the problem with direct db.table_exists?
puts "1. WITHOUT suppression (direct db.table_exists?):"
puts "-" * 70
result = DB.table_exists?(:nonexistent_table)
puts "   Result: #{result}"
puts "   ^ Notice the ERROR log above from Sequel"
puts

# Part 2: Show the solution with logger suppression
puts "2. WITH suppression (table_guard's approach):"
puts "-" * 70

# Simulate what table_guard does
original_loggers = DB.loggers.dup
DB.loggers.clear

result = DB.table_exists?(:nonexistent_table)

DB.loggers.clear
original_loggers.each { |logger| DB.loggers << logger }

puts "   Result: #{result}"
puts "   ^ No ERROR log - clean output"
puts

puts "=" * 70
puts "Verification complete!"
puts "=" * 70
