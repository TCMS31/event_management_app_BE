# frozen_string_literal: true

# The public shape of a user. Deliberately excludes `encrypted_password`,
# `jti` and the password-reset columns.
class UserSerializer
  include JSONAPI::Serializer

  attributes :id, :email, :name
end
