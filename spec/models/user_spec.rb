# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'attributes' do
    it { is_expected.to have_db_column(:name).of_type(:string) }
    it { is_expected.to have_db_column(:email).of_type(:string) }
    it { is_expected.to have_db_column(:id).of_type(:integer) }
    it { is_expected.to have_db_column(:encrypted_password).of_type(:string) }
    it { is_expected.to have_db_column(:reset_password_token).of_type(:string) }
    it { is_expected.to have_db_column(:reset_password_sent_at).of_type(:datetime) }
    it { is_expected.to have_db_column(:remember_created_at).of_type(:datetime) }
    it { is_expected.to have_db_column(:jti).of_type(:string) }
  end

  describe 'relations' do
    it { is_expected.to have_many(:event_users) }
    it { is_expected.to have_many(:events).through(:event_users) }

    it 'owns the events it organises' do
      expect(subject).to have_many(:organized_events)
        .class_name('Event')
        .with_foreign_key(:organizer_id)
        .dependent(:destroy)
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_length_of(:name).is_at_most(15) }
  end

  describe 'factory' do
    it 'has a valid factory' do
      expect(create(:user)).to be_valid
    end
  end

  describe '#organized_events vs #events' do
    # Regression: `organized_events` used to be a second `has_many :events`,
    # which Active Record silently replaced with the through-association, so
    # the two concepts collapsed into one.
    it 'separates events the user runs from events the user attends' do
      user = create(:user)
      mine = create(:event, organizer: user)
      theirs = create(:event)
      create(:event_user, user: user, event: theirs)

      expect(user.organized_events).to contain_exactly(mine)
      expect(user.events).to contain_exactly(theirs)
    end
  end

  describe '#destroy' do
    # Regression: because the `dependent: :destroy` declaration was overwritten,
    # deleting a user who had organised anything raised
    # ActiveRecord::InvalidForeignKey from PostgreSQL.
    it 'destroys the events the user organised' do
      user = create(:user)
      create(:event, organizer: user)

      expect { user.destroy! }.to change(Event, :count).by(-1)
    end

    it 'destroys the attendance rows the user created' do
      user = create(:user)
      create(:event_user, user: user, event: create(:event))

      expect { user.destroy! }.to change(EventUser, :count).by(-1)
    end
  end
end
