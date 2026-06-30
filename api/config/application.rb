require_relative 'boot'

require 'rails'
require 'active_model/railtie'
require 'active_record/railtie'
require 'action_controller/railtie'

Bundler.require(*Rails.groups)

module PrescientApi
  class Application < Rails::Application
    config.load_defaults 7.1
    config.api_only = true
    config.time_zone = 'UTC'
  end
end
