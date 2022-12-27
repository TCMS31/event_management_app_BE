# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EventUser, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:user).class_name('User').required }
    it { is_expected.to belong_to(:event).class_name('Event').required }

    it 'resolves the conventional foreign keys' do
      expect(described_class.reflect_on_association(:user).foreign_key).to eq('user_id')
      expect(described_class.reflect_on_association(:event).foreign_key).to eq('event_id')
    end
  end

  describe 'factory' do
    it 'has a valid factory' do
      expect(create(:event_user)).to be_valid
    end
  end

  describe 'validations' do
    let!(:user) { create(:user) }
    let!(:event) { create(:event) }

    before do
      create(:event_user, user: user, event: event)
    end

    it 'allows a user to join a given event only once' do
      expect(subject).to validate_uniqueness_of(:user_id)
        .scoped_to(:event_id)
        .with_message('User can join the same event only once')
    end

    # The validation alone left a race between the SELECT and the INSERT. The
    # unique index closes it; this proves the database refuses the duplicate
    # even when the validation is bypassed.
    it 'is also enforced by a unique index' do
      expect { described_class.new(user: user, event: event).save!(validate: false) }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
