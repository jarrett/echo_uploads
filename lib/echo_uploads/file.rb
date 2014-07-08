require 'digest/sha2'
require 'mime/types'

module EchoUploads
  class File < ActiveRecord::Base
    self.table_name = 'echo_uploads_files'
    
    belongs_to :owner, polymorphic: true
    
    before_destroy :delete_file_conditionally
    
    def compute_mime!
      type = MIME::Types.type_for(original_filename).first
      self.mime_type = type ? type.content_type : 'application/octet-stream'
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
    
    # Pass in an attribute name, an ActionDispatch::UploadedFile, and an options hash.
    def persist!(attr, file, mapped_file, options)
      # Configure and save the metadata object.
      self.key = options[:key].call file
      self.owner_attr = attr
      self.original_extension = ::File.extname(file.original_filename)
      self.original_basename = ::File.basename(file.original_filename, original_extension)
      compute_mime!
      self.storage_type = options[:storage].name
      save!
    
      # Write the file to the filestore.
      if mapped_file
        file_to_write = nil
      else
        file_to_write = file
      end
      if file_to_write.is_a?(ActionDispatch::Http::UploadedFile)
        storage.write key, file.tempfile
      else
        storage.write key, file
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