module EchoUploads
  # This comment is current as of Rails 4.2.5.
  # 
  # This module writes temporary EchoUploads::Files on failed attempts to save the main
  # ActiveRecord model. Because ActiveRecord wraps save attempts in transactions, we can't
  # use after_save callbacks. If we tried, the EchoUploads::Files would be lost upon
  # rollback. Instead, we have to wrap #save, #create, and #update methods so that the
  # EchoUploads::Files are saved outside the transactions.
  #
  # Here is the ancestor chain for ActiveRecord::Base, including this module,
  # highest-priority first:
  # 
  # EchoUploads::TmpFileWriting -> ActiveRecord::Transactions -> ActiveRecord::Persistence
  # 
  # Here is the control flow for each of the main persistence methods. (T) denotes that
  # the method wraps all subsequent calls in a transaction.
  #
  # #save
  #   EchoUploads::TmpFileWriting#save -> ActiveRecord::Transactions#save (T) ->
  #   ActiveRecord::Persistence#save
  # 
  # #create
  #   ActiveRecord::Persistence#create -> EchoUploads::TmpFileWriting#save ->
  #   ActiveRecord::Transactions#save (T) -> ActiveRecord::Persistence#save
  #
  # #update
  #   EchoUploads::TmpFileWriting#update -> ActiveRecord::Persistence#update (T) -> 
  #   EchoUploads::TmpFileWriting#save -> ActiveRecord::Transactions#save (T) ->
  #   ActiveRecord::Persistence#save
  # 
  # Per the above, #save and #create are easy enough: We just wrap #save. But #update is
  # problematic because it starts its own transaction and then delegates to #save. Because
  # of that outer transaction, we can't rely on the #save wrapper. Instead, we have to
  # wrap #update. To prevent writing the temp file twice (once in #update and again in
  # #save), #update sets @echo_uploads_persistence_wrapped. This tells the #save
  # wrapper not to write the temp file.
  
  module TmpFileWriting
    extend ActiveSupport::Concern
    
    included do
      extend ClassMethods
      class_attribute :echo_uploads_save_wrapper
      self.echo_uploads_save_wrapper = []
    end
    
    # On a failed attempt to save (typically due to validation errors), save the file
    # and metadata. Metadata record will be given the temporary flag.
    def echo_uploads_maybe_write_tmp_file(attr, options)
      if (file = send(attr)).present? and errors[attr].empty?
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
    
    def echo_uploads_persistence_wrapper
      success = yield
      unless success
        self.class.echo_uploads_save_wrapper.each do |attr, options|
          echo_uploads_maybe_write_tmp_file(attr, options)
        end
        if self.class.included_modules.include? ::EchoUploads::Callbacks
          run_callbacks :failed_save
        end
      end
      success
    end
    
      
    def save(*)
      if @echo_uploads_persistence_wrapped
        super
      else
        echo_uploads_persistence_wrapper { super }
      end
    end
    
    
    def update(*)
      echo_uploads_persistence_wrapper do
        begin
          @echo_uploads_persistence_wrapped = true
          super
        ensure
          @echo_uploads_persistence_wrapped = nil
        end
      end
    end
    
    alias_method :update_attributes, :update
    
    module ClassMethods
      def echo_uploads_configure_tmp_file_writing(attr, options)
        if options[:write_tmp_file] == :after_rollback
          # Because ActiveRecord rolls back the transaction on validation failure, we
          # can't just use a convenient after_validation callback. Nor can we use an
          # after_rollback hook, because that causes all kinds of bizarre side-effects,
          # especially in the test environment.
          self.echo_uploads_save_wrapper += [[attr, options]]
        elsif options[:write_tmp_file] == :after_validation
          after_validation do
            echo_uploads_maybe_write_tmp_file(attr, options) { errors.empty? }
          end
        end
      end
    end
  end
end