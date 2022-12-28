# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EventSerializer do
  let(:event) { create(:event) }

  it 'serializes the Event model' do
    serialized_event = described_class.new(event).serializable_hash

    expect(serialized_event[:data][:attributes]).to have_key(:id)
    expect(serialized_event[:data][:attributes]).to have_key(:name)
    expect(serialized_event[:data][:attributes]).to have_key(:description)
    expect(serialized_event[:data][:attributes]).to have_key(:date)
    expect(serialized_event[:data][:attributes]).to have_key(:location)
    expect(serialized_event[:data][:attributes]).to have_key(:organizer_id)
    expect(serialized_event[:data][:relationships]).to have_key(:users)
  end
end
