# frozen_string_literal: true

# Cross-Origin Resource Sharing for the React client.
#
# The browser can only read the login response's `Authorization` header because
# it is listed under `expose`; without that line the client never sees the JWT.
#
# CORS_ORIGINS defaults to '*' so a fresh clone works, but any deployment that
# matters should pin it to the client's origin -- a wildcard here means any site
# a signed-in user visits can call this API with their token.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*ENV.fetch('CORS_ORIGINS', '*').split(',').map(&:strip))

    resource '*',
             headers: :any,
             methods: %i[get post put patch delete options head],
             expose: %w[Authorization X-Total-Count X-Page X-Per-Page]
  end
end
