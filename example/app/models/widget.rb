class Widget < ActiveRecord::Base
  include EchoUploads::Model
  
  echo_upload :manual
  echo_upload :thumbnail
  
  validates :name, presence: true, length: {maximum: 255}
  validates :thumbnail, upload: {presence: true, max_size: 1.5.kilobytes, extension: ['.jpg', '.png']}
end