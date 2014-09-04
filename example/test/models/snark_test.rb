require 'test_helper'
require 'net/http'

# The purpose of the Snark model is to test EchoUploads::S3Store.
# 
# To run these tests, you'll need to start an instance of fakes3. From Rails root folder:
#   ./fakes3.sh
# 
# There may be a problem with Net:HTTP in Ruby 2, causing S3 requests to time out. See
# this thread for a description, and search in it for "excon" for a possible solution:
# 
# https://github.com/aws/aws-sdk-ruby/issues/241
class SnarkTest < ActiveSupport::TestCase
  before do
    ensure_s3_bucket_exists
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
      s3 = AWS::S3.new
      bucket = s3.buckets['example']
      exp_path = File.join 'echo_uploads/test', s.manual_key
      assert bucket.objects[exp_path].exists?, "Expected Snark to write file to S3 path: #{exp_path}"
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