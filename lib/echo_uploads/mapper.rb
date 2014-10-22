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
    
    def write(ext)
      folder = ::File.join Rails.root, 'tmp/echo_uploads'
      FileUtils.mkdir_p folder
      path = ::File.join(folder, SecureRandom.hex(15) + ext)
      yield path
      unless ::File.exists? path
        raise "Called echo_upload with the :map option, but failed to write a file to #{path}"
      end
      file = ::File.open path, 'rb'
      mapped_file = ::EchoUploads::MappedFile.new(
        tempfile: file, filename: @uploaded_file.original_filename
      )
      mapped_file.mapped_filename = ::File.basename path
      outputs << mapped_file
    end
  end
end