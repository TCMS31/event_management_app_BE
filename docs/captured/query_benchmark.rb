require 'benchmark'

ActiveRecord::Base.logger = nil

EVENTS = 20_000
JOINED = 5_000

user = User.find_or_create_by!(email: 'bench@example.com') { |u| u.name = 'Bench'; u.password = 'password123' }
other = User.find_or_create_by!(email: 'bench2@example.com') { |u| u.name = 'Bench2'; u.password = 'password123' }

if Event.where(organizer: other).count < EVENTS
  puts "seeding #{EVENTS} events..."
  now = Time.current
  rows = Array.new(EVENTS) do |i|
    { name: "Bench Event #{i}", description: 'x', date: now + (i % 60).days,
      location: 'Somewhere', organizer_id: other.id, created_at: now, updated_at: now }
  end
  Event.insert_all!(rows)
  ids = Event.where(organizer: other).limit(JOINED).pluck(:id)
  EventUser.insert_all!(ids.map { |id| { user_id: user.id, event_id: id, created_at: now, updated_at: now } })
end

puts "dataset: #{Event.count} events, #{EventUser.where(user: user).count} of them joined by the benchmark user"
puts

# The implementation this repository shipped with.
def old_scope(user)
  Event.where.not(id: user.events.ids | Event.where(organizer_id: user.id).ids)
end

# Warm up so neither measurement pays for connection or plan setup.
2.times { old_scope(user).limit(50).to_a; Event.not_joined_by_user(user).limit(50).to_a }

n = 10
old_t = Benchmark.realtime { n.times { old_scope(user).limit(50).to_a } }
new_t = Benchmark.realtime { n.times { Event.not_joined_by_user(user).limit(50).to_a } }

count = lambda do |&blk|
  q = 0
  s = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
    q += 1 unless payload[:name].in?(%w[SCHEMA TRANSACTION])
  end
  blk.call
  ActiveSupport::Notifications.unsubscribe(s)
  q
end

old_q = count.call { old_scope(user).limit(50).to_a }
new_q = count.call { Event.not_joined_by_user(user).limit(50).to_a }

puts format('%-46s %10s %10s', '', 'ms/call', 'queries')
puts format('%-46s %10.1f %10d', 'before: where.not(id: joined_ids | organised_ids)', old_t / n * 1000, old_q)
puts format('%-46s %10.1f %10d', 'after:  correlated NOT EXISTS', new_t / n * 1000, new_q)
puts
puts format('speedup: %.1fx', old_t / new_t)
puts
puts 'EXPLAIN ANALYZE of the new scope:'
puts Event.connection.select_all(
  "EXPLAIN ANALYZE #{Event.not_joined_by_user(user).limit(50).to_sql}"
).rows.flatten.first(8)
