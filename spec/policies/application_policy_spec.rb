# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationPolicy do
  subject(:policy) { described_class.new(build_stubbed(:user), build_stubbed(:event)) }

  # Fail closed: a new policy that forgets to override a predicate denies.
  it { is_expected.not_to be_show }
  it { is_expected.not_to be_create }
  it { is_expected.not_to be_update }
  it { is_expected.not_to be_destroy }
end
