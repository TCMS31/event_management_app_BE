# frozen_string_literal: true

FactoryBot.define do
  factory :event_user do
    user
    event
  end
end
