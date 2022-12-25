# frozen_string_literal: true

# Flattens an Event into the attribute object the API returns.
#
# NOTE: the controllers render only `serializable_hash[:data][:attributes]`, so
# the `users` relationship below is *not* part of any current response body.
# It is declared because the serializer is also used directly in specs and is
# the obvious place to render participants from if a future endpoint needs them.
class EventSerializer
  include JSONAPI::Serializer

  attributes :id, :name, :description, :date, :location, :organizer_id

  has_many :users
end
