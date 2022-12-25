# frozen_string_literal: true

# Wires the policy objects in app/policies into the controllers.
#
# Usage: `authorize!(record, :update)`. It raises unless the matching policy
# predicate returns true, and the raise is translated into a 403 by the
# `rescue_from` below, so a forgotten check fails closed rather than open.
module Authorization
  extend ActiveSupport::Concern

  class NotAuthorizedError < StandardError; end

  included do
    rescue_from NotAuthorizedError, with: :render_not_authorized
  end

  private

  def authorize!(record, action)
    raise NotAuthorizedError unless policy_for(record).public_send(:"#{action}?")

    record
  end

  def policy_for(record)
    "#{record.model_name.name}Policy".constantize.new(current_user, record)
  end

  def render_not_authorized(_exception)
    render_errors(I18n.t('errors.not_authorized'), :forbidden)
  end
end
