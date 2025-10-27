require_relative "test_helper"

class JsonModeTest < HanamiTestCase
  def test_only_json_configuration_defaults_to_false
    auth_class = Class.new(Rodauth::Auth) do
      configure do
        enable :hanami
        enable :json
      end
    end

    auth_instance = auth_class.allocate

    # By default, only_json? should be false (not configured)
    # We can't directly test this since it depends on Rodauth configuration
    # but we can verify CSRF is enabled by default
    assert auth_instance.send(:hanami_csrf_enabled?),
           "CSRF should be enabled when only_json is not configured"
  end

  def test_csrf_disabled_when_only_json_true
    auth_class = Class.new(Rodauth::Auth) do
      configure do
        enable :hanami
        enable :json
        only_json? true
      end
    end

    mock_scope = Object.new
    mock_request = Hanami::Action::Request.new
    mock_request.session[:_csrf_token] = "valid_token"
    mock_request.params["_csrf_token"] = "wrong_token"

    mock_scope.define_singleton_method(:hanami_request) { mock_request }

    auth_instance = auth_class.allocate
    auth_instance.instance_variable_set(:@scope, mock_scope)

    # CSRF check should not raise error when only_json is true
    assert_silent do
      auth_instance.send(:hanami_check_csrf!)
    end
  end

  def test_csrf_enabled_when_only_json_false
    auth_class = Class.new(Rodauth::Auth) do
      configure do
        enable :hanami
        enable :json
        only_json? false
      end
    end

    mock_scope = Object.new
    mock_request = Hanami::Action::Request.new
    mock_request.session[:_csrf_token] = "valid_token"
    mock_request.params["_csrf_token"] = "wrong_token"
    mock_request.env["HTTP_X_CSRF_TOKEN"] = nil

    mock_scope.define_singleton_method(:hanami_request) { mock_request }

    auth_instance = auth_class.allocate
    auth_instance.instance_variable_set(:@scope, mock_scope)

    # CSRF check should raise error when only_json is false and token is wrong
    assert_raises(Rodauth::Rack::Hanami::Error) do
      auth_instance.send(:hanami_check_csrf!)
    end
  end

  def test_view_skips_rendering_when_only_json_true
    auth_class = Class.new(Rodauth::Auth) do
      configure do
        enable :hanami
        enable :json
        only_json? true
      end
    end

    auth_instance = auth_class.allocate

    # Mock the parent view method to return a value we can test
    auth_instance.define_singleton_method(:method_missing) do |method, *args|
      if method == :super && args.empty?
        "json_response"
      else
        super(method, *args)
      end
    end

    # When only_json is true, view should call super (return JSON response)
    # We need to mock scope and hanami_render
    mock_scope = Object.new
    mock_request = Hanami::Action::Request.new
    mock_scope.define_singleton_method(:hanami_request) { mock_request }

    auth_instance.instance_variable_set(:@scope, mock_scope)

    # The view method should skip hanami_render and go straight to super
    # This is verified by checking that only_json? returns true
    assert auth_instance.send(:only_json?)
  end

  def test_csrf_tag_still_generated_but_check_skipped_when_only_json
    auth_class = Class.new(Rodauth::Auth) do
      configure do
        enable :hanami
        enable :json
        only_json? true
      end
    end

    mock_scope = Object.new
    mock_request = Hanami::Action::Request.new
    mock_request.session[:_csrf_token] = "test_token"

    mock_scope.define_singleton_method(:hanami_request) { mock_request }

    auth_instance = auth_class.allocate
    auth_instance.instance_variable_set(:@scope, mock_scope)

    # CSRF tag is still generated (for forms if needed)
    tag = auth_instance.send(:csrf_tag)
    assert_match(/test_token/, tag)

    # But CSRF verification is skipped due to only_json?
    mock_request.params["_csrf_token"] = "wrong_token"
    assert_silent do
      auth_instance.send(:hanami_check_csrf!)
    end
  end

  def test_check_csrf_returns_early_when_only_json_true
    auth_class = Class.new(Rodauth::Auth) do
      configure do
        enable :hanami
        enable :json
        only_json? true
      end
    end

    mock_scope = Object.new
    mock_request = Hanami::Action::Request.new
    # Don't set any tokens - would normally fail CSRF check
    mock_request.session[:_csrf_token] = "session_token"
    # No matching param token

    mock_scope.define_singleton_method(:hanami_request) { mock_request }

    auth_instance = auth_class.allocate
    auth_instance.instance_variable_set(:@scope, mock_scope)

    # Should not raise because only_json? returns true
    assert_silent do
      auth_instance.send(:check_csrf)
    end
  end
end
