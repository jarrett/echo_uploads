module ExampleFiles
  def example_image(num = 1)
    Rack::Test::UploadedFile.new example_image_path(num), 'image/png'
  end
  
  def example_image_digest(num = 1)
    Digest::SHA512.hexdigest File.read(example_image_path(num))
  end
  
  def example_image_path(num = 1)
    File.join Rails.root, "test/files/example_image_#{num}.png"
  end
  
  def example_textfile(num = 1)
    Rack::Test::UploadedFile.new example_textfile_path(num), 'text/plain'
  end
  
  def example_textfile_path(num = 1)
    File.join Rails.root, "test/files/example_textfile_#{num}.txt"
  end
  
  def with_big_image
    with_big_image_path do |big_image_path|
      yield Rack::Test::UploadedFile.new big_image_path, 'image/png'
    end
  end
  
  def with_big_image_path
    big_image_path = File.join(Rails.root, 'test/files/big_example_image.png')
    begin
      File.open(big_image_path, 'wb') do |f|
        data = File.read example_image_path
        2.times { f << data }
      end
      yield big_image_path
    ensure
      ::File.delete big_image_path if ::File.exists?(big_image_path)
    end
  end
end