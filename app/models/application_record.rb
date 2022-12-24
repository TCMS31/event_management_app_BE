# frozen_string_literal: true

# Abstract base class for every model in this application.
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
end
