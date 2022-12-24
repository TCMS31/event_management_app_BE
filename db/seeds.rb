# frozen_string_literal: true

# Idempotent demo data. Safe to run repeatedly: everything is keyed on email or
# on (organizer, name), so `bin/rails db:seed` twice produces the same database.
#
# NOTE: this used to `require 'factory_bot'` and call the *test* factories,
# which tied `db:seed` to a development-and-test-only gem and would fail on any
# machine that ran it with RAILS_ENV=production.

PASSWORD = ENV.fetch('SEED_PASSWORD', 'password123')

organizers = [
  { name: 'Ada Lovelace', email: 'ada@example.com' },
  { name: 'Grace Hopper', email: 'grace@example.com' },
  { name: 'Alan Turing',  email: 'alan@example.com' }
].map do |attrs|
  User.find_or_initialize_by(email: attrs[:email]).tap do |user|
    user.name = attrs[:name]
    user.password = PASSWORD
    user.save!
  end
end

EVENTS = [
  ['Rails Performance Day', 'A day of profiling, query plans and cache strategy.', 'Manchester', 7],
  ['PostgreSQL Indexing Workshop', 'Hands-on session on B-tree, GIN and partial indexes.', 'Leeds', 14],
  ['API Design Clinic', 'Bring an endpoint, leave with a better contract.', 'London', 21],
  ['Testing Without Mocks', 'Writing suites that fail for the right reasons.', 'Bristol', 28],
  ['Retro: Things We Shipped', 'An honest look at last quarter.', 'Remote', 35],
  ['Archived Kickoff', 'Last season opener, kept to exercise the past-event filter.', 'Sheffield', -10]
].freeze

events = EVENTS.each_with_index.map do |(name, description, location, days), index|
  organizer = organizers[index % organizers.size]
  Event.find_or_initialize_by(organizer: organizer, name: name).tap do |event|
    event.description = description
    event.location = location
    event.date = days.days.from_now
    event.save!
  end
end

# Everyone joins the events they did not organize, so joined_events and
# get_events both return something on a fresh seed.
organizers.each do |user|
  events.reject { |event| event.organizer_id == user.id }.take(2).each do |event|
    EventUser.find_or_create_by!(user: user, event: event)
  end
end

puts "Seeded #{User.count} users, #{Event.count} events, #{EventUser.count} attendances."
puts "Sign in with any of: #{organizers.map(&:email).join(', ')} / #{PASSWORD}"
