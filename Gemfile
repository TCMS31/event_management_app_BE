# frozen_string_literal: true

source 'https://rubygems.org'

ruby '3.2.2'

gem 'rails', '~> 7.1.2'

gem 'pg', '~> 1.1'
gem 'puma', '>= 5.0'

gem 'bootsnap', require: false

# Pinned deliberately. Adding RuboCop resolves json to 3.x, and on Rails 7.1
# that makes ActionDispatch fail to parse any request with a JSON body:
# signup, login, create and update all 500 with ParseError while the app still
# boots and GET endpoints still answer. Measured, not assumed --
# docs/captured/json-3-regression.txt is the transcript. Rails 7.1 is tested
# against the 2.x line, so the bundle stays there until Rails itself moves.
gem 'json', '~> 2.7'
gem 'rack-cors'
gem 'tzinfo-data', platforms: %i[windows jruby]

# Authentication: Devise issues the session, devise-jwt turns it into a bearer
# token, jsonapi-serializer renders the responses.
gem 'devise'
gem 'devise-jwt'
gem 'jsonapi-serializer'

group :development, :test do
  gem 'debug', platforms: %i[mri windows]
  gem 'factory_bot_rails'
  gem 'faker'
  gem 'rspec-rails', '~> 6.1'
end

group :development do
  gem 'rubocop', require: false
  gem 'rubocop-factory_bot', require: false
  gem 'rubocop-rails', require: false
  gem 'rubocop-rspec', require: false
  gem 'rubocop-rspec_rails', require: false
end

group :test do
  gem 'jsonapi-rspec'
  gem 'rails-controller-testing'
  gem 'shoulda-matchers'
end
