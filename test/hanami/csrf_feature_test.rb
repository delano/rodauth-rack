require_relative "test_helper"
require "rack/utils"

class CsrfFeatureTest < HanamiTestCase
  def test_csrf_timing_safe_comparison
    auth_class = Class.new(Rodauth::Auth) do
      configure do
        enable :hanami
        enable :json
      end
    end

    # Create mock scope class with opts
    mock_scope_class = Class.new do
      def self.opts
        {}
      end

      def hanami_request
        @hanami_request
      end

      def initialize(request)
        @hanami_request = request
      end
    end

    mock_request = Hanami::Action::Request.new
    mock_request.session[:_csrf_token] = "valid_token_12345"
    mock_request.params["_csrf_token"] = "valid_token_12345"

    mock_scope = mock_scope_class.new(mock_request)

    auth_instance = auth_class.allocate
    auth_instance.instance_variable_set(:@scope, mock_scope)

    # Test that CSRF check passes with matching tokens
    assert_silent do
      auth_instance.send(:hanami_check_csrf!)
    end
  end

  def test_csrf_fails_with_wrong_token
    auth_class = Class.new(Rodauth::Auth) do
      configure do
        enable :hanami
        enable :json
        only_json? false  # Ensure CSRF is enabled
      end
    end

    mock_scope = Object.new
    mock_request = Hanami::Action::Request.new
    mock_request.session[:_csrf_token] = "valid_token_12345"
    mock_request.params["_csrf_token"] = "wrong_token"
    mock_request.env["HTTP_X_CSRF_TOKEN"] = nil  # No header token either

    mock_scope.define_singleton_method(:hanami_request) { mock_request }

    auth_instance = auth_class.allocate
    auth_instance.instance_variable_set(:@scope, mock_scope)

    # Verify CSRF is enabled for this test
    assert auth_instance.send(:hanami_csrf_enabled?), "CSRF should be enabled"

    # Test that CSRF check raises error with wrong token
    error = assert_raises(Rodauth::Rack::Hanami::Error) do
      auth_instance.send(:hanami_check_csrf!)
    end

    assert_match(/CSRF token verification failed/, error.message)
  end

  def test_csrf_token_generation
    auth_class = Class.new(Rodauth::Auth) do
      configure do
        enable :hanami
        enable :json
      end
    end

    mock_scope = Object.new
    mock_request = Hanami::Action::Request.new

    mock_scope.define_singleton_method(:hanami_request) { mock_request }

    auth_instance = auth_class.allocate
    auth_instance.instance_variable_set(:@scope, mock_scope)

    # Generate CSRF token
    token = auth_instance.send(:hanami_csrf_token)

    # Should be a base64 string
    assert_kind_of String, token
    refute_empty token
    assert_equal token, mock_request.session[:_csrf_token]
  end

  def test_csrf_tag_output
    auth_class = Class.new(Rodauth::Auth) do
      configure do
        enable :hanami
        enable :json
      end
    end

    mock_scope = Object.new
    mock_request = Hanami::Action::Request.new
    mock_request.session[:_csrf_token] = "test_token"

    mock_scope.define_singleton_method(:hanami_request) { mock_request }

    auth_instance = auth_class.allocate
    auth_instance.instance_variable_set(:@scope, mock_scope)

    tag = auth_instance.send(:hanami_csrf_tag)

    assert_match(/<input/, tag)
    assert_match(/type="hidden"/, tag)
    assert_match(/name="_csrf_token"/, tag)
    assert_match(/value="test_token"/, tag)
  end
end
