require 'test_helper'

class WidgetsTest < ActionDispatch::IntegrationTest
  def assert_successful_upload(widget_num = 1)
    assert_equal '/', current_path
    assert_selector 'ul#widgets > li'
    img_src = URI.parse(page.find('ul#widgets > li > img')['src']).path
    visit img_src
    headers = page.response_headers
    assert_equal %Q(inline; filename="test_image_#{widget_num}.png"), headers['Content-Disposition']
    assert_equal 'image/png', headers['Content-Type']
    assert_equal({1 => '1421', 2 => '1290'}[widget_num], headers['Content-Length'])
  end
  
  test 'successful upload in one attempt' do
    visit '/'
    click_link 'New widget'
    fill_in 'widget_name', with: 'Flower'
    attach_file 'widget_thumbnail', example_image_path
    click_button 'Save'
    assert_successful_upload
  end
  
  test 'upload without name, resubmit without name again, resubmit with name' do
    # Invalid upload.
    visit '/'
    click_link 'New widget'
    assert_selector 'input#widget_thumbnail'
    attach_file 'widget_thumbnail', example_image_path
    click_button 'Save'
    assert has_text?("can't be blank")
    
    # Invalid upload.
    assert_no_selector 'input#widget_thumbnail'
    click_button 'Save'
    assert has_text?("can't be blank")
    
    # Valid upload.
    assert_no_selector 'input#widget_thumbnail'
    fill_in 'widget_name', with: 'Flower'
    click_button 'Save'
    assert_successful_upload
  end
  
  test 'upload without widget, resubmit with widget' do
    # Invalid upload.
    visit '/'
    click_link 'New widget'
    fill_in 'widget_name', with: 'Flower'
    click_button 'Save'
    assert has_text?('must be uploaded')
    
    # Valid upload.
    attach_file 'widget_thumbnail', example_image_path
    click_button 'Save'
    assert_successful_upload
  end
  
  test 'upload oversized widget, resubmit with valid widget' do
    # Invalid upload.
    with_big_image_path do |big_image_path|
      visit '/'
      click_link 'New widget'
      fill_in 'widget_name', with: 'Flower'
      attach_file 'widget_thumbnail', big_image_path
      click_button 'Save'
      assert has_text?('must be smaller than 1536 bytes')
    end
    
    # Valid upload.
    attach_file 'widget_thumbnail', example_image_path
    click_button 'Save'
    assert_successful_upload
  end
  
  test 'successfully upload new version of file' do
    visit '/widgets/new'
    fill_in 'widget_name', with: 'Flower'
    attach_file 'widget_thumbnail', example_image_path(1)
    click_button 'Save'
    assert_successful_upload 1
    
    visit '/'
    click_link 'Edit'
    attach_file 'widget_thumbnail', example_image_path(2)
    click_button 'Save'
    assert_successful_upload 2
  end
  
  test 'try to upload new version with name blank, resubmit successfully' do
    # Valid upload.
    visit '/widgets/new'
    fill_in 'widget_name', with: 'Flower'
    attach_file 'widget_thumbnail', example_image_path(1)
    click_button 'Save'
    assert_successful_upload 1
    
    # Invalid upload.
    visit '/'
    click_link 'Edit'
    fill_in 'widget_name', with: ''
    attach_file 'widget_thumbnail', example_image_path(2)
    click_button 'Save'
    assert has_text?("can't be blank")
    
    # Valid upload.
    fill_in 'widget_name', with: 'Flower'
    click_button 'Save'
    assert_successful_upload 2
  end
  
  test 'try to upload oversized new version, resubmit successfully' do
    # Valid upload.
    visit '/widgets/new'
    fill_in 'widget_name', with: 'Flower'
    attach_file 'widget_thumbnail', example_image_path(1)
    click_button 'Save'
    assert_successful_upload 1
    
    # Invalid upload.
    with_big_image_path do |big_image_path|
      visit '/'
      click_link 'Edit'    
      attach_file 'widget_thumbnail', big_image_path
      click_button 'Save'
      assert has_text?('must be smaller than 1536 bytes')
    end
    
    # Valid upload.
    attach_file 'widget_thumbnail', example_image_path(2)
    click_button 'Save'
    assert_successful_upload 2
  end
end