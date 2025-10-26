# frozen_string_literal: true

RSpec.describe Rodauth::Rack do
  it "has a version number" do
    expect(Rodauth::Rack::VERSION).not_to be_nil
  end

  it "has an Error class" do
    expect(Rodauth::Rack::Error).to be < StandardError
  end

  describe "configuration" do
    it "allows setting adapter_class" do
      adapter = Class.new
      Rodauth::Rack.adapter_class = adapter
      expect(Rodauth::Rack.adapter_class).to eq(adapter)
    end

    it "allows setting account_model" do
      model = Class.new
      Rodauth::Rack.account_model = model
      expect(Rodauth::Rack.account_model).to eq(model)
    end
  end
end
