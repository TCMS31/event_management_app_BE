# frozen_string_literal: true

# Join record: one attendance of one user at one event.
class EventUser < ApplicationRecord
  belongs_to :user, class_name: 'User', optional: false, inverse_of: :event_users
  belongs_to :event, class_name: 'Event', optional: false, inverse_of: :event_users

  # Backed by a unique index (see db/migrate/20231210120000_add_indexes_for_event_lookups.rb).
  # The validation alone left a race: two concurrent joins could both pass the
  # SELECT and both INSERT.
  # The message lives in config/locales/en.yml under
  # activerecord.errors.models.event_user.attributes.user_id.taken.
  validates :user_id, uniqueness: { scope: :event_id }
end
