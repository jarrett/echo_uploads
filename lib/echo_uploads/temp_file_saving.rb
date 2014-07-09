module EchoUploads
  module TempFileSaving
    def self.included(base)
      base.class_eval { extend ClassMethods }
    end
    
    # On a failed attempt to save (typically due to validation errors), save the file
    # and metadata. Metadata record will be given the temporary flag.
    # 
    # To deal with the various persistence methods (#save, #create,
    # #update_attributes), and the fact that ActiveRecord rolls back the transaction
    # on validation failure, we can't just use a convenient after_validation callback.
    # Instead, we have to do some trickery with .alias_method_chain.
    def maybe_save_temp_file(attr, options)
      success = yield
      
      # Because of the tangled way ActiveRecord's persistence methods delegate to each
      # other, maybe_save_temp_file sometimes gets called twice. That's unavoidable. To
      # workaround that issue, we check whether we're calling #save from within #update.
      @echo_uploads_saving ||= {}
      @echo_uploads_updating ||= {}
      unless @echo_uploads_saving[attr] and @echo_uploads_updating[attr]
        if (file = send(attr)).present? and !success and errors[attr].empty?
          # A file has been uploaded. Validation failed, but the file itself was valid.
          # Thus, we must persist a temporary file.
          # 
          # It's possible at this point that the record already has a permanent file.
          # That's fine. We'll now have a permanent and a temporary one. The temporary
          # one will replace the permanent one if and when the user resubmits with
          # valid data.
          
          # Construct an array of EchoUploads::File instances. The array might have only
          # one element.
          if options[:multiple]
            mapped_files = send("mapped_#{attr}") ||
              raise('echo_uploads called with :multiple, but :map option was missing')
            metas = mapped_files.map do |mapped_file|
              ::EchoUploads::File.new(
                owner: nil, temporary: true, expires_at: options[:expires].from_now,
                file: mapped_file
              )
            end
          else
            metas = [::EchoUploads::File.new(
              owner: nil, temporary: true, expires_at: options[:expires].from_now,
              file: send(attr)
            )]
          end
          
          # Persist each file. (There might only be one, though.)
          metas.each do |meta|
            meta.persist! attr, options
          end
          
          # Set the attr_tmp_metadata attribute so the form can remember our records.
          send("#{attr}_tmp_metadata=", metas)
        end
      end
      
      success
    end
    
    module ClassMethods
      # Wraps ActiveRecord's persistence methods. We can't use a callback for this. See
      # the comment above for an explanation of why.
      def configure_temp_file_saving(attr, options)
        # Wrap the #save method. This also suffices for #create.
        define_method("save_with_#{attr}_temp_file") do |*args|
          @echo_uploads_saving ||= {}
          @echo_uploads_saving[attr] = true
          begin
            success = maybe_save_temp_file(attr, options) do
              send "save_without_#{attr}_temp_file", *args
            end
            success
          ensure
            @echo_uploads_saving.delete attr
          end
        end
        alias_method_chain :save, "#{attr}_temp_file".to_sym
        
        # Wrap the #update and #update_attributes methods.
        define_method("update_with_#{attr}_temp_file") do |*args|
          @echo_uploads_updating ||= {}
          @echo_uploads_updating[attr] = true
          begin
            success = maybe_save_temp_file(attr, options) do
              send "update_without_#{attr}_temp_file", *args
            end
            success
          ensure
            @echo_uploads_updating.delete attr
          end
        end
        alias_method_chain :update, "#{attr}_temp_file".to_sym
        alias_method :update_attributes, "update_with_#{attr}_temp_file".to_sym
      end
    end
  end
end