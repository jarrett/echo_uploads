require 'fileutils'

class Widget < ActiveRecord::Base
  include EchoUploads::Model
  
  echo_upload :manual
  echo_upload :thumbnail
  echo_upload :photo, map: :resize_photo
  
  validates :name, presence: true, length: {maximum: 255}
  validates :thumbnail, upload: {presence: true, max_size: 1.5.kilobytes, extension: ['.jpg', '.png']}
  
  private
  
  def resize_photo(in_file, out_file_path)
    ImageScience.with_image(in_file.path) do |in_image|
      in_image.cropped_thumbnail(200) do |out_image|
        # ImageScience won't let you specify an image format as a param of the #save
        # method. It guesses based on the file extension. So we have to do a little dance.
        out_image.save(out_file_path + '.png')
        FileUtils.mv(out_file_path + '.png', out_file_path)
      end
    end
  end
end