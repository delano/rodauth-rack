# frozen_string_literal: true

RSpec.describe Rodauth::Tools do
  it "has a version number" do
    expect(Rodauth::Tools::VERSION).not_to be_nil
  end

  it "has an Error class" do
    expect(Rodauth::Tools::Error).to be < StandardError
  end

  describe "Rack compatibility" do
    it "delegates release to Rack gem" do
      expect(Rodauth::Tools.release).to eq(::Rack.release)
    end

    it "provides release_version method" do
      expect(Rodauth::Tools).to respond_to(:release_version)
    end
  end
end
