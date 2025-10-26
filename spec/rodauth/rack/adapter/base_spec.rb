# frozen_string_literal: true

require "spec_helper"

RSpec.describe Rodauth::Rack::Adapter::Base do
  let(:request) { instance_double(Rack::Request, session: {}, path: "/login", params: {}, env: {}) }
  let(:response) { instance_double(Rack::Response, status: 200) }
  let(:adapter) { described_class.new(request, response) }

  describe "#initialize" do
    it "sets request and response" do
      expect(adapter.request).to eq(request)
      expect(adapter.response).to eq(response)
    end
  end

  describe "abstract methods" do
    describe "#render" do
      it "raises NotImplementedError" do
        expect { adapter.render("login") }.to raise_error(NotImplementedError, /render/)
      end
    end

    describe "#view_path" do
      it "raises NotImplementedError" do
        expect { adapter.view_path }.to raise_error(NotImplementedError, /view_path/)
      end
    end

    describe "#csrf_token" do
      it "raises NotImplementedError" do
        expect { adapter.csrf_token }.to raise_error(NotImplementedError, /csrf_token/)
      end
    end

    describe "#csrf_field" do
      it "raises NotImplementedError" do
        expect { adapter.csrf_field }.to raise_error(NotImplementedError, /csrf_field/)
      end
    end

    describe "#valid_csrf_token?" do
      it "raises NotImplementedError" do
        expect { adapter.valid_csrf_token?("token") }.to raise_error(NotImplementedError, /valid_csrf_token/)
      end
    end

    describe "#flash" do
      it "raises NotImplementedError" do
        expect { adapter.flash }.to raise_error(NotImplementedError, /flash/)
      end
    end

    describe "#url_for" do
      it "raises NotImplementedError" do
        expect { adapter.url_for("/path") }.to raise_error(NotImplementedError, /url_for/)
      end
    end

    describe "#deliver_email" do
      it "raises NotImplementedError" do
        expect { adapter.deliver_email(:reset_password) }.to raise_error(NotImplementedError, /deliver_email/)
      end
    end

    describe "#account_model" do
      it "raises NotImplementedError" do
        expect { adapter.account_model }.to raise_error(NotImplementedError, /account_model/)
      end
    end

    describe "#rodauth_config" do
      it "raises NotImplementedError" do
        expect { adapter.rodauth_config }.to raise_error(NotImplementedError, /rodauth_config/)
      end
    end

    describe "#db" do
      it "raises NotImplementedError" do
        expect { adapter.db }.to raise_error(NotImplementedError, /db/)
      end
    end
  end

  describe "implemented methods" do
    describe "#session" do
      it "returns request session" do
        expect(adapter.session).to eq(request.session)
      end
    end

    describe "#clear_session" do
      it "clears the request session" do
        session = {}
        allow(request).to receive(:session).and_return(session)
        session[:user_id] = 123

        adapter.clear_session
        expect(session).to be_empty
      end
    end

    describe "#request_path" do
      it "returns the request path" do
        expect(adapter.request_path).to eq("/login")
      end
    end

    describe "#params" do
      it "returns request params" do
        params = { "email" => "test@example.com" }
        allow(request).to receive(:params).and_return(params)
        expect(adapter.params).to eq(params)
      end
    end

    describe "#env" do
      it "returns request environment" do
        env = { "REQUEST_METHOD" => "POST" }
        allow(request).to receive(:env).and_return(env)
        expect(adapter.env).to eq(env)
      end
    end

    describe "#redirect" do
      it "redirects the response to a path" do
        expect(response).to receive(:redirect).with("/dashboard", 302)
        adapter.redirect("/dashboard")
      end

      it "accepts custom status" do
        expect(response).to receive(:redirect).with("/dashboard", 301)
        adapter.redirect("/dashboard", status: 301)
      end
    end

    describe "#status=" do
      it "sets the response status" do
        expect(response).to receive(:status=).with(404)
        adapter.status = 404
      end
    end
  end
end
