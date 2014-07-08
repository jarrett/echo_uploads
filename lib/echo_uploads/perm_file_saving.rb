module EchoUploads
  module PermFileSaving
    def self.included(base)
      base.class_eval { extend ClassMethods }
    end
    
    module ClassMethods
      def configure_perm_file_saving(attr, options)
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
            meta.persist! attr, file, send("mapped_#{attr}"), options
          elsif meta = send("#{attr}_tmp_metadata") and meta.temporary
            # A file has not been uploaded during this request cycle. However, the
            # submitted form "remembered" a temporary metadata record that was previously
            # saved. We mark it as permanent and set its owner.
            # 
            # But first, we must delete any existing metadata record. (It's possible we
            # were trying to replace an old version of the file, and there were validation
            # errors on the first attempt.)
            if old = model.send("#{attr}_metadata")
              old.destroy
            end
            
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