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
    
    Capybara.use_default_driver
  end
  
  def assert_bucket_count(expected_count, bucket_name, prefix = 'echo_uploads/test')
    actual_count = Aws::S3::Bucket.new(bucket_name).objects.count
    assert_equal(
      expected_count, actual_count,
      "Expected S3 bucket to contain #{expected_count} objects, but had #{actual_count}.\n\n" +
      "Objects were:\n\n" + bucket.objects.to_a.map(&:key).inspect
    )
  end
  
  def bucket
    @bucket ||= Aws::S3::Bucket.new(Rails.configuration.echo_uploads.s3.bucket)
  end
  
  def empty_s3
    # Be careful doing this in a real app! This deletes the entire bucket, which may not
    # be what you want.
    if bucket.exists?
      bucket.objects.each do |obj|
        obj.delete
      end
      bucket.delete!
    end
  end
  
  def ensure_s3_bucket_exists
    unless bucket.exists?
      bucket.create
    end
    assert bucket.exists?, 'Expected S3 bucket "example" to exist'
  end
end

class ActionDispatch::IntegrationTest
  include Capybara::DSL
end