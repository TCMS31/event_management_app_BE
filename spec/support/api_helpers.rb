# frozen_string_literal: true

# Helpers for request specs that need to go through the real JWT flow rather
# than Warden's `sign_in` shortcut.
module ApiHelpers
  # Registers and logs a user in over HTTP and returns the bearer token that
  # `POST /login` puts in the Authorization response header.
  def login_as_api(user, password: 'password123')
    post '/login', params: { user: { email: user.email, password: password } }, as: :json
    response.headers['Authorization']
  end

  def auth_headers(token)
    { 'Authorization' => token }
  end

  def json_body
    JSON.parse(response.body)
  end
end

RSpec.configure do |config|
  config.include ApiHelpers, type: :request
end
