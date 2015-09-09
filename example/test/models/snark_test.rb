require 'test_helper'
require 'net/http'

class SnarkTest < ActiveSupport::TestCase
  before do
    ensure_s3_bucket_exists
  end
  
  after do
    empty_s3
  end
  
  def with_s3
    begin
      yield
    rescue Errno::ECONNREFUSED
      raise 'fakes3 is not running'
    end
  end
  
  test 'writes to correct path on S3' do
    with_s3 do
      s = Snark.create! manual: example_textfile
      bucket = Aws::S3::Bucket.new 'example'
      exp_path = File.join 'echo_uploads/test', s.manual_key
      assert bucket.object(exp_path).exists?, "Expected Snark to write file to S3 path: #{exp_path}"
      assert_bucket_count 1, 'example', ''
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
      url.scheme = 'http'
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