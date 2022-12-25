# frozen_string_literal: true

# Base class for the authorization layer.
#
# A policy answers one question: "may this user perform this action on this
# record?". Keeping that answer out of the controllers means the rule is stated
# once, is unit-testable on its own, and cannot be forgotten on a new endpoint —
# `Authorization#authorize!` raises unless a policy explicitly says yes.
#
# Every predicate denies by default. Subclasses opt in.
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def show? = false
  def create? = false
  def update? = false
  def destroy? = false
end
