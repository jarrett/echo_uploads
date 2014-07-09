class Snark < ActiveRecord::Base
  include EchoUploads::Model
  
  echo_upload :manual, storage: EchoUploads::S3Store
  
  validates :manual, upload: {presence: true}
end