# frozen_string_literal: true

module Users
  # Devise's session endpoints, rendered as JSON.
  #
  # `POST /login`   dispatches a JWT in the `Authorization` response header
  #                 (see the `jwt.dispatch_requests` entry in the Devise initializer).
  # `DELETE /logout` revokes it by rotating the user's `jti`.
  class SessionsController < Devise::SessionsController
    include RackSessionsFix

    respond_to :json

    # Devise signs the user out *before* `respond_to_on_destroy` runs, so the
    # identity has to be captured while Warden still knows about it. The previous
    # implementation re-decoded the bearer token by hand against a hardcoded
    # signing key; reading it from Warden is both correct and keeps the secret in
    # exactly one place.
    # rubocop:disable Rails/LexicallyScopedActionFilter -- `destroy` is inherited
    # from Devise::SessionsController and deliberately not overridden here.
    prepend_before_action :capture_signed_out_user, only: :destroy
    # rubocop:enable Rails/LexicallyScopedActionFilter

    private

    def capture_signed_out_user
      @signed_out_user = current_user
    end

    def respond_with(resource, _opts = {})
      render json: {
        status: {
          code: 200,
          message: 'Logged in successfully.',
          data: { user: UserSerializer.new(resource).serializable_hash[:data][:attributes] }
        }
      }, status: :ok
    end

    def respond_to_on_destroy
      if @signed_out_user
        render json: { status: 200, message: 'Logged out successfully.' }, status: :ok
      else
        render json: { status: 401, message: "Couldn't find an active session." }, status: :unauthorized
      end
    end
  end
end
