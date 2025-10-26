require_relative "test_helper"
require "sequel"

class BaseFeatureTest < HanamiTestCase
  def test_inflector_instance_created
    # Create a minimal auth class that includes the feature
    auth_class = Class.new(Rodauth::Auth) do
      configure do
        enable :hanami
      end
    end

    auth_instance = auth_class.allocate

    # Test that inflector is memoized
    inflector1 = auth_instance.send(:inflector)
    inflector2 = auth_instance.send(:inflector)

    assert_kind_of Dry::Inflector, inflector1
    assert_same inflector1, inflector2, "Inflector should be memoized"
  end

  def test_safe_constantize_existing_constant
    auth_class = Class.new(Rodauth::Auth) do
      configure do
        enable :hanami
      end
    end

    auth_instance = auth_class.allocate

    # Test with existing constant
    result = auth_instance.send(:safe_constantize, "String")
    assert_equal String, result
  end

  def test_safe_constantize_missing_constant
    auth_class = Class.new(Rodauth::Auth) do
      configure do
        enable :hanami
      end
    end

    auth_instance = auth_class.allocate

    # Test with non-existent constant
    result = auth_instance.send(:safe_constantize, "NonExistentClass")
    assert_nil result
  end

  def test_inflector_methods_work
    auth_class = Class.new(Rodauth::Auth) do
      configure do
        enable :hanami
      end
    end

    auth_instance = auth_class.allocate
    inflector = auth_instance.send(:inflector)

    # Test inflection methods
    assert_equal "Account", inflector.classify("accounts")
    assert_equal "account", inflector.singularize("accounts")
    assert_equal "Account", inflector.camelize("account")
  end
end
