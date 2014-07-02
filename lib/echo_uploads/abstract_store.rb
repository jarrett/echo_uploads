module EchoUploads
  class AbstractStore
    def path(key)
      raise "This type of filestore doesn't support the #path method."
    end
  end
end