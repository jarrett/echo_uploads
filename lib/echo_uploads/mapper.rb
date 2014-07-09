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
      path = ::File.join Rails.root, 'tmp', SecureRandom.hex(15)
      yield path
      file = ::File.open path, 'rb'
      outputs << ActionDispatch::Http::UploadedFile.new(
        tempfile: file, filename: @uploaded_file.original_filename
      )
    end
  end
end