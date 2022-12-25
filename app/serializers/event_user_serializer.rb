# frozen_string_literal: true

# Flattens an attendance record into the attribute object the API returns.
class EventUserSerializer
  include JSONAPI::Serializer

  attributes :id, :user_id, :event_id

  belongs_to :user
  belongs_to :event
end
