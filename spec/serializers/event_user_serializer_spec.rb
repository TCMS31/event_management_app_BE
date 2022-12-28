# frozen_string_literal: true

# spec/serializers/event_user_serializer_spec.rb

require 'rails_helper'

RSpec.describe EventUserSerializer do
  let(:event_user) { create(:event_user) }

  it 'serializes the EventUser model' do
    serialized_event_user = described_class.new(event_user).serializable_hash

    expect(serialized_event_user[:data][:attributes]).to have_key(:id)
    expect(serialized_event_user[:data][:attributes]).to have_key(:user_id)
    expect(serialized_event_user[:data][:attributes]).to have_key(:event_id)
    expect(serialized_event_user[:data][:relationships]).to have_key(:user)
    expect(serialized_event_user[:data][:relationships]).to have_key(:event)
  end
end
