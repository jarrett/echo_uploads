require 'ostruct'

module EchoUploads
  class Railtie < Rails::Railtie
    config.echo_uploads = OpenStruct.new
  end
end