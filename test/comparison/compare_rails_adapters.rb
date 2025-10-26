#!/usr/bin/env ruby
# frozen_string_literal: true

# Comparison test: rodauth-rails gem vs rodauth-rack Rails adapter
#
# This script creates two identical Rails apps and compares the output
# of running the same generators with both implementations.
#
# Usage:
#   ruby test/comparison/compare_rails_adapters.rb
#   VERBOSE=1 ruby test/comparison/compare_rails_adapters.rb

require "fileutils"
require "tmpdir"
require "open3"

class RailsAdapterComparison
  GENERATORS = %w[
    install
    migration
    views
    mailer
  ].freeze

  MIGRATION_FEATURES = %w[
    base
    verify_account
    reset_password
    remember
    otp
  ].freeze

  attr_reader :work_dir, :verbose

  def initialize
    @work_dir = Dir.mktmpdir("rodauth-comparison-")
    @verbose = ENV["VERBOSE"] == "1"
    @failures = []
  end

  def run
    puts "=" * 80
    puts "Rodauth Rails Adapter Comparison Test"
    puts "=" * 80
    puts "Working directory: #{work_dir}"
    puts

    setup_test_apps
    run_generators
    compare_outputs
    cleanup

    report_results
  ensure
    cleanup unless ENV["KEEP_TEMP"] == "1"
  end

  private

  def setup_test_apps
    section "Setting up test Rails applications"

    # App A: Using rodauth-rails gem
    create_rails_app("rodauth-rails-test", rodauth_rails_gem: true)

    # App B: Using rodauth-rack adapter
    create_rails_app("rodauth-rack-test", rodauth_rails_gem: false)
  end

  def create_rails_app(name, rodauth_rails_gem:)
    app_dir = File.join(work_dir, name)

    step "Creating Rails app: #{name}"
    run_command("rails new #{app_dir} --skip-git --skip-bundle --database=sqlite3")

    Dir.chdir(app_dir) do
      # Add appropriate gem to Gemfile
      if rodauth_rails_gem
        append_to_gemfile('gem "rodauth-rails", "~> 1.15"')
      else
        rodauth_rack_path = File.expand_path("../..", __dir__)
        append_to_gemfile("gem \"rodauth-rack\", path: \"#{rodauth_rack_path}\"")
      end

      step "Running bundle install for #{name}"
      run_command("bundle install")
    end
  end

  def run_generators
    section "Running generators on both applications"

    GENERATORS.each do |generator|
      run_generator_comparison(generator)
    end
  end

  def run_generator_comparison(generator)
    step "Running generator: #{generator}"

    args = generator_args(generator)

    # Run on rodauth-rails app
    rails_output = run_in_app("rodauth-rails-test", "rails g rodauth:#{generator} #{args}")

    # Run on rodauth-rack app
    rack_output = run_in_app("rodauth-rack-test", "rails g rodauth:#{generator} #{args}")

    # Compare outputs (normalize namespace differences)
    compare_generator_output(generator, rails_output, rack_output)
  end

  def generator_args(generator)
    case generator
    when "migration"
      MIGRATION_FEATURES.join(" ")
    else
      ""
    end
  end

  def compare_outputs
    section "Comparing generated files"

    dirs_to_compare = %w[
      app/misc
      app/models
      app/controllers
      app/mailers
      app/views/rodauth
      app/views/rodauth_mailer
      config/initializers
      db/migrate
    ]

    dirs_to_compare.each do |dir|
      compare_directory(dir)
    end
  end

  def compare_directory(dir)
    rails_dir = File.join(work_dir, "rodauth-rails-test", dir)
    rack_dir = File.join(work_dir, "rodauth-rack-test", dir)

    return unless File.directory?(rails_dir) && File.directory?(rack_dir)

    step "Comparing directory: #{dir}"

    # Get file lists
    rails_files = Dir.glob("#{rails_dir}/**/*").select { |f| File.file?(f) }
    rack_files = Dir.glob("#{rack_dir}/**/*").select { |f| File.file?(f) }

    # Compare file counts
    rails_relative = rails_files.map { |f| f.sub("#{rails_dir}/", "") }.sort
    rack_relative = rack_files.map { |f| f.sub("#{rack_dir}/", "") }.sort

    if rails_relative != rack_relative
      record_failure("File list mismatch in #{dir}",
                     "rodauth-rails: #{rails_relative.inspect}",
                     "rodauth-rack: #{rack_relative.inspect}")
      return
    end

    # Compare file contents
    rails_relative.each do |relative_path|
      rails_file = File.join(rails_dir, relative_path)
      rack_file = File.join(rack_dir, relative_path)

      compare_file_contents(relative_path, rails_file, rack_file)
    end
  end

  def compare_file_contents(relative_path, rails_file, rack_file)
    rails_content = File.read(rails_file)
    rack_content = File.read(rack_file)

    # Normalize namespace differences
    normalized_rack = normalize_namespace(rack_content)

    if rails_content == normalized_rack
      verbose_log "  ✓ #{relative_path} matches"
    elsif rails_content.gsub(/\s+/, "") == normalized_rack.gsub(/\s+/, "")
      # Check if difference is only in whitespace/formatting
      verbose_log "  Minor whitespace difference in #{relative_path} (acceptable)"
    else
      record_failure("Content mismatch in #{relative_path}",
                     "Expected (rodauth-rails): #{rails_content[0..200]}...",
                     "Got (rodauth-rack): #{rack_content[0..200]}...")
    end
  end

  def normalize_namespace(content)
    content
      .gsub("Rodauth::Rack::Rails", "Rodauth::Rails")
      .gsub("rodauth/rack/rails", "rodauth/rails")
  end

  def compare_generator_output(generator, rails_output, rack_output)
    # Normalize outputs
    normalized_rack = normalize_namespace(rack_output)

    if rails_output == normalized_rack
      verbose_log "  ✓ Generator output matches"
    else
      record_failure("Generator output mismatch for #{generator}",
                     "rodauth-rails: #{rails_output[0..200]}",
                     "rodauth-rack: #{rack_output[0..200]}")
    end
  end

  def run_in_app(app_name, command)
    app_dir = File.join(work_dir, app_name)
    Dir.chdir(app_dir) do
      stdout, stderr, status = Open3.capture3(command)
      unless status.success?
        puts "  ERROR: Command failed: #{command}"
        puts "  STDERR: #{stderr}" unless stderr.to_s.empty?
      end
      stdout + stderr
    end
  end

  def run_command(command)
    verbose_log "  Running: #{command}"
    stdout, stderr, status = Open3.capture3(command)
    unless status.success?
      puts "  ERROR: #{stderr}"
      exit 1
    end
    verbose_log stdout if verbose && !stdout.empty?
  end

  def append_to_gemfile(line)
    File.open("Gemfile", "a") { |f| f.puts "\n#{line}" }
  end

  def cleanup
    return if ENV["KEEP_TEMP"] == "1"

    FileUtils.rm_rf(work_dir) if work_dir && File.directory?(work_dir)
  end

  def report_results
    puts
    puts "=" * 80
    puts "Test Results"
    puts "=" * 80

    if @failures.empty?
      puts "✓ All comparisons passed!"
      puts "  rodauth-rack Rails adapter is functionally equivalent to rodauth-rails gem"
      exit 0
    else
      puts "✗ #{@failures.size} comparison(s) failed:"
      puts
      @failures.each_with_index do |failure, i|
        puts "#{i + 1}. #{failure[:description]}"
        puts "   #{failure[:expected]}"
        puts "   #{failure[:got]}"
        puts
      end
      exit 1
    end
  end

  def record_failure(description, expected, got)
    @failures << { description: description, expected: expected, got: got }
    puts "  ✗ #{description}"
  end

  def section(title)
    puts
    puts "-" * 80
    puts title
    puts "-" * 80
  end

  def step(message)
    puts "• #{message}"
  end

  def verbose_log(message)
    puts message if verbose
  end
end

# Run the comparison if executed directly
RailsAdapterComparison.new.run if __FILE__ == $PROGRAM_NAME
