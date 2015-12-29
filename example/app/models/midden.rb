class Midden < ActiveRecord::Base
  include EchoUploads::Model
  
  belongs_to :squib
  
  echo_upload :thumbnail, write_tmp_file: :after_validation
  echo_upload :manual, write_tmp_file: false
  
  validates :name, presence: true, length: {maximum: 255}
end