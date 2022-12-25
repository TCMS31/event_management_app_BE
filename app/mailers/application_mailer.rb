# frozen_string_literal: true

# Base mailer. Nothing sends mail yet; Devise's :recoverable module would.
class ApplicationMailer < ActionMailer::Base
  default from: 'from@example.com'
  layout 'mailer'
end
