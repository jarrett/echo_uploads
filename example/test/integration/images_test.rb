require 'test_helper'

class ImagesTest < ActionDispatch::IntegrationTest
  def assert_successful_upload
    assert_equal '/', current_path
    assert_selector 'ul#images > li'
    img_src = URI.parse(page.find('ul#images > li > img')['src']).path
    visit img_src
    headers = page.response_headers
    assert_equal 'inline; filename="test_image_1.png"', headers['Content-Disposition']
    assert_equal 'image/png', headers['Content-Type']
    assert_equal '1421', headers['Content-Length']
  end
  
  test 'successful upload in one attempt' do
    visit '/'
    click_link 'Upload image'
    fill_in 'image_name', with: 'Flower'
    attach_file 'image_file', example_file_path
    click_button 'Save'
    assert_successful_upload
  end
  
  test 'upload without name, resubmit without name again, resubmit with name' do
    visit '/'
    click_link 'Upload image'
    assert_selector 'input#image_file'
    attach_file 'image_file', example_file_path
    click_button 'Save'
    assert has_text?("can't be blank")
    assert_no_selector 'input#image_file'
    click_button 'Save'
    assert has_text?("can't be blank")
    assert_no_selector 'input#image_file'
    fill_in 'image_name', with: 'Flower'
    click_button 'Save'
    assert_successful_upload
  end
  
  test 'upload without image, resubmit with image' do
    visit '/'
    click_link 'Upload image'
    fill_in 'image_name', with: 'Flower'
    click_button 'Save'
    assert has_text?('must be uploaded')
    attach_file 'image_file', example_file_path
    click_button 'Save'
    assert_successful_upload
  end
  
  test 'upload oversized image, resubmit with valid image' do
    with_big_file_path do |big_file_path|
      visit '/'
      click_link 'Upload image'
      fill_in 'image_name', with: 'Flower'
      attach_file 'image_file', big_file_path
      click_button 'Save'
    end
    assert has_text?('must be smaller than 1536 bytes')
    attach_file 'image_file', example_file_path
    click_button 'Save'
    assert_successful_upload
  end
  
  test 'successfully upload new version of file' do
    skip
  end
  
  test 'try to upload new version with name blank, resubmit successfully' do
    skip
  end
  
  test 'try to upload oversized new version, resubmit successfully' do
    skip
  end
end