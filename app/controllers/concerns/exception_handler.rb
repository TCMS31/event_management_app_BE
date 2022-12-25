# frozen_string_literal: true

# Translates exceptions into the API's two error envelopes:
#   { "errors": ["..."] }                    -- a message the client can show
#   { "attributes_errors": { "name": [...] } } -- per-field validation failures
#
# Having one place that does this is why the controllers can call `save!` and
# `find` and stay three lines long.
module ExceptionHandler
  extend ActiveSupport::Concern

  included do
    rescue_from StandardError, with: :handle_standard_error
    rescue_from ActionController::ParameterMissing, with: :render_parameter_missing
    rescue_from ActiveRecord::RecordNotFound, with: :render_record_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid
  end

  private

  def render_errors(error_messages, status)
    error_messages = Array(error_messages)

    render json: { errors: error_messages }, status: status
  end

  def render_attributes_errors(error_messages)
    render json: { attributes_errors: error_messages }, status: :unprocessable_entity
  end

  def render_parameter_missing(exception)
    render_errors(I18n.t('errors.missing_param', param: exception.param.to_s), :bad_request)
  end

  def render_record_not_found(exception)
    render_errors(I18n.t('errors.record_not_found', model: exception.model), :not_found)
  end

  def render_record_invalid(exception)
    errors = exception.record.errors.messages

    render_attributes_errors(errors)
  end

  def handle_standard_error(exception)
    raise exception if Rails.env.test?

    logger.error(exception)
    exception.backtrace.each { |line| logger.error(line) } if Rails.env.development?

    render_errors(I18n.t('errors.server'), :internal_server_error)
  end
end
