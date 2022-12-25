# frozen_string_literal: true

# Devise's controllers reach for `request.env['rack.session']` even in an
# API-only app, where the session middleware is not loaded. This supplies a
# disabled stand-in so nothing stores anything.
#
# Consequence worth knowing: there is no session, so Warden re-authenticates
# from the bearer token on every single request.
module RackSessionsFix
  extend ActiveSupport::Concern

  # A Hash that reports itself as a disabled session.
  class FakeRackSession < Hash
    def enabled?
      false
    end

    def destroy; end
  end
  included do
    before_action :set_fake_session

    private

    def set_fake_session
      request.env['rack.session'] ||= FakeRackSession.new
    end
  end
end
