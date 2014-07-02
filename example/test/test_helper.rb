ENV["RAILS_ENV"] ||= "test"
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'
require 'minitest/rails'
require 'capybara/rails'
require 'turn/autorun'
require 'fileutils'
require 'blueprints'

class ActiveSupport::TestCase
  ActiveRecord::Migration.check_pending!
  
  after do
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.clean
    
    FileUtils.rm_rf Dir.glob(File.join(Rails.root, 'echo_uploads/test/*'))
    
    Capybara.use_default_driver
  end
  
  def example_file(num = 1)
    Rack::Test::UploadedFile.new example_file_path(num), 'image/png'
  end
  
  def example_file_digest(num = 1)
    Digest::SHA512.hexdigest File.read(example_file_path(num))
  end
  
  def example_file_path(num = 1)
    File.join Rails.root, "test/files/test_image_#{num}.png"
  end
  
  def with_big_file
    with_big_file_path do |big_file_path|
      yield Rack::Test::UploadedFile.new big_file_path, 'image/png'
    end
  end
  
  def with_big_file_path
    big_file_path = File.join(Rails.root, 'test/files/big_test_image.png')
    begin
      File.open(big_file_path, 'wb') do |f|
        data = File.read example_file_path
        2.times { f << data }
      end
      yield big_file_path
    ensure
      ::File.delete big_file_path if ::File.exists?(big_file_path)
    end
  end
end

class ActionDispatch::IntegrationTest
  include Capybara::DSL
end