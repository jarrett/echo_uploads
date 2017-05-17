require 'fileutils'

class Widget < ActiveRecord::Base
  include EchoUploads::Model
  
  echo_upload :manual
  echo_upload :warranty, map: :reverse_warranty
  echo_upload :thumbnail
  echo_upload :photo, map: :resize_photo, multiple: true
  
  validates :name, presence: true, length: {maximum: 255}
  validates :thumbnail, upload: {presence: true, max_size: 1.5.kilobytes, extension: ['.jpg', '.png']}
  
  private
  
  def resize_photo(in_file, mapper)
    in_image = ChunkyPNG::Image.from_file(in_file.path)
    
    [200, 300].each do |size|
      mapper.write('.png') do |out_file_path|
        in_image.resample_nearest_neighbor(size, size).save(out_file_path)
      end
    end
  end
  
  def reverse_warranty(in_file, mapper)
    mapper.write('.txt') do |out_file_path|
      File.open(out_file_path, 'w') do |f|
        f << in_file.read.reverse
      end
    end
  end
end