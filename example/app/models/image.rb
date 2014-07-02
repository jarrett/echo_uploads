class Image < ActiveRecord::Base
  include EchoUploads::Model
  
  echo_upload :file
  
  validates :name, presence: true, length: {maximum: 255}
  validates :file, upload: {presence: true, max_size: 1.5.kilobytes, extension: ['.jpg', '.png']}
end