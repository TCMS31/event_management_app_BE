# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Event, type: :model do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:description) }
    it { is_expected.to validate_presence_of(:date) }
    it { is_expected.to validate_presence_of(:location) }

    # `belongs_to :organizer` is required by default in Rails 5+, so the
    # explicit `validates :organizer, presence: true` it used to carry was
    # redundant. The behaviour is still asserted, just not the declaration.
    it 'is invalid without an organizer' do
      event = build(:event, organizer: nil)

      expect(event).not_to be_valid
      expect(event.errors[:organizer]).to be_present
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:organizer).class_name('User') }

    it 'points organizer at the organizer_id column' do
      expect(described_class.reflect_on_association(:organizer).foreign_key).to eq('organizer_id')
    end

    it { is_expected.to have_many(:event_users).class_name('EventUser').dependent(:destroy) }
    it { is_expected.to have_many(:users).class_name('User').through(:event_users) }
  end

  describe 'factory' do
    it 'has a valid factory' do
      expect(create(:event)).to be_valid
    end

    it 'creates an event with users' do
      event = create(:event_with_users, users_count: 3)
      expect(event.users.count).to eq(3)
    end
  end

  describe 'scopes' do
    let(:user) { create(:user) }

    describe 'organized_by_user' do
      it 'returns events organized by the specified user' do
        event = create(:event, organizer: user)

        result = described_class.organized_by_user(user)

        expect(result).to include(event)
      end

      it 'does not return events organized by other users' do
        other_user = create(:user)
        event = create(:event, organizer: other_user)

        result = described_class.organized_by_user(user)

        expect(result).not_to include(event)
      end
    end

    describe 'not_joined_by_user' do
      it 'returns events not joined by the specified user' do
        event = create(:event)
        create(:event_user, event: event, user: user)

        result = described_class.not_joined_by_user(user).upcoming_events

        expect(result).not_to include(event)
      end

      it 'returns events not joined by any user' do
        event = create(:event)

        result = described_class.not_joined_by_user(user).upcoming_events

        expect(result).to include(event)
      end

      it 'does not return events joined by the specified user' do
        event = create(:event, organizer: user)

        result = described_class.not_joined_by_user(user).upcoming_events

        expect(result).not_to include(event)
      end

      # The scope used to load every joined and organised id into Ruby and send
      # them back inside a NOT IN list. It is now one statement.
      it 'resolves in a single SQL query however much history the user has' do
        create_list(:event, 5).each { |e| create(:event_user, event: e, user: user) }
        create_list(:event, 5, organizer: user)
        create(:event)

        queries = []
        subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
          queries << payload[:sql] unless payload[:name].in?(%w[SCHEMA TRANSACTION])
        end
        described_class.not_joined_by_user(user).to_a
        ActiveSupport::Notifications.unsubscribe(subscriber)

        expect(queries.size).to eq(1)
      end
    end

    describe '.upcoming_events' do
      let!(:past_event) { create(:event, date: 1.day.ago) }
      let!(:upcoming_event1) { create(:event, date: 1.day.from_now) }
      let!(:upcoming_event2) { create(:event, date: 3.days.from_now) }

      it 'returns only upcoming events' do
        upcoming_events = described_class.upcoming_events

        expect(upcoming_events).to include(upcoming_event1, upcoming_event2)
        expect(upcoming_events).not_to include(past_event)
      end

      it 'returns events ordered by date in ascending order' do
        upcoming_events = described_class.upcoming_events

        expect(upcoming_events).to eq([upcoming_event1, upcoming_event2])
      end
    end
  end
end
