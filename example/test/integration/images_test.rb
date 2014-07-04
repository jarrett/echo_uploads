require 'test_helper'

class ImagesTest < ActionDispatch::IntegrationTest
  def assert_successful_upload(image_num = 1)
    assert_equal '/', current_path
    assert_selector 'ul#images > li'
    img_src = URI.parse(page.find('ul#images > li > img')['src']).path
    visit img_src
    headers = page.response_headers
    assert_equal %Q(inline; filename="test_image_#{image_num}.png"), headers['Content-Disposition']
    assert_equal 'image/png', headers['Content-Type']
    assert_equal({1 => '1421', 2 => '1290'}[image_num], headers['Content-Length'])
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
    # Invalid upload.
    visit '/'
    click_link 'Upload image'
    assert_selector 'input#image_file'
    attach_file 'image_file', example_file_path
    click_button 'Save'
    assert has_text?("can't be blank")
    
    # Invalid upload.
    assert_no_selector 'input#image_file'
    click_button 'Save'
    assert has_text?("can't be blank")
    
    # Valid upload.
    assert_no_selector 'input#image_file'
    fill_in 'image_name', with: 'Flower'
    click_button 'Save'
    assert_successful_upload
  end
  
  test 'upload without image, resubmit with image' do
    # Invalid upload.
    visit '/'
    click_link 'Upload image'
    fill_in 'image_name', with: 'Flower'
    click_button 'Save'
    assert has_text?('must be uploaded')
    
    # Valid upload.
    attach_file 'image_file', example_file_path
    click_button 'Save'
    assert_successful_upload
  end
  
  test 'upload oversized image, resubmit with valid image' do
    # Invalid upload.
    with_big_file_path do |big_file_path|
      visit '/'
      click_link 'Upload image'
      fill_in 'image_name', with: 'Flower'
      attach_file 'image_file', big_file_path
      click_button 'Save'
      assert has_text?('must be smaller than 1536 bytes')
    end
    
    # Valid upload.
    attach_file 'image_file', example_file_path
    click_button 'Save'
    assert_successful_upload
  end
  
  test 'successfully upload new version of file' do
    visit '/images/new'
    fill_in 'image_name', with: 'Flower'
    attach_file 'image_file', example_file_path(1)
    click_button 'Save'
    assert_successful_upload 1
    
    visit '/'
    click_link 'Edit'
    attach_file 'image_file', example_file_path(2)
    click_button 'Save'
    assert_successful_upload 2
  end
  
  test 'try to upload new version with name blank, resubmit successfully' do
    # Valid upload.
    visit '/images/new'
    fill_in 'image_name', with: 'Flower'
    attach_file 'image_file', example_file_path(1)
    click_button 'Save'
    assert_successful_upload 1
    
    # Invalid upload.
    visit '/'
    click_link 'Edit'
    fill_in 'image_name', with: ''
    attach_file 'image_file', example_file_path(2)
    click_button 'Save'
    assert has_text?("can't be blank")
    
    # Valid upload.
    fill_in 'image_name', with: 'Flower'
    click_button 'Save'
    assert_successful_upload 2
  end
  
  test 'try to upload oversized new version, resubmit successfully' do
    # Valid upload.
    visit '/images/new'
    fill_in 'image_name', with: 'Flower'
    attach_file 'image_file', example_file_path(1)
    click_button 'Save'
    assert_successful_upload 1
    
    # Invalid upload.
    with_big_file_path do |big_file_path|
      visit '/'
      click_link 'Edit'    
      attach_file 'image_file', big_file_path
      click_button 'Save'
      assert has_text?('must be smaller than 1536 bytes')
    end
    
    # Valid upload.
    attach_file 'image_file', example_file_path(2)
    click_button 'Save'
    assert_successful_upload 2
  end
end