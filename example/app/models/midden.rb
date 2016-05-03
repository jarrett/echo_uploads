class Midden < ActiveRecord::Base
  include EchoUploads::Model
  
  belongs_to :squib
  
  echo_upload :thumbnail, write_tmp_file: :after_validation
  echo_upload :manual, write_tmp_file: false
  
  validates :name, presence: true, length: {maximum: 255}
  
  attr_accessor :callback_invoked
  
  after_echo_uploads_write_prm do |midden|
    midden.callback_invoked = true
  end
end