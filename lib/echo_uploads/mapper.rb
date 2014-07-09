require 'fileutils'

module EchoUploads
  class Mapper
    def initialize(file)
      unless(
        file.is_a?(ActionDispatch::Http::UploadedFile) or
        file.is_a?(Rack::Test::UploadedFile)
      )
        raise(
          "Expected file to be a ActionDispatch::Http::UploadedFile "+
          "or Rack::Test::UploadedFile, but was #{file.inspect}"
        )
      end
      
      @uploaded_file = file
      @outputs = []
    end
    
    attr_reader :outputs
    
    def write
      folder = ::File.join Rails.root, 'tmp/echo_uploads'
      FileUtils.mkdir_p folder
      path = ::File.join folder, SecureRandom.hex(15)
      yield path
      file = ::File.open path, 'rb'
      outputs << ::EchoUploads::MappedFile.new(
        tempfile: file, filename: @uploaded_file.original_filename
      )
    end
  end
end