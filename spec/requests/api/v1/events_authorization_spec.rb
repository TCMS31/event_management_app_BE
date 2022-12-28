# frozen_string_literal: true

require 'rails_helper'

# The authorization regression suite.
#
# Before EventPolicy existed, every mutating endpoint here was reachable by any
# authenticated user against any event. A cross-user PUT returned 200, rewrote
# the record *and* reassigned `organizer_id` to the caller (because the strong
# parameters defaulted `organizer_id` to `current_user.id` on update as well as
# create); a cross-user DELETE returned 204 and destroyed the row.
#
# docs/captured/baseline-bug-probe.txt is the transcript of that behaviour on
# the pristine checkout.
RSpec.describe 'Api::V1::Events authorization', type: :request do
  let(:owner) { create(:user) }
  let(:intruder) { create(:user) }
  let!(:event) { create(:event, organizer: owner, name: 'Owned By Owner') }

  describe 'PUT /api/v1/events/:id by a non-organizer' do
    before do
      sign_in intruder
      put "/api/v1/events/#{event.id}", params: { event: { name: 'Hijacked' } }
    end

    it 'is forbidden' do
      expect(response).to have_http_status(:forbidden)
      expect(json_body).to eq('errors' => ['You are not allowed to perform this action'])
    end

    it 'leaves the record untouched' do
      expect(event.reload.name).to eq('Owned By Owner')
    end

    it 'does not transfer ownership to the caller' do
      expect(event.reload.organizer_id).to eq(owner.id)
    end
  end

  describe 'PATCH /api/v1/events/:id by a non-organizer' do
    it 'is forbidden' do
      sign_in intruder
      patch "/api/v1/events/#{event.id}", params: { event: { location: 'Elsewhere' } }

      expect(response).to have_http_status(:forbidden)
      expect(event.reload.location).not_to eq('Elsewhere')
    end
  end

  describe 'DELETE /api/v1/events/:id by a non-organizer' do
    it 'is forbidden and destroys nothing' do
      sign_in intruder
      delete "/api/v1/events/#{event.id}"

      expect(response).to have_http_status(:forbidden)
      expect(Event.exists?(event.id)).to be(true)
    end
  end

  # NOTE: this application stores no session (`RackSessionsFix` installs a
  # disabled one so Devise's controllers work in API mode), so Warden's
  # `sign_in` applies to the *next* request only. Each request therefore gets
  # its own `sign_in`.
  describe 'a participant who is not the organizer' do
    before { create(:event_user, user: intruder, event: event) }

    it 'still may not update the event they joined' do
      sign_in intruder
      put "/api/v1/events/#{event.id}", params: { event: { name: 'Hijacked' } }

      expect(response).to have_http_status(:forbidden)
      expect(event.reload.name).to eq('Owned By Owner')
    end

    it 'still may not delete the event they joined' do
      sign_in intruder
      delete "/api/v1/events/#{event.id}"

      expect(response).to have_http_status(:forbidden)
      expect(Event.exists?(event.id)).to be(true)
    end
  end

  describe 'the organizer' do
    it 'may update their own event' do
      sign_in owner
      put "/api/v1/events/#{event.id}", params: { event: { name: 'Renamed' } }

      expect(response).to have_http_status(:ok)
      expect(event.reload.name).to eq('Renamed')
    end

    it 'may delete their own event' do
      sign_in owner
      delete "/api/v1/events/#{event.id}"

      expect(response).to have_http_status(:no_content)
      expect(Event.exists?(event.id)).to be(false)
    end
  end

  describe 'POST /api/v1/events/add_user_to_events' do
    # Regression: an organizer could join their own event, producing an
    # attendance row for an event that never appears in the joinable list.
    it 'refuses to let the organizer join their own event' do
      sign_in owner
      post '/api/v1/events/add_user_to_events', params: { event_id: event.id }

      expect(response).to have_http_status(:forbidden)
      expect(EventUser.count).to eq(0)
    end

    it 'lets anybody else join' do
      sign_in intruder
      post '/api/v1/events/add_user_to_events', params: { event_id: event.id }

      expect(response).to have_http_status(:created)
      expect(EventUser.count).to eq(1)
    end
  end

  describe 'every mutating endpoint rejects an anonymous caller' do
    it 'POST /api/v1/events is 401' do
      post '/api/v1/events', params: { event: attributes_for(:event) }

      expect(response).to have_http_status(:unauthorized)
    end

    %i[put patch].each do |verb|
      it "#{verb.upcase} /api/v1/events/:id is 401" do
        public_send(verb, "/api/v1/events/#{event.id}", params: { event: { name: 'x' } })

        expect(response).to have_http_status(:unauthorized)
        expect(event.reload.name).to eq('Owned By Owner')
      end
    end

    it 'DELETE /api/v1/events/:id is 401' do
      delete "/api/v1/events/#{event.id}"

      expect(response).to have_http_status(:unauthorized)
      expect(Event.exists?(event.id)).to be(true)
    end

    it 'POST /api/v1/events/add_user_to_events is 401' do
      post '/api/v1/events/add_user_to_events', params: { event_id: event.id }

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
