module EchoUploads
  module PrmFileWriting
    extend ActiveSupport::Concern
    
    module ClassMethods
      def echo_uploads_configure_prm_file_writing(attr, options)
        # Save the file and the metadata after this model saves.
        after_save do |model|
          @echo_uploads_prm_files_saved ||= {}
          if (file = send(attr)).present? and @echo_uploads_prm_files_saved[attr.to_sym] != file
            # A file is being uploaded during this request cycle. Further, we have not
            # already done the permanent file saving during this request cycle. (It's
            # not uncommon for a model to be saved twice in one request. If we ran this
            # code twice, we'd have duplicate effort at best and exceptions at worst.)
            
            @echo_uploads_prm_files_saved[attr.to_sym] = file
            
            if options[:multiple]
              metas = send("#{attr}_metadatas")
            else
              metas = [send("#{attr}_metadata")].compact
            end
            
            # metas is now an array of ::EchoUploads::File instances. The array may
            # be empty.
            
            if metas.any?
              # Previous permanent file(s) exist. This is a new version being uploaded.
              # Delete the old version(s).
              metas.each(&:destroy)
            end
            
            # No previous permanent files exists. The metas array is currently empty or
            # else contains deleted records. We need to rebuild that array by constructing
            # (but not yet saving) new EchoUploads::File objects.
            
            if options[:multiple]
              mapped_files = send("mapped_#{attr}") ||
                raise('echo_uploads called with :multiple, but :map option was missing')
              metas = mapped_files.map do |mapped_file|
                ::EchoUploads::File.new(
                  owner: model, temporary: false, file: mapped_file
                )
              end
              send("#{attr}_metadatas=", metas)
            elsif options[:map]
              mapped_files = send("mapped_#{attr}")
              metas = [::EchoUploads::File.new(
                owner: model, temporary: false, file: mapped_files.first
              )]
              send("#{attr}_metadata=", metas.first)
            else
              metas = [::EchoUploads::File.new(
                owner: model, temporary: false, file: send(attr)
              )]
              send("#{attr}_metadata=", metas.first)
            end
            
            # metas is still an array of the EchoUploads::File instances. If the array was
            # initially empty (meaning no previous permanent file existed), then it has
            # since been populated.
            
            metas.each do |meta|
              meta.persist! attr, options
            end
          elsif metas = send("#{attr}_tmp_metadata")
            # A file has not been uploaded during this request cycle. However, the
            # submitted form "remembered" a temporary metadata record that was previously
            # saved.
            
            # Delete any existing metadata record. (It's possible we
            # were trying to replace an old version of the file, and there were validation
            # errors on the first attempt.)
            
            if options[:multiple]
              model.send("#{attr}_metadatas").each(&:destroy)
            elsif old = model.send("#{attr}_metadata")
              old.destroy
            end
            
            # We need not call persist! here, because the file is already persisted. (Nor
            # could we call it, because persist! requires an
            # ActionDispatch::HTTP::UploadedFile.) Mark the metadata record as permanent
            # and set its owner.
            metas.each do |meta|
              meta.owner = model
              meta.temporary = false
              meta.expires_at = nil
              meta.save!
            end
            
            if options[:multiple]
              send("#{attr}_metadatas=", metas)
            else
              send("#{attr}_metadata=", metas.first)
            end
          end
        end
      end
    end
  end
end