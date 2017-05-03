require 'base64'
require 'json'
require 'fileutils'
require 'securerandom'

module EchoUploads    
  module Model
    extend ActiveSupport::Concern
    
    included do
      class_attribute :echo_uploads_config
      
      include ::EchoUploads::Validation
      include ::EchoUploads::PrmFileWriting
      include ::EchoUploads::TmpFileWriting
    end
    
    def echo_uploads_data
      Base64.encode64(JSON.dump(self.class.echo_uploads_config.inject({}) do |hash, (attr, cfg)|
        metas = send("#{attr}_tmp_metadata")
        if metas
          hash[attr] = metas.map do |meta|
            {'id' => meta.id, 'key' => meta.key}
          end
        end
        hash
      end)).strip
    end
    
    # Pass in a hash that's been encoded as JSON and then Base64.
    def echo_uploads_data=(data)
      parsed = JSON.parse Base64.decode64(data)
      # parsed will look like:
      # { 'attr1' => [ {'id' => 1, 'key' => 'abc...'} ] }
      unless parsed.is_a? Hash
        raise ArgumentError, "Invalid JSON structure in: #{parsed.inspect}"
      end
      parsed.each do |attr, attr_data|
        # If the :map option was passed, there may be multiple variants of the uploaded
        # file. Even if not, attr_data is still a one-element array.
        unless attr_data.is_a? Array
          raise ArgumentError, "Invalid JSON structure in: #{parsed.inspect}"
        end
        attr_data.each do |variant_data|
          unless variant_data.is_a? Hash
            raise ArgumentError, "Invalid JSON structure in: #{parsed.inspect}"
          end
          if meta = ::EchoUploads::File.where(
            id: variant_data['id'], key: variant_data['key'], temporary: true
          ).first
            if send("#{attr}_tmp_metadata").nil?
              send "#{attr}_tmp_metadata=", []
            end
            send("#{attr}_tmp_metadata") << meta
          end
        end
      end
    end
    
    # Helper method used internally Echo Uploads.
    def echo_uploads_map_metadata(attr, options)
      meta = send("#{attr}_metadata")
      meta ? yield(meta) : nil
    end
  
    module ClassMethods      
      # Options:
      #
      # - +key+: A Proc that takes an ActionDispatch::UploadedFile and returns a key
      #   uniquely identifying the file. If this option is not specified, the key is
      #   computed as the SHA-512 hash of the file contents. A digest of the file's
      #   contents should always be at least a part of the key.
      #
      # - +expires+: Length of time temporary files will be persisted. Defaults to
      #   +1.day+.
      #
      # - +storage+: A class that persists uploaded files to disk, to the cloud, or to
      #   wherever else you want. Defaults to +Rails.configuration.echo_uploads.storage+,
      #   which in turn is +EchoUploads::FilesystemStore+ by default.
      #
      # - +map+: A Proc that accepts an ActionDispatch::Htttp::UploadedFile and an
      #   instance of +EchoUploads::Mapper+. It should transform the file data (e.g.
      #   scaling an image). It should then write the transformed data to one of more
      #   temporary files. To get the temporary file path(s), call +#write+ on the
      #   +Mapper+. See readme.md for an example. The +:map+ option can also accept a
      #   symbol naming an an instance method that works the same way as the previously
      #   described Proc.
      #
      # - +multiple+: You use the +:map+ option to write multiple versions of the file.
      #   E.g. multiple thumbnail sizes. If you do so, you must pass +multiple: true+.
      #   This will make the association with +EchoUploads::File+ a +has_many+ instead of
      #   a +has_one+. The first file you write in the map function becomes the default.
      #   E.g.: Your model is called +Widget+, and the upload file attribute is called
      #   +photo+. You pass +:map+ with a method that writes three files. If you call
      #   +Widget#photo_path+, it will return the path to the first of the three files.
      #
      # - +write_tmp_file+: Normally, on a failed attempt to save the record, Echo Uploads
      #   writes a temp file. That way, the user can fix the validation errors without
      #   re-uploading the file. This option determines when the temp file is written. The
      #   default is +:after_rollback+, meaning the temp file is written on a failed
      #   attempt to save the record. Set to +false+ to turn off temp file saving. You can
      #   then save temp files manually by calling Set to +:after_validation+ and the temp
      #   file will be written on validation failure. (Warning: Although ActiveRecord
      #   implicitly validates before saving, it does so during a transaction. So setting
      #   this option to +:after_validation+ will prevent temp files being written during
      #   calls to +#save+ and similar methods.)
      def echo_upload(attr, options = {})
        options = {
          expires: 1.day,
          storage: Rails.configuration.echo_uploads.storage,
          key: ::EchoUploads::File.default_key_proc,
          write_tmp_file: :after_rollback
        }.merge(options)
        
        # Init the config object. We can't use [] syntax to set the hash key because
        # class_attribute expects you to call the setter method every time the
        # attribute value changes. (Merely calling [] would just mutate the referenced
        # object, and wouldn't invoke the setter.)
        self.echo_uploads_config ||= {}
        self.echo_uploads_config = echo_uploads_config.merge attr => {}
        
        # Define reader method for the file attribute.
        if Rails::VERSION::MAJOR >= 5
          attribute attr
        else
          attr_reader attr
        end
                
        # Define the accessor methods for the mapped version(s) of the file. Returns
        # an array.
        define_method("mapped_#{attr}") do
          unless instance_variable_get("@mapped_#{attr}")
            file = send attr
            mapper = ::EchoUploads::Mapper.new file
            if options[:map].is_a? Proc
              options[:map].call file, mapper
            else
              send(options[:map], file, mapper)
            end
            # Write an array of ActionDispatch::Http::UploadedFile objects to the instance
            # variable.
            instance_variable_set("@mapped_#{attr}", mapper.outputs)
          end
          instance_variable_get("@mapped_#{attr}")
        end
        
        # Define the original filename method.
        define_method("#{attr}_original_filename") do
          echo_uploads_map_metadata(attr, options, &:original_filename)
        end
        
        # Define the path method. This method will raise if the given storage
        # class doesn't support the #path method.
        define_method("#{attr}_path") do
          echo_uploads_map_metadata(attr, options) do |meta|
            meta.path
          end
        end
        
        # Define the MIME type method.
        define_method("#{attr}_mime") do
          echo_uploads_map_metadata(attr, options, &:mime_type)
        end
        alias_method "#{attr}_mime_type", "#{attr}_mime"
        
        # Define the key method
        define_method("#{attr}_key") do
          echo_uploads_map_metadata(attr, options, &:key)
        end
        
        # Define the storage method.
        define_method("#{attr}_storage") do
          echo_uploads_map_metadata(attr, options, &:storage)
        end
        
        # Define the url method.
        define_method("#{attr}_url") do |options = {}|
          echo_uploads_map_metadata(attr, options) do |meta|
            if meta.storage.respond_to?(:url)
              meta.storage.url meta.key, options
            else
              raise(
                NoMethodError,
                "The Echo Uploads file store you've selected, " +
                "#{meta.storage.class.to_s}, does not support the #url method."
              )
            end
          end
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
        # a temporary metadata record. (Typically because validation errors caused
        # the form to be redisplayed.)
        define_method("has_tmp_#{attr}?") do
          send("#{attr}_tmp_metadata").present?
        end
        
        # Define the read_x method. Delegates to the #read method of the store (e.g.
        # FilesystemStore).
        define_method("read_#{attr}") do
          echo_uploads_map_metadata(attr, options, &:read)
        end
        
        define_method("write_#{attr}") do |&block|
          echo_uploads_write_prm_file(attr, options, &block)
        end
        
        define_method("#{attr}_size") do
          echo_uploads_map_metadata(attr, options, &:size)
        end
        
        define_method("maybe_write_tmp_#{attr}") do
          echo_uploads_maybe_write_tmp_file(attr, options)
        end
        
        # Define the association with the metadata model.
        if options[:multiple]
          has_many("#{attr}_metadatas".to_sym,
            ->() { where(owner_attr: attr) },
            as: :owner, dependent: :destroy, class_name: '::EchoUploads::File'
          )
          
          alias_method attr.to_s.pluralize, "#{attr}_metadatas"
          
          define_method("#{attr}_metadata") do
            send("#{attr}_metadatas").first
          end
          
          define_method("#{attr}_metadata=") do |val|
            send("#{attr}_metadatas") << val
          end
        else
          has_one("#{attr}_metadata".to_sym,
            ->() { where(owner_attr: attr) },
            as: :owner, dependent: :destroy, class_name: '::EchoUploads::File'
          )
        end
        
        # Define the temp attribute for the metadata model.
        attr_accessor "#{attr}_tmp_metadata"
        
        echo_uploads_configure_tmp_file_writing attr, options
        
        echo_uploads_configure_prm_file_writing attr, options
      end
    end
  end
end