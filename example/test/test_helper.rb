ENV["RAILS_ENV"] ||= "test"
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'
require 'minitest/rails'
require 'capybara/rails'
require 'turn/autorun'
require 'fileutils'
require 'example_files'

class ActiveSupport::TestCase
  include ExampleFiles
  
  ActiveRecord::Migration.check_pending!
  
  after do
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.clean
    
    FileUtils.rm_rf Dir.glob(File.join(Rails.root, 'echo_uploads/test/*'))
    empty_s3
    
    Capybara.use_default_driver
  end
  
  def assert_bucket_count(count, bucket_name, prefix = 'echo_uploads/test')
    s3 = AWS::S3.new
    bucket = s3.buckets[bucket_name]
    assert bucket.exists?, "Expected S3 bucket #{bucket_name} to exist"
    assert_equal(count, bucket.objects.with_prefix(prefix).count,
      "Expected S3 bucket to contain #{count} objects, but had #{bucket.objects.count}.\n\n" +
      "Objects were:\n\n" + bucket.objects.to_a.map(&:key).inspect
    )
  end
  
  def empty_s3
    # Be careful doing this in a real app! This empties the entire bucket, which may not
    # be what you want. More commonly, you'd use:
    #   s3 = AWS::S3.new
    #   bucket = s3.buckets['example']
    #   bucket.objects.with_prefix('echo_uploads/test/').delete_all
    # which would only delete the files from the test folder.
    s3 = AWS::S3.new
    bucket = s3.buckets['example']
    # There's a cleaner way to do this with the real S3 (bucket.delete!), but it doesn't
    # work with fakes3.
    if bucket.exists?
      bucket.objects.each(&:delete)
      bucket.delete
    end
  end
  
  def ensure_s3_bucket_exists
    s3 = AWS::S3.new
    unless s3.buckets['example'].exists?
      s3.buckets.create 'example'
    end
    assert s3.buckets['example'].exists?, 'Expected S3 bucket "example" to exist'
  end
end

class ActionDispatch::IntegrationTest
  include Capybara::DSL
end