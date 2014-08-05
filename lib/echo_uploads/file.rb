require 'digest/sha2'
require 'mime/types'

module EchoUploads
  class File < ActiveRecord::Base
    self.table_name = 'echo_uploads_files'
    
    belongs_to :owner, polymorphic: true
    
    before_destroy :delete_file_conditionally
    
    attr_accessor :file
    
    def compute_mime!(options)
      if file and file.is_a?(::EchoUploads::MappedFile)
        name = file.mapped_filename
      else
        name = original_filename
      end
      type = MIME::Types.type_for(name).first
      self.mime_type = type ? type.content_type : 'application/octet-stream'
    end
    
    def compute_key!(file, options)
      self.key = options[:key].call file
    end
    
    # Returns a proc that takes as its only argument an ActionDispatch::UploadedFile
    # and returns a key string.
    def self.default_key_proc
      ->(file) do
        digest = Digest::SHA512.new
        file.rewind
        until file.eof?
          digest.update file.read(1000)
        end
        digest.hexdigest
      end
    end
    
    # Deletes the file on disk if and only if no other instances of EchoUpload::File
    # reference it.
    def delete_file_conditionally
      unless self.class.where(key: key).where(['id != ?', id]).exists?
        storage.delete key
      end
    end
    
    def original_filename
      original_basename + original_extension
    end
    
    def path
      storage.path key
    end
    
    # Pass in an attribute name, an ActionDispatch::Http::UploadedFile, and an options hash.
    # Must set #file attribute first.
    def persist!(attr, options)
      unless(
        file.is_a?(ActionDispatch::Http::UploadedFile) or
        file.is_a?(Rack::Test::UploadedFile)
      )
        raise(
          "Expected #file to be a ActionDispatch::Http::UploadedFile "+
          "or Rack::Test::UploadedFile, but was #{file.inspect}"
        )
      end
      
      # Configure and save the metadata object.
      compute_key! file, options
      self.owner_attr = attr
      self.original_extension = ::File.extname(file.original_filename)
      self.original_basename = ::File.basename(file.original_filename, original_extension)
      compute_mime! options
      if options[:storage].is_a? String
        self.storage_type = options[:storage]
      else
        self.storage_type = options[:storage].name
      end
      save!
    
      # Write the file to the filestore. It's possible that #file is an instance of
      # EchoUploads::MappedFile, which is a subclass of
      # ActionDispatch::Http::UploadedFile.
      if file.is_a?(ActionDispatch::Http::UploadedFile)
        storage.write key, file.tempfile
      else
        storage.write key, file
      end
      
      # If we mapped the files, they were temporarily written to tmp/echo_uploads.
      # Delete them.
      if file.is_a?(::EchoUploads::MappedFile)
        ::File.delete file.path
      end
    
      # Prune any expired temporary files. (Unless automatic pruning was turned off in
      # the app config.)
      unless (
        Rails.configuration.echo_uploads.respond_to?(:prune_tmp_files_on_upload) and
        !Rails.configuration.echo_uploads.prune_tmp_files_on_upload
      )
        self.class.prune_temporary!
      end
    end
    
    def self.prune_temporary!
      where(temporary: true).where(['expires_at < ?', Time.now]).each do |file_meta|
        file_meta.destroy
      end
    end
    
    def storage
      class_from_string(storage_type).new
    end
    
    private
    
    def class_from_string(name)
      name.split('::').inject(Object) do |mod, klass|
        mod.const_get klass
      end
    end
  end
end