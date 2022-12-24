# frozen_string_literal: true

# An event somebody is organizing. `organizer` is the owner; `users` are the
# attendees, joined through the `event_users` table.
class Event < ApplicationRecord
  belongs_to :organizer, class_name: 'User', inverse_of: :organized_events

  has_many :event_users, class_name: 'EventUser', dependent: :destroy, inverse_of: :event
  has_many :users, class_name: 'User', through: :event_users

  validates :name, presence: true, length: { maximum: 30 }
  validates :description, presence: true, length: { maximum: 300 }
  validates :date, presence: true
  validates :location, presence: true

  # `Time.current`, not `Time.now`: the latter reads the *process* time zone,
  # which differs from the application time zone on most deployments and made
  # the boundary of this scope depend on where the server happened to run.
  scope :upcoming_events, -> { where(date: Time.current..).order(date: :asc) }

  scope :recent_first, -> { order(created_at: :desc, id: :desc) }

  scope :organized_by_user, ->(user) { where(organizer_id: user.id) }

  # Events the user neither organizes nor has already joined.
  #
  # The original implementation was
  #   where.not(id: user.events.ids | Event.organized_by_user(user).ids)
  # which ran two extra SELECTs, loaded every matching id into Ruby, and then
  # sent them all back to PostgreSQL inside a `NOT IN (...)` list that grew with
  # the user's history. This is a single statement with a correlated NOT EXISTS,
  # backed by the unique index on event_users(user_id, event_id).
  scope :not_joined_by_user, lambda { |user|
    where.not(organizer_id: user.id)
         .where(
           'NOT EXISTS (SELECT 1 FROM event_users WHERE event_users.event_id = events.id ' \
           'AND event_users.user_id = :user_id)',
           user_id: user.id
         )
  }
end
