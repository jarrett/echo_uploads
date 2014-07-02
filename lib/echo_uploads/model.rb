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
        
        extend ClassMethods
      end
    end
    
    def echo_uploads_data
      Base64.encode64(JSON.dump(self.class.echo_uploads_config.inject({}) do |hash, (attr, cfg)|
        meta = send("#{attr}_tmp_metadata")
        if meta
          hash[attr] = {'id' => meta.id}
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
        meta = ::EchoUploads::File.where(temporary: true).find(attr_data['id'])
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
      #   computed as the SHA-256 hash of the file contents.
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
        
        # On a failed attempt to save (typically due to validation errors), save the file
        # and metadata. Metadata record will be given the temporary flag.
        #
        # It might be cleaner to use a callback here instead of alias_method_chain. But
        # we can't, because the callback would be executed in a transaction that would
        # be rolled back. So the metadata model would never be saved.
        define_method(:save_with_temp_file_saving) do |*args|
          success = save_without_temp_file_saving(*args)
          if (file = send(attr)).present?
            unless success
              if send("#{attr}_tmp_metadata").nil? and errors[attr].empty?
                meta = ::EchoUploads::File.new(
                  owner: nil, temporary: true, expires_at: options[:expires].from_now
                )
                meta.persist! file, options
                send("#{attr}_tmp_metadata=", meta)
              end
            end
          end
          success
        end
        alias_method_chain :save, :temp_file_saving
        
        # Save the file and the metadata after this model saves.
        after_save do |model|
          if (file = send(attr)).present?
            # A file is being uploaded during this request cycle.
            if meta = send("#{attr}_metadata")
              # A previous permanent file exists. This is a new version being uploaded.
              # Delete the old version from the disk if no other metadata record
              # references it.
              meta.delete_file_conditionally
            else
              # No previous permanent file exists. 
              meta = ::EchoUploads::File.new(owner: model, temporary: false)
              send("#{attr}_metadata=", meta)
            end
            meta.persist! file, options
          elsif meta = send("#{attr}_tmp_metadata") and meta.temporary
            # A file has not been uploaded during this request cycle. However, the
            # submitted form "remembered" a temporary metadata file that was previously
            # saved. We mark it as permanent and set its owner.
            meta.owner = model
            send("#{attr}_metadata=", meta)
            meta.temporary = false
            meta.expires_at = nil
            meta.save!
          end
        end
      end
    end
  end
end