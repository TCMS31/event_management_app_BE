# frozen_string_literal: true

module Users
  # Devise's `POST /signup` endpoint, rendered as JSON.
  class RegistrationsController < Devise::RegistrationsController
    include RackSessionsFix

    respond_to :json

    private

    # NOTE: the parameter was previously named `current_user`, which shadowed the
    # Devise helper of the same name and made the method read as though it
    # operated on the signed-in user. It is the freshly built resource.
    def respond_with(resource, _opts = {})
      if resource.persisted?
        render json: {
          status: { code: 200, message: 'Signed up successfully.' },
          data: UserSerializer.new(resource).serializable_hash[:data][:attributes]
        }
      else
        render json: { status: resource.errors.full_messages }, status: :unprocessable_entity
      end
    end
  end
end
