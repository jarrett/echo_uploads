require 'base64'
require 'json'
require 'fileutils'
require 'securerandom'

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
        if meta = ::EchoUploads::File.where(id: attr_data['id'], key: attr_data['key'], temporary: true).first
          send("#{attr}_tmp_metadata=", meta)
        end
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
      # - +map+: A Proc that accepts an ActionDispatch::Htttp::UploadedFile and a path to
      #   a temporary file. It should transform the file data (e.g. scaling an image). It
      #   should then write the transformed data to the temporary file path. Can also
      #   accept a symbol naming an an instance method that works the same way as the
      #   previously described Proc.
      def echo_upload(attr, options = {})
        options = {
          expires: 1.day,
          storage: ::EchoUploads::FilesystemStore,
          key: ::EchoUploads::File.default_key_proc
        }.merge(options)
        
        # Init the config object. We can't use [] syntax to set the hash key because
        # class_attribute expects you to call the setter method every time the
        # attribute value changes. (Merely calling [] would just mutate the referenced
        # object, and wouldn't invoke the setter.)
        self.echo_uploads_config ||= {}
        self.echo_uploads_config = echo_uploads_config.merge attr => {}
        
        # Define reader method for the file attribute.
        attr_reader attr
        
        # Define the writer method for the file attribute.
        define_method("#{attr}=") do |file|
          if options[:map]
            mapped_file_path = ::File.join Rails.root, 'tmp', SecureRandom.hex(15)
            if options[:map].is_a? Proc
              options[:map].call file, mapped_file_path
            else
              send(options[:map], file, mapped_file_path)
            end
            mapped_file = ::File.open mapped_file_path, 'rb'
            send "mapped_#{attr}=", mapped_file
          end
          instance_variable_set "@#{attr}", file
        end
        
        # Define the accessor methods for the mapped version of the file.
        attr_accessor "mapped_#{attr}"
        
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
        alias_method "#{attr}_mime_type", "#{attr}_mime"
        
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
        has_one("#{attr}_metadata".to_sym,
          ->() { where(owner_attr: attr) },
          as: :owner, dependent: :destroy, class_name: '::EchoUploads::File'
        )
        
        # Define the temp attribute for the metadata model.
        attr_accessor "#{attr}_tmp_metadata"
        
        configure_temp_file_saving attr, options
        
        configure_perm_file_saving attr, options
      end
    end
  end
end