require_relative "test_helper"

class SessionFeatureTest < HanamiTestCase
  def test_hanami_session_returns_request_session
    auth_class = Class.new(Rodauth::Auth) do
      configure do
        enable :hanami
      end
    end

    mock_scope = Object.new
    mock_request = Hanami::Action::Request.new
    mock_request.session[:user_id] = 123

    mock_scope.define_singleton_method(:hanami_request) { mock_request }

    auth_instance = auth_class.allocate
    auth_instance.instance_variable_set(:@scope, mock_scope)

    # Verify session method returns Hanami request session
    session = auth_instance.send(:session)
    assert_equal 123, session[:user_id]
    assert_same mock_request.session, session
  end

  def test_hanami_flash_returns_current_flash_bucket
    auth_class = Class.new(Rodauth::Auth) do
      configure do
        enable :hanami
      end
    end

    mock_scope = Object.new
    mock_request = Hanami::Action::Request.new
    mock_request.session[:_flash] = { notice: "Test message" }

    mock_scope.define_singleton_method(:hanami_request) { mock_request }

    auth_instance = auth_class.allocate
    auth_instance.instance_variable_set(:@scope, mock_scope)

    # Verify flash method returns :_flash bucket
    flash = auth_instance.send(:flash)
    assert_equal "Test message", flash[:notice]
  end

  def test_set_notice_flash_uses_next_bucket
    auth_class = Class.new(Rodauth::Auth) do
      configure do
        enable :hanami
      end
    end

    mock_scope = Object.new
    mock_request = Hanami::Action::Request.new

    mock_scope.define_singleton_method(:hanami_request) { mock_request }

    auth_instance = auth_class.allocate
    auth_instance.instance_variable_set(:@scope, mock_scope)

    # Set notice flash (should go to :_flash_next)
    auth_instance.send(:set_notice_flash, "Success message")

    # Verify it's in :_flash_next, not :_flash
    assert_equal "Success message", mock_request.session[:_flash_next][:notice]
    assert_nil mock_request.session[:_flash]
  end

  def test_set_error_flash_uses_next_bucket
    auth_class = Class.new(Rodauth::Auth) do
      configure do
        enable :hanami
        flash_error_key :error
      end
    end

    mock_scope = Object.new
    mock_request = Hanami::Action::Request.new

    mock_scope.define_singleton_method(:hanami_request) { mock_request }

    auth_instance = auth_class.allocate
    auth_instance.instance_variable_set(:@scope, mock_scope)

    # Set error flash (should go to :_flash_next)
    auth_instance.send(:set_error_flash, "Error message")

    # Verify it's in :_flash_next with error key
    assert_equal "Error message", mock_request.session[:_flash_next][:error]
    assert_nil mock_request.session[:_flash]
  end

  def test_set_notice_now_flash_uses_current_bucket
    auth_class = Class.new(Rodauth::Auth) do
      configure do
        enable :hanami
      end
    end

    mock_scope = Object.new
    mock_request = Hanami::Action::Request.new

    mock_scope.define_singleton_method(:hanami_request) { mock_request }

    auth_instance = auth_class.allocate
    auth_instance.instance_variable_set(:@scope, mock_scope)

    # Set notice now flash (should go to :_flash)
    auth_instance.send(:set_notice_now_flash, "Immediate notice")

    # Verify it's in :_flash, not :_flash_next
    assert_equal "Immediate notice", mock_request.session[:_flash][:notice]
    assert_nil mock_request.session[:_flash_next]
  end

  def test_set_error_now_flash_uses_current_bucket
    auth_class = Class.new(Rodauth::Auth) do
      configure do
        enable :hanami
        flash_error_key :error
      end
    end

    mock_scope = Object.new
    mock_request = Hanami::Action::Request.new

    mock_scope.define_singleton_method(:hanami_request) { mock_request }

    auth_instance = auth_class.allocate
    auth_instance.instance_variable_set(:@scope, mock_scope)

    # Set error now flash (should go to :_flash)
    auth_instance.send(:set_error_now_flash, "Immediate error")

    # Verify it's in :_flash with error key, not :_flash_next
    assert_equal "Immediate error", mock_request.session[:_flash][:error]
    assert_nil mock_request.session[:_flash_next]
  end

  def test_flash_messages_independent_buckets
    auth_class = Class.new(Rodauth::Auth) do
      configure do
        enable :hanami
      end
    end

    mock_scope = Object.new
    mock_request = Hanami::Action::Request.new

    mock_scope.define_singleton_method(:hanami_request) { mock_request }

    auth_instance = auth_class.allocate
    auth_instance.instance_variable_set(:@scope, mock_scope)

    # Set both current and next flash messages
    auth_instance.send(:set_notice_now_flash, "Current request message")
    auth_instance.send(:set_notice_flash, "Next request message")

    # Verify both buckets are independent
    assert_equal "Current request message", mock_request.session[:_flash][:notice]
    assert_equal "Next request message", mock_request.session[:_flash_next][:notice]
  end
end
