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
      # The map callback might not write a file. That could happen if, for example, the
      # input file is an invalid image. The best thing to do here is to fail silently.
      # The application author should write code to handle the failure case, e.g. by
      # appending to the ActiveRecord errors hash.
      if ::File.exists? path
        file = ::File.open path, 'rb'
        mapped_file = ::EchoUploads::MappedFile.new(
          tempfile: file, filename: @uploaded_file.original_filename
        )
        mapped_file.mapped_filename = ::File.basename path
        outputs << mapped_file
      end
    end
  end
end