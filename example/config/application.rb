require File.expand_path('../boot', __FILE__)

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(:default, Rails.env)

module Example
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de
    
    config.i18n.enforce_available_locales = true
    
    # Don't do this in a real app. This is just a convenience for developing the Echo
    # Uploads gem. Instead, put `gem 'echo_uploads'` in your Gemfile.
    config.autoload_paths += [File.join(Rails.root, '../lib')]
    require File.join(Rails.root, '../lib/echo_uploads/railtie')
    
    config.echo_uploads.s3.bucket = 'example'
    
    # Configure the aws-sdk gem to connect to the fakes3 process.
    Aws.config.update(
      access_key_id: 'abc',
      secret_access_key: '123',
      endpoint: 'http://localhost:4000',
      force_path_style: true,
      region: 'IGNORED'
    )
  end
end
