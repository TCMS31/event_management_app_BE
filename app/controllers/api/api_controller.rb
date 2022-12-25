# frozen_string_literal: true

module Api
  # Base class for every JSON endpoint under /api.
  #
  # Order matters: ExceptionHandler installs a catch-all `rescue_from
  # StandardError`, so the more specific handlers contributed by Authorization
  # must be registered *after* it (Rails matches handlers newest-first).
  class ApiController < ApplicationController
    include ExceptionHandler
    include Authorization
    include Paginatable

    before_action :authenticate_user!
  end
end
