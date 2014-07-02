require 'machinist/active_record'

Image.blueprint do
  name { 'Lorem Ipsum' }
  file { Rack::Test::UploadedFile.new File.join(Rails.root, 'test/files/test_image.png'), 'image/png' }
end