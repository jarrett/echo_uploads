require 'ostruct'

if defined?(Rails) and !Rails.configuration.respond_to?(:echo_uploads)
  Rails.configuration.echo_uploads = OpenStruct.new
end