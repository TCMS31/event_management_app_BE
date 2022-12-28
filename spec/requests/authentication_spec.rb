# frozen_string_literal: true

require 'rails_helper'

# Exercises the Devise + devise-jwt endpoints over HTTP, using the real bearer
# token rather than Warden's `sign_in` shortcut, so the signing key, the
# Authorization response header and the jti revocation strategy are all covered.
RSpec.describe 'Authentication', type: :request do
  describe 'POST /signup' do
    let(:params) do
      { user: { name: 'Ada', email: 'ada@example.com', password: 'password123' } }
    end

    it 'creates the account and echoes the serialized user' do
      expect { post '/signup', params: params, as: :json }.to change(User, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(json_body['status']).to include('code' => 200, 'message' => 'Signed up successfully.')
      expect(json_body['data']).to include('email' => 'ada@example.com', 'name' => 'Ada')
      expect(json_body['data']).not_to include('encrypted_password', 'jti')
    end

    # The React client renders `error.response.data.status` as a list, so this
    # shape is load-bearing.
    it 'returns an array of messages under "status" when invalid' do
      post '/signup', params: { user: { email: 'nope', password: 'x' } }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body['status']).to be_an(Array)
      expect(json_body['status']).to be_present
    end
  end

  describe 'POST /login' do
    let!(:user) { create(:user, password: 'password123') }

    it 'returns the bearer token in the Authorization header' do
      post '/login', params: { user: { email: user.email, password: 'password123' } }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.headers['Authorization']).to match(/\ABearer .+\z/)
      expect(json_body.dig('status', 'data', 'user', 'email')).to eq(user.email)
    end

    it 'rejects a wrong password without issuing a token' do
      post '/login', params: { user: { email: user.email, password: 'wrong' } }, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(response.headers['Authorization']).to be_nil
    end
  end

  describe 'the bearer token' do
    let!(:user) { create(:user, password: 'password123') }

    it 'authenticates API requests' do
      token = login_as_api(user)
      create(:event, organizer: user)

      get '/api/v1/events', headers: auth_headers(token)

      expect(response).to have_http_status(:ok)
      expect(json_body.size).to eq(1)
    end

    it 'is rejected once the session is logged out' do
      token = login_as_api(user)

      delete '/logout', headers: auth_headers(token)
      expect(response).to have_http_status(:ok)
      expect(json_body['message']).to eq('Logged out successfully.')

      get '/api/v1/events', headers: auth_headers(token)
      expect(response).to have_http_status(:unauthorized)
    end

    it 'is rejected when tampered with' do
      token = login_as_api(user)
      tampered = "#{token[0..-3]}xx"

      get '/api/v1/events', headers: auth_headers(tampered)

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'DELETE /logout without a session' do
    it 'reports that there is nothing to log out of' do
      delete '/logout'

      expect(response).to have_http_status(:unauthorized)
      expect(json_body['message']).to eq("Couldn't find an active session.")
    end
  end
end
