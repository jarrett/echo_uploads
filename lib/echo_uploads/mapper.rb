module EchoUploads
  class Mapper
    def initialize
      @outputs = []
    end
    
    attr_reader :outputs
    
    def write
      path = ::File.join Rails.root, 'tmp', SecureRandom.hex(15)
      yield path
      file = ::File.open path, 'rb'
      outputs << file
    end
  end
end