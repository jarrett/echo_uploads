module EchoUploads
  # Used by `EchoUploads::PrmFileWriting#echo_uploads_write_prm_file`.
  class WritableFile
    def close
      # Using ActionDispatch::Http::UploadedFile is ugly. We use it because
      # EchoUploads::File#persist! expects that. In version 1 of this gem, we should
      # refactor. Everything should be more modular in general.
      uploaded_file = ActionDispatch::Http::UploadedFile.new(
        tempfile: @tempfile,
        filename: @metadata.original_filename
      )
      ActiveRecord::Base.transaction do
        # Duping the EchoUploads::File and destroy the prior one. This ensure that the
        # old data is cleaned out if necessary.
        new_metadata = @metadata.dup
        @metadata.destroy
        new_metadata.file = uploaded_file
        new_metadata.persist! new_metadata.owner_attr, @options
        @tempfile.close!
      end
    end
    
    # Takes an EchoUploads::File.
    def initialize(metadata, options)
      tmp_name = SecureRandom.hex 10
      @tempfile = Tempfile.new 'echo_uploads', Rails.root.join('tmp')
      @metadata = metadata
      @options = options
    end
    
    def method_missing(meth, *args)
      if @tempfile.respond_to? meth
        @tempfile.send meth, *args
      else
        super meth, *args
      end
    end
  end
end