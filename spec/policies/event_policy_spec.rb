# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EventPolicy do
  subject(:policy) { described_class.new(actor, event) }

  let(:organizer) { build_stubbed(:user, id: 1) }
  let(:other_user) { build_stubbed(:user, id: 2) }
  let(:event) { build_stubbed(:event, organizer: organizer, organizer_id: organizer.id) }

  context 'when the actor is the organizer' do
    let(:actor) { organizer }

    it { is_expected.to be_show }
    it { is_expected.to be_create }
    it { is_expected.to be_update }
    it { is_expected.to be_destroy }
    it { is_expected.not_to be_join }
  end

  context 'when the actor is a different signed-in user' do
    let(:actor) { other_user }

    it { is_expected.to be_show }
    it { is_expected.to be_create }
    it { is_expected.not_to be_update }
    it { is_expected.not_to be_destroy }
    it { is_expected.to be_join }
  end

  context 'when there is no actor' do
    let(:actor) { nil }

    it { is_expected.not_to be_show }
    it { is_expected.not_to be_create }
    it { is_expected.not_to be_update }
    it { is_expected.not_to be_destroy }
    it { is_expected.not_to be_join }
  end
end
