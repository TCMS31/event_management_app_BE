# frozen_string_literal: true

FactoryBot.define do
  # NOTE: the previous version set `encrypted_password` *and* `password`, which
  # only worked because FactoryBot happens to assign attributes in declaration
  # order, and hardcoded a `jti` that Devise::JWT's JTIMatcher generates anyway.
  # Both are gone. `password` is a fixed known value so request specs can log in
  # over HTTP and exercise the real token flow.
  factory :user do
    email { Faker::Internet.unique.email }
    name { Faker::Name.name.slice(0, 15) }
    password { 'password123' }
  end
end
