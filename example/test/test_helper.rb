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
end

class ActionDispatch::IntegrationTest
  include Capybara::DSL
end