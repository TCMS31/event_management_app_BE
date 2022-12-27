# frozen_string_literal: true

FactoryBot.define do
  factory :event do
    # Event#name is capped at 30 characters, so the generated name is truncated
    # before the sequence number is appended (30 = 24 + 2 + up to 4 digits).
    sequence(:name) do |n|
      "#{Faker::Book.title} #{%w[Conference Seminar Workshop].sample}"[0, 24] + " ##{n}"
    end
    description { Faker::Lorem.paragraph }
    date { Faker::Time.forward(days: 30, period: :all) }
    location { Faker::Address.city }
    organizer factory: :user

    trait :past do
      date { 2.days.ago }
    end

    factory :event_with_users do
      transient do
        users_count { 5 }
      end

      after(:create) do |event, evaluator|
        create_list(:user, evaluator.users_count).each do |user|
          create(:event_user, user: user, event: event)
        end
      end
    end
  end
end
