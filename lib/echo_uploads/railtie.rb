require 'ostruct'

module EchoUploads
  class Railtie < Rails::Railtie
    config.echo_uploads = OpenStruct.new(
      storage: 'EchoUploads::FilesystemStore',
      s3: OpenStruct.new(bucket: nil, folder: nil)
    )
  end
end