require 'test_helper'
require 'net/http'

# The purpose of the Snark model is to test EchoUploads::S3Store.
# 
# To run these tests, you'll need to start an instance of fakes3. From Rails root folder:
#   ./fakes3.sh
class SnarkTest < ActiveSupport::TestCase
  def with_s3
    begin
      yield
    rescue Errno::ECONNREFUSED
      raise 'fakes3 is not running'
    end
  end
  
  test 'write and read' do
    with_s3 do
      s = Snark.create! manual: example_textfile
      assert_equal(
        File.read(example_textfile_path),
        s.manual_metadata.storage.read(s.manual_key)
      )
    end
  end
  
  test 'generate S3 URL via SDK' do
    with_s3 do
      s = Snark.create! manual: example_textfile
      storage = s.manual_metadata.storage
      url = storage.url s.manual_metadata.key
      text = Net::HTTP.get url
      assert_equal File.read(example_textfile_path), text
    end
  end
  
  test 'delete' do
    s = Snark.create! manual: example_textfile
    storage = s.manual_metadata.storage
    assert storage.exists?(s.manual_key)
    storage.delete s.manual_key
    assert !storage.exists?(s.manual_key)
  end
  
  test 'exists?' do
    s = Snark.create! manual: example_textfile
    storage = s.manual_metadata.storage
    assert storage.exists?(s.manual_key)
    assert !storage.exists?('123')
  end
end