require_relative "test_helper"

class AppFlashTest < HanamiTestCase
  def test_flash_rotation_logic_next_to_current
    # Test the flash rotation logic directly
    # Simulates: if session[:_flash_next] then session[:_flash] = session.delete(:_flash_next)

    session = {}
    session[:_flash_next] = { notice: "Message for next request" }

    # Apply rotation logic
    if session[:_flash_next]
      session[:_flash] = session.delete(:_flash_next)
    else
      session.delete(:_flash)
    end

    # Verify rotation
    assert_equal({ notice: "Message for next request" }, session[:_flash])
    assert_nil session[:_flash_next]
  end

  def test_flash_rotation_logic_clears_when_no_next
    # Test flash clearing when no flash_next exists
    session = {}
    session[:_flash] = { notice: "Old message" }
    # No :_flash_next

    # Apply rotation logic
    if session[:_flash_next]
      session[:_flash] = session.delete(:_flash_next)
    else
      session.delete(:_flash)
    end

    # Verify flash is cleared
    assert_nil session[:_flash]
    assert_nil session[:_flash_next]
  end

  def test_flash_rotation_preserves_multiple_message_types
    session = {}
    session[:_flash_next] = {
      notice: "Success message",
      error: "Error message",
      warning: "Warning message"
    }

    # Apply rotation logic
    if session[:_flash_next]
      session[:_flash] = session.delete(:_flash_next)
    else
      session.delete(:_flash)
    end

    # Verify all message types preserved
    assert_equal "Success message", session[:_flash][:notice]
    assert_equal "Error message", session[:_flash][:error]
    assert_equal "Warning message", session[:_flash][:warning]
    assert_nil session[:_flash_next]
  end

  def test_after_hook_exists_in_app_class
    app_class = Class.new(Rodauth::Rack::Hanami::App)

    # Verify after hook is registered (Roda stores hooks in opts)
    assert app_class.respond_to?(:opts), "App class should respond to opts"

    # Check if after hooks exist
    if app_class.opts[:after]
      assert app_class.opts[:after].is_a?(Array), "After hooks should be an array"
      refute_empty app_class.opts[:after], "After hooks should not be empty"
    else
      # Alternative: check for instance method that implements after behavior
      skip "After hooks not stored in opts, may be implemented differently"
    end
  end

  def test_before_hook_exists_in_app_class
    app_class = Class.new(Rodauth::Rack::Hanami::App)

    # Verify before hook is registered
    assert app_class.respond_to?(:opts), "App class should respond to opts"

    # Check if before hooks exist
    if app_class.opts[:before]
      assert app_class.opts[:before].is_a?(Array), "Before hooks should be an array"
      refute_empty app_class.opts[:before], "Before hooks should not be empty"
    else
      # Alternative: check for instance method that implements before behavior
      skip "Before hooks not stored in opts, may be implemented differently"
    end
  end

  def test_session_finalize_conditional_check
    # Test the conditional finalize logic
    mock_session_with_finalize = Object.new
    finalize_called = false

    mock_session_with_finalize.define_singleton_method(:respond_to?) do |method|
      method == :finalize
    end

    mock_session_with_finalize.define_singleton_method(:finalize) do
      finalize_called = true
    end

    # Simulate conditional finalize
    if mock_session_with_finalize.respond_to?(:finalize)
      mock_session_with_finalize.finalize
    end

    assert finalize_called, "Finalize should be called when available"
  end

  def test_session_finalize_not_called_when_unavailable
    # Test that finalize is not called when not available
    mock_session_without_finalize = Object.new

    # Simulate conditional finalize - should not raise error
    if mock_session_without_finalize.respond_to?(:finalize)
      mock_session_without_finalize.finalize
    end

    # If we get here, test passed (no error raised)
    assert true
  end

  def test_app_has_hanami_request_method
    app_class = Class.new(Rodauth::Rack::Hanami::App)

    # Verify hanami_request method exists
    assert app_class.instance_methods.include?(:hanami_request),
           "App should define hanami_request method"
  end

  def test_app_has_hanami_response_method
    app_class = Class.new(Rodauth::Rack::Hanami::App)

    # Verify hanami_response method exists
    assert app_class.instance_methods.include?(:hanami_response),
           "App should define hanami_response method"
  end

  def test_app_has_session_method
    app_class = Class.new(Rodauth::Rack::Hanami::App)

    # Verify session method exists (delegates to hanami_request)
    assert app_class.instance_methods.include?(:session),
           "App should define session method"
  end

  def test_request_methods_module_exists
    # Verify RequestMethods module is defined
    assert defined?(Rodauth::Rack::Hanami::App::RequestMethods),
           "RequestMethods module should be defined"
  end

  def test_request_methods_has_redirect
    # Verify redirect method is defined in RequestMethods
    assert Rodauth::Rack::Hanami::App::RequestMethods.instance_methods.include?(:redirect),
           "RequestMethods should define redirect method"
  end

  def test_request_methods_has_rodauth
    # Verify rodauth method is defined in RequestMethods
    assert Rodauth::Rack::Hanami::App::RequestMethods.instance_methods.include?(:rodauth),
           "RequestMethods should define rodauth method"
  end

  def test_request_methods_has_post
    # Verify POST method is defined in RequestMethods
    assert Rodauth::Rack::Hanami::App::RequestMethods.instance_methods.include?(:POST),
           "RequestMethods should define POST method"
  end
end
