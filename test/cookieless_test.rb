require File.expand_path("../test_helper", __FILE__)

RSpec.describe Rack::Cookieless, type: :feature do
  include Rack::Test::Methods

  let(:inner_app)      { Rails.application }
  let(:app)            { Rack::Cookieless.new inner_app }
  let(:session_key)    { 'session_id' }
  let(:session_params) { { session_key => 'session-value' } }

  before do
    header 'Set-Cookie', 'some-cookie'
    allow(Rails.cache).to receive(:exist?).and_return true
  end

  subject { last_response.original_headers['Location'] }

  describe '#convert_url' do
    context 'when url contains anchor' do
      let(:redirect_url) { '/internal_redirect#anchor' }

      subject { app.send(:convert_url, redirect_url, 'sessionid') }

      it "doesn't escapes the hash in url" do
        is_expected.to include redirect_url
      end
    end
  end

  context 'when cookies are enabled' do
    let(:rack_env) { { 'HTTP_COOKIE' => 'some-cookie' } }

    describe 'non-redirect response' do
      subject { last_response.body }

      it 'does not have session key in response body' do
        get '/', session_params, rack_env
        is_expected.not_to include session_key
      end
    end

    describe 'internal redirect response' do
      it 'does not have session key in [Location] header' do
        get '/internal_redirect', session_params, rack_env
        is_expected.not_to include session_key
      end
    end

    describe 'external redirect response' do
      it 'does not have session key in [Location] header' do
        get '/external_redirect', session_params, rack_env
        is_expected.not_to include session_key
      end
    end
  end

  context 'when cookies are disabled' do
    let(:rack_env) { { 'HTTP_COOKIE' => nil } }

    describe 'non-redirect response' do
      subject { last_response.body }

      it 'has session key in response body' do
        get '/', session_params, rack_env
        is_expected.to include session_key
      end
    end

    describe 'internal redirect response' do
      it 'has session key in [Location] header' do
        get '/internal_redirect', session_params, rack_env
        is_expected.to include session_key
      end
    end

    describe 'external redirect response' do
      it 'does not have session key in [Location] header' do
        get '/external_redirect', session_params, rack_env
        is_expected.not_to include session_key
      end
    end
  end
end
