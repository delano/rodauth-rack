# frozen_string_literal: true

require "rodauth/rack/rails/tasks/routes"

namespace :rodauth do
  desc "Lists endpoints that will be routed by your Rodauth app"
  task routes: :environment do
    puts "Routes handled by #{Rodauth::Rack::Rails.app}:"

    Rodauth::Rack::Rails.app.opts[:rodauths].each_value do |auth_class|
      Rodauth::Rack::Rails::Tasks::Routes.new(auth_class).call
    end
  end
end
