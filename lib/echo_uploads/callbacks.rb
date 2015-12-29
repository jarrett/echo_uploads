module EchoUploads
  module Callbacks
    extend ActiveSupport::Concern
    
    included do
      unless included_modules.include? ::EchoUploads::Model
        include ::EchoUploads::Model
      end
      
      define_model_callbacks :failed_save, only: [:after]
    end
  end
end