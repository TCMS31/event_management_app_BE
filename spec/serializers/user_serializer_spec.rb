# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserSerializer do
  let(:user) { create(:user) }

  it 'serializes the User model' do
    serialized_user = described_class.new(user).serializable_hash

    expect(serialized_user[:data][:attributes]).to have_key(:id)
    expect(serialized_user[:data][:attributes]).to have_key(:email)
    expect(serialized_user[:data][:attributes]).to have_key(:name)
  end
end
