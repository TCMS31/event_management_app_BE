# frozen_string_literal: true

# Base controller. `ActionController::API` means no cookies, no flash and no
# CSRF token -- authentication travels entirely in the Authorization header.
class ApplicationController < ActionController::API
  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: %i[name])
    devise_parameter_sanitizer.permit(:account_update, keys: %i[name])
  end
end
