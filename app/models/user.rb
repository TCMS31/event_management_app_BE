# frozen_string_literal: true

# An account. A user both organizes events (`organized_events`) and attends
# other people's events (`events`, through `event_users`).
class User < ApplicationRecord
  # NOTE: `organized_events` used to be declared as a *second* `has_many :events`,
  # which Active Record silently overwrote with the through-association below.
  # The practical effect was that `dependent: :destroy` never ran, so deleting a
  # user who had organized anything raised a foreign-key violation from
  # PostgreSQL. See spec/models/user_spec.rb.
  has_many :organized_events, class_name: 'Event', foreign_key: :organizer_id,
                              dependent: :destroy, inverse_of: :organizer

  has_many :event_users, class_name: 'EventUser', dependent: :destroy, inverse_of: :user
  has_many :events, class_name: 'Event', through: :event_users

  include Devise::JWT::RevocationStrategies::JTIMatcher

  devise :database_authenticatable, :registerable,
         :recoverable, :validatable, :jwt_authenticatable,
         jwt_revocation_strategy: self

  validates :name, presence: true, length: { maximum: 15 }
end
