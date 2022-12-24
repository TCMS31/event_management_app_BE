# frozen_string_literal: true

# Two indexes the original schema was missing.
#
# 1. event_users(user_id, event_id) UNIQUE — the "a user can join an event only
#    once" rule existed only as an Active Record validation, so two concurrent
#    requests could both pass the SELECT and both INSERT. The index also makes
#    the correlated NOT EXISTS in Event.not_joined_by_user an index-only probe
#    instead of a sequential scan of the join table.
# 2. events(date) — Event.upcoming_events filters and sorts on it.
class AddIndexesForEventLookups < ActiveRecord::Migration[7.1]
  def change
    add_index :event_users, %i[user_id event_id], unique: true,
                                                  name: 'index_event_users_on_user_id_and_event_id'
    add_index :events, :date
  end
end
