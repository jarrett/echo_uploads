module EchoUploads
  class MappedFile < ActionDispatch::Http::UploadedFile
    attr_accessor :mapped_filename
  end
end