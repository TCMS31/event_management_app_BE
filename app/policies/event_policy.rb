# frozen_string_literal: true

# Who may do what to an Event.
#
# Reading is open to any signed-in user: the "Join upcoming events" screen links
# straight to an event the reader does not own yet. Writing is restricted to the
# organizer. Before this class existed, `update` and `destroy` were reachable by
# *any* authenticated user for *any* event (see spec/requests/api/v1/events_authorization_spec.rb).
class EventPolicy < ApplicationPolicy
  def show? = user.present?
  def create? = user.present?
  def update? = organizer?
  def destroy? = organizer?

  # Organizers are already attending their own event, and it is filtered out of
  # the joinable list, so joining it is a no-op that would otherwise create a
  # confusing "you joined your own event" row.
  def join? = user.present? && !organizer?

  private

  def organizer? = user.present? && record.organizer_id == user.id
end
