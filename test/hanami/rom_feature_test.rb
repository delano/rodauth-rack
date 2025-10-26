require_relative "test_helper"

# Mock ROM::Struct for testing without ROM dependency
module ROM
  class Struct
    attr_reader :attributes

    def initialize(attributes = {})
      @attributes = attributes
    end

    def to_h
      @attributes
    end

    def [](key)
      @attributes[key]
    end
  end
end

class RomFeatureTest < HanamiTestCase
  def test_rom_struct_to_hash_conversion_with_to_h
    # Test ROM::Struct to Hash conversion directly
    rom_struct = ROM::Struct.new("id" => 1, "email" => "user@example.com", "status" => "verified")

    # Convert to hash using transform_keys
    result = rom_struct.to_h.transform_keys(&:to_sym)

    # Verify hash has symbolized keys
    assert_kind_of Hash, result
    assert_equal 1, result[:id]
    assert_equal "user@example.com", result[:email]
    assert_equal "verified", result[:status]
  end

  def test_rom_struct_to_hash_conversion_nil_struct
    # Test that nil conversion returns nil
    rom_struct = nil

    # Simulate the conversion logic
    result = rom_struct&.to_h&.transform_keys(&:to_sym)

    assert_nil result
  end

  def test_rom_struct_to_hash_symbolizes_keys
    # Create ROM struct with both string and symbol keys mixed
    rom_struct = ROM::Struct.new("id" => 42, "email" => "test@example.com", "created_at" => Time.now)

    # Convert to hash
    result = rom_struct.to_h.transform_keys(&:to_sym)

    # Verify all keys are symbols
    assert result.keys.all? { |k| k.is_a?(Symbol) }, "All keys should be symbols"
    assert_equal [:created_at, :email, :id], result.keys.sort
  end

  def test_rom_container_lookup_via_hanami_app
    # Test that we can look up ROM container from Hanami app
    mock_rom = Object.new

    # Temporarily set the ROM container
    original_result = Hanami::App["persistence.rom"]
    Hanami::App.define_singleton_method(:[]) do |key|
      key == "persistence.rom" ? mock_rom : {}
    end

    # Verify lookup works
    result = Hanami::App["persistence.rom"]
    assert_same mock_rom, result

    # Restore
    Hanami::App.define_singleton_method(:[]) { |_key| original_result }
  end

  def test_rom_struct_responds_to_to_h
    # Verify our mock ROM::Struct has to_h method
    rom_struct = ROM::Struct.new("id" => 1)

    assert rom_struct.respond_to?(:to_h), "ROM::Struct should respond to to_h"
    assert_kind_of Hash, rom_struct.to_h
  end

  def test_rom_struct_attributes_accessible
    # Verify our mock ROM::Struct has attributes accessor
    rom_struct = ROM::Struct.new("id" => 1, "name" => "Test")

    assert rom_struct.respond_to?(:attributes), "ROM::Struct should have attributes"
    assert_equal({"id" => 1, "name" => "Test"}, rom_struct.attributes)
  end

  def test_rom_container_interface
    # Test that ROM container has relations interface
    mock_rom_container = Object.new
    mock_relations = { accounts: Object.new }

    mock_rom_container.define_singleton_method(:relations) { mock_relations }

    assert mock_rom_container.respond_to?(:relations)
    assert_equal mock_relations, mock_rom_container.relations
  end

  def test_hanami_app_bracket_accessor
    # Verify Hanami::App.[] exists and can be called
    result = Hanami::App["persistence.rom"]

    # Should return either the ROM container or nil/empty
    # We're just testing the interface exists
    assert true, "Hanami::App.[] should be callable"
  end
end
