module EchoUploads
  class FilesystemStore < ::EchoUploads::AbstractStore
    def delete(key)
      _path = path(key)
      ::File.delete(_path) if ::File.exists?(_path)
    end
    
    def exists?(key)
      ::File.exists? path(key)
    end
    
    def open(key)
      ::File.open(path(key), 'rb', &block)
    end
    
    def path(key)
      ::File.join folder, key
    end
    
    def read(key)
      File.read path(key)
    end
    
    def write(key, file)
      _path = path key
      unless ::File.exists?(_path)
        unless ::File.exists?(folder)
          begin
            FileUtils.mkdir_p folder
          rescue Errno::EACCES
            raise "Permission denied trying to create #{folder}"
          end
        end
        FileUtils.cp file.path, _path
      end
    end
    
    private
    
    # Can be customized in your per-environment config like this:
    #   config.echo_uploads.folder = File.join(Rails.root, 'my_uploads_folder', 'development')
    def folder
      if Rails.configuration.respond_to?(:echo_uploads) and Rails.configuration.echo_uploads.folder
        Rails.configuration.echo_uploads.folder
      else
        ::File.join Rails.root, 'echo_uploads', Rails.env
      end
    end
  end
end