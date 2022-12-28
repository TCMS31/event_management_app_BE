# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Events', type: :request do
  let(:user) { create(:user) }

  describe 'GET /api/v1/events' do
    it 'returns the events organised by the authenticated user' do
      event = create(:event, organizer: user)

      sign_in user
      get '/api/v1/events'

      expect(response).to have_http_status(:ok)
      expect(json_body.pluck('id')).to contain_exactly(event.id)
    end

    it 'does not return events organised by anybody else' do
      someone_elses = create(:event)

      sign_in user
      get '/api/v1/events'

      expect(json_body.pluck('id')).not_to include(someone_elses.id)
    end

    # Regression: this used to answer `204 No Content` with a JSON body, which
    # RFC 9110 forbids and Rack strips, so the client received an empty string
    # where it expected an array.
    it 'returns 200 and an empty array when there is nothing to list' do
      sign_in user
      get '/api/v1/events'

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('application/json')
      expect(json_body).to eq([])
    end

    it 'returns unauthorized for an unauthenticated user' do
      get '/api/v1/events'

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /api/v1/events' do
    it 'creates an event owned by the authenticated user' do
      sign_in user
      post '/api/v1/events', params: { event: attributes_for(:event) }

      expect(response).to have_http_status(:created)
      expect(Event.count).to eq(1)
      expect(Event.last.organizer).to eq(user)
      expect(json_body).to include('id', 'name', 'description', 'date', 'location', 'organizer_id')
    end

    it 'ignores an organizer_id supplied by the client' do
      victim = create(:user)

      sign_in user
      post '/api/v1/events', params: { event: attributes_for(:event).merge(organizer_id: victim.id) }

      expect(response).to have_http_status(:created)
      expect(Event.last.organizer).to eq(user)
    end

    it 'returns unprocessable_entity for invalid event data' do
      sign_in user
      post '/api/v1/events', params: { event: { name: '' } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body['attributes_errors']).to include('name')
    end

    it 'returns unauthorized for an unauthenticated user' do
      post '/api/v1/events', params: { event: attributes_for(:event) }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /api/v1/events/:id' do
    it 'returns the event' do
      event = create(:event, organizer: user)

      sign_in user
      get "/api/v1/events/#{event.id}"

      expect(response).to have_http_status(:ok)
      expect(json_body['name']).to eq(event.name)
    end

    # The React client links from the "join an event" list straight to the
    # detail page of an event the reader does not own, so reads stay open.
    it 'lets a signed-in user read an event organised by somebody else' do
      event = create(:event)

      sign_in user
      get "/api/v1/events/#{event.id}"

      expect(response).to have_http_status(:ok)
    end

    # Regression: a missing record used to return `200 OK` whose body was the
    # raw exception message, leaking internals and confusing every client.
    it 'returns 404 with the standard error envelope for a missing event' do
      sign_in user
      get '/api/v1/events/999999'

      expect(response).to have_http_status(:not_found)
      expect(json_body).to eq('errors' => ['Event not found'])
    end

    it 'returns unauthorized for an unauthenticated user' do
      event = create(:event)

      get "/api/v1/events/#{event.id}"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'PUT /api/v1/events/:id' do
    it 'updates an event the user organises' do
      event = create(:event, organizer: user)

      sign_in user
      put "/api/v1/events/#{event.id}", params: { event: { name: 'Updated Name' } }

      expect(response).to have_http_status(:ok)
      expect(event.reload.name).to eq('Updated Name')
    end

    it 'returns unprocessable_entity if the event name is too long' do
      event = create(:event, organizer: user)

      sign_in user
      put "/api/v1/events/#{event.id}",
          params: { event: { name: 'The Historical Development of the Heart from Its Formation' } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body['attributes_errors']).to include('name')
    end

    it 'returns unauthorized for an unauthenticated user' do
      event = create(:event)

      put "/api/v1/events/#{event.id}", params: { event: { name: 'Updated Event Name' } }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'DELETE /api/v1/events/:id' do
    it 'deletes an event the user organises' do
      event = create(:event, organizer: user)

      sign_in user
      delete "/api/v1/events/#{event.id}"

      expect(response).to have_http_status(:no_content)
      expect(Event.count).to eq(0)
    end

    it 'returns unauthorized for an unauthenticated user' do
      event = create(:event)

      delete "/api/v1/events/#{event.id}"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /api/v1/events/add_user_to_events' do
    it 'adds the authenticated user to the event' do
      event = create(:event)

      sign_in user
      post '/api/v1/events/add_user_to_events', params: { event_id: event.id }

      expect(response).to have_http_status(:created)
      expect(EventUser.count).to eq(1)
      expect(json_body).to include('id', 'user_id', 'event_id')
    end

    it 'accepts event_id in the query string, the way the React client sends it' do
      event = create(:event)

      sign_in user
      post "/api/v1/events/add_user_to_events?event_id=#{event.id}"

      expect(response).to have_http_status(:created)
    end

    # Regression: the event id used to be looked up with `find_by` and a missing
    # record answered 422 with the bare JSON string "Event Not Found".
    it 'returns 404 when the event does not exist' do
      sign_in user
      post '/api/v1/events/add_user_to_events', params: { event_id: 999_999 }

      expect(response).to have_http_status(:not_found)
      expect(json_body).to eq('errors' => ['Event not found'])
    end

    # Regression: a missing parameter used to return `200 OK` with the raw
    # exception message as the body.
    it 'returns 400 when event_id is missing' do
      sign_in user
      post '/api/v1/events/add_user_to_events'

      expect(response).to have_http_status(:bad_request)
      expect(json_body['errors'].first).to include('event_id')
    end

    it 'returns 422 when the user has already joined' do
      event = create(:event)
      create(:event_user, user: user, event: event)

      sign_in user
      post '/api/v1/events/add_user_to_events', params: { event_id: event.id }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(EventUser.count).to eq(1)
    end

    it 'returns unauthorized for an unauthenticated user' do
      event = create(:event)

      post '/api/v1/events/add_user_to_events', params: { event_id: event.id }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /api/v1/events/get_events' do
    it 'returns upcoming events the user has neither organised nor joined' do
      joinable = create(:event)
      already_joined = create(:event)
      own = create(:event, organizer: user)
      past = create(:event, :past)
      create(:event_user, user: user, event: already_joined)

      sign_in user
      get '/api/v1/events/get_events'

      expect(response).to have_http_status(:ok)
      ids = json_body.pluck('id')
      expect(ids).to include(joinable.id)
      expect(ids).not_to include(already_joined.id, own.id, past.id)
    end

    it 'returns 200 and an empty array when there is nothing left to join' do
      event = create(:event)
      create(:event_user, user: user, event: event)

      sign_in user
      get '/api/v1/events/get_events'

      expect(response).to have_http_status(:ok)
      expect(json_body).to eq([])
    end

    it 'returns unauthorized for an unauthenticated user' do
      get '/api/v1/events/get_events'

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /api/v1/events/joined_events' do
    it 'returns the events the user has joined' do
      first = create(:event)
      second = create(:event)
      create(:event_user, user: user, event: first)
      create(:event_user, user: user, event: second)

      sign_in user
      get '/api/v1/events/joined_events'

      expect(response).to have_http_status(:ok)
      expect(json_body.pluck('id')).to contain_exactly(first.id, second.id)
    end

    it 'returns 200 and an empty array when the user has joined nothing' do
      sign_in user
      get '/api/v1/events/joined_events'

      expect(response).to have_http_status(:ok)
      expect(json_body).to eq([])
    end

    it 'returns unauthorized for an unauthenticated user' do
      get '/api/v1/events/joined_events'

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'pagination' do
    before { create_list(:event, 12, organizer: user) }

    it 'caps an unbounded list and reports the window in headers' do
      sign_in user
      get '/api/v1/events', params: { per_page: 5 }

      expect(json_body.size).to eq(5)
      expect(response.headers['X-Total-Count']).to eq('12')
      expect(response.headers['X-Page']).to eq('1')
      expect(response.headers['X-Per-Page']).to eq('5')
    end

    it 'returns the requested page' do
      sign_in user
      get '/api/v1/events', params: { per_page: 5, page: 3 }

      expect(json_body.size).to eq(2)
      expect(response.headers['X-Page']).to eq('3')
    end

    it 'refuses to return more than MAX_PER_PAGE rows however large per_page is' do
      sign_in user
      get '/api/v1/events', params: { per_page: 10_000 }

      expect(response.headers['X-Per-Page']).to eq(Paginatable::MAX_PER_PAGE.to_s)
    end

    it 'treats a nonsense page parameter as page 1' do
      sign_in user
      get '/api/v1/events', params: { page: 'banana', per_page: 5 }

      expect(response.headers['X-Page']).to eq('1')
      expect(json_body.size).to eq(5)
    end
  end
end
