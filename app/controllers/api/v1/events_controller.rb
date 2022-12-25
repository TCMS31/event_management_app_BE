# frozen_string_literal: true

module Api
  module V1
    # Events owned by, joinable by, and joined by the signed-in user.
    #
    # Responses are flat JSON objects (or arrays of them), *not* JSON:API
    # envelopes: the serializers are jsonapi-serializer classes, but only the
    # `attributes` hash is rendered because that is the shape the React client
    # consumes. See docs/api-contract.md.
    class EventsController < ApiController
      before_action :set_event, only: %i[show update destroy]

      # GET /api/v1/events — events this user organizes.
      def index
        render json: serialize_many(paginate(Event.organized_by_user(current_user).recent_first))
      end

      # GET /api/v1/events/:id
      def show
        authorize!(@event, :show)

        render json: serialize_one(@event)
      end

      # POST /api/v1/events
      def create
        event = current_user.organized_events.build(event_params)
        authorize!(event, :create)
        event.save!

        render json: serialize_one(event), status: :created
      end

      # PATCH/PUT /api/v1/events/:id
      def update
        authorize!(@event, :update)
        @event.update!(event_params)

        render json: serialize_one(@event)
      end

      # DELETE /api/v1/events/:id
      def destroy
        authorize!(@event, :destroy)
        @event.destroy!

        head :no_content
      end

      # POST /api/v1/events/add_user_to_events?event_id=:id
      #
      # Kept at its original path and parameter name because the deployed React
      # client calls exactly this.
      def add_user_to_events
        event = Event.find(params.require(:event_id))
        authorize!(event, :join)

        event_user = EventUser.create!(event: event, user: current_user)

        render json: EventUserSerializer.new(event_user).serializable_hash[:data][:attributes],
               status: :created
      end

      # GET /api/v1/events/get_events — upcoming events this user may still join.
      # rubocop:disable Naming/AccessorMethodName -- the deployed React client
      # calls /api/v1/events/get_events by that exact name; renaming it would be
      # a breaking API change for no behavioural gain.
      def get_events
        render json: serialize_many(paginate(Event.not_joined_by_user(current_user).upcoming_events))
      end
      # rubocop:enable Naming/AccessorMethodName

      # GET /api/v1/events/joined_events — events this user has joined.
      def joined_events
        render json: serialize_many(paginate(current_user.events.recent_first))
      end

      private

      def set_event
        @event = Event.find(params[:id])
      end

      def event_params
        params.require(:event).permit(:name, :description, :date, :location)
      end

      def serialize_one(event)
        EventSerializer.new(event).serializable_hash[:data][:attributes]
      end

      def serialize_many(events)
        EventSerializer.new(events).serializable_hash[:data].pluck(:attributes)
      end
    end
  end
end
