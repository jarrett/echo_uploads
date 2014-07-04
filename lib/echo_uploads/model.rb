require 'base64'
require 'json'
require 'digest/sha2'
require 'mime/types'
require 'fileutils'

module EchoUploads    
  module Model
    def self.included(base)
      base.class_eval do
        class_attribute :echo_uploads_config
        
        include ::EchoUploads::Validation
        include ::EchoUploads::PermFileSaving
        include ::EchoUploads::TempFileSaving
        
        extend ClassMethods
      end
    end
    
    def echo_uploads_data
      Base64.encode64(JSON.dump(self.class.echo_uploads_config.inject({}) do |hash, (attr, cfg)|
        meta = send("#{attr}_tmp_metadata")
        if meta
          hash[attr] = {'id' => meta.id, 'key' => meta.key}
        end
        hash
      end)).strip
    end
    
    # Pass in a hash that's been encoded as JSON and then Base64.
    def echo_uploads_data=(data)
      parsed = JSON.parse Base64.decode64(data)
      parsed.each do |attr, attr_data|
        # Must verify that the metadata record is temporary. If not, an attacker could
        # pass the ID of a permanent record and change its owner.
        meta = ::EchoUploads::File.where(key: attr_data['key'], temporary: true).find(attr_data['id'])
        send("#{attr}_tmp_metadata=", meta)
      end
    end
    
    # Helper method used internally Echo Uploads.
    def map_metadata(attr)
      meta = send("#{attr}_metadata")
      meta ? yield(meta) : nil
    end
  
    module ClassMethods      
      # Options:
      # - +key+: A Proc that takes an ActionDispatch::UploadedFile and returns a key
      #   uniquely identifying the file. If this option is not specified, the key is
      #   computed as the SHA-512 hash of the file contents. A digest of the file's
      #   contents should always be at least a part of the key.
      # - +expires+: Length of time temporary files will be persisted. Defaults to
      #   +1.day+.
      # - +storage+: A class that persists uploaded files to disk, to the cloud, or to
      #   wherever else you want. Defaults to +EchoUploads::FilesystemStore+.
      def echo_upload(attr, options = {})
        options = {
          expires: 1.day,
          storage: ::EchoUploads::FilesystemStore,
          key: ::EchoUploads::File.default_key_proc
        }.merge(options)
        
        # Init the config object.
        self.echo_uploads_config ||= {}
        self.echo_uploads_config[attr.to_sym] = {}
        
        # Define reader and writer methods for the file attribute.
        attr_accessor attr
        
        # Define the path method. This method will raise if the given storage
        # class doesn't support the #path method.
        define_method("#{attr}_path") do
          map_metadata(attr) do |meta|
            meta.storage.path meta.key
          end
        end
        
        # Define the MIME type method.
        define_method("#{attr}_mime") do
          map_metadata(attr, &:mime_type)
        end
        
        # Define the original filename method.
        define_method("#{attr}_original_filename") do
          map_metadata(attr, &:original_filename)
        end
        
        # Define the key method
        define_method("#{attr}_key") do
          map_metadata(attr, &:key)
        end
        
        # Define the has_x? method. Returns true if a permanent or temporary file has been
        # persisted, or if a file (which may not be valid) has been uploaded this request
        # cycle.
        define_method("has_#{attr}?") do
          # Does this record have a permanent file?
          send("has_prm_#{attr}?") or
          
          # Did the submitted form "remember" a previously saved metadata record?
          send("has_tmp_#{attr}?") or
          
          # Has a new file been uploaded in this request cycle?
          send(attr).present?
        end
        
        # Define the has_prm_x? method. Returns true if the permanent metadata record
        # exists and has its owner set to this object.
        define_method("has_prm_#{attr}?") do
          send("#{attr}_metadata").present? and send("#{attr}_metadata").persisted?
        end
        
        # Define the has_tmp_x? method. Returns true if the record "remembers"
        # a a temporary metadata record. (Typically because validation errors caused
        # the form to be redisplayed.)
        define_method("has_tmp_#{attr}?") do
          send("#{attr}_tmp_metadata").present?
        end
        
        # Define the association with the metadata model.
        has_one "#{attr}_metadata".to_sym, as: :owner, dependent: :destroy, class_name: '::EchoUploads::File'
        
        # Define the temp attribute for the metadata model.
        attr_accessor "#{attr}_tmp_metadata"
        
        configure_temp_file_saving attr, options
        
        configure_perm_file_saving attr, options
      end
    end
  end
end