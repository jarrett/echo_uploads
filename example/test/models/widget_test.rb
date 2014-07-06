require 'test_helper'

class WidgetTest < ActiveSupport::TestCase
  def assert_meta(meta, options = {})
    options.reverse_merge! temporary: false, widget_num: 1
    assert_equal meta.key, example_image_digest(options[:widget_num])
    assert_equal "test_image_#{options[:widget_num]}", meta.original_basename
    assert_equal '.png', meta.original_extension
    assert_equal 'image/png', meta.mime_type
    assert_equal options[:temporary], meta.temporary
    if options[:temporary]
      assert_in_delta 1.day.from_now.to_i, meta.expires_at.to_i, 5
    else
      assert_nil meta.expires_at
    end
    path = meta.storage.path(meta.key)
    assert ::File.exists? path
    assert_equal(
      example_image_digest(options[:widget_num]),
      Digest::SHA512.hexdigest(File.read(path))
    )
  end
  
  def assert_not_remember_meta(record)
    data = JSON.parse(Base64.decode64(record.echo_uploads_data))
    assert_equal({}, data)
  end
  
  def assert_remember_meta(record, attr, meta)
    data = JSON.parse(Base64.decode64(record.echo_uploads_data))
    assert_equal data[attr.to_s]['id'], meta.id
  end
  
  test 'creation' do
    Widget.create! name: 'Lorem Ipsum', thumbnail: example_image
  end
  
  test 'temp file persisted if record (but not the file itself) is invalid' do
    assert_equal 0, ::EchoUploads::File.count
    wid = Widget.create thumbnail: example_image
    assert_equal 1, ::EchoUploads::File.count
    meta = ::EchoUploads::File.first
    assert_meta meta, temporary: true
    assert_remember_meta wid, :thumbnail, meta
  end
  
  test 'temp file not persisted if file is invalid' do
    with_big_image do |big_image|
      assert_equal 0, ::EchoUploads::File.count
      wid = Widget.create name: 'Flower', thumbnail: big_image
      assert_equal 0, ::EchoUploads::File.count
      assert_not_remember_meta wid
    end
  end
  
  test 'temp files pruned when new file is persisted' do
    assert_equal 0, ::EchoUploads::File.count
    Widget.create thumbnail: example_image
    assert_equal 1, ::EchoUploads::File.count
    meta = ::EchoUploads::File.first
    assert_meta meta, temporary: true
    Timecop.travel(2.days.from_now) do
      Widget.create! name: 'Lorem Ipsum', thumbnail: example_image
    end
    assert_equal 1, ::EchoUploads::File.count
    assert !::EchoUploads::File.exists?(id: meta.id)
  end
  
  test 'temp files not pruned automatically when turned off' do
    Rails.configuration.echo_uploads.prune_tmp_files_on_upload = false
    begin
      assert_equal 0, ::EchoUploads::File.count
      Widget.create thumbnail: example_image
      assert_equal 1, ::EchoUploads::File.count
      meta = ::EchoUploads::File.first
      assert_meta meta, temporary: true
      Timecop.travel(2.days.from_now) do
        Widget.create! name: 'Lorem Ipsum', thumbnail: example_image
      end
      assert_equal 2, ::EchoUploads::File.count
      assert ::EchoUploads::File.exists?(id: meta.id)
    ensure
      Rails.configuration.echo_uploads.prune_tmp_files_on_upload = true
    end
  end
  
  test 'cannot claim permanent metadata by passing in malicious echo_uploads_data' do
    wid1 = Widget.create! name: 'Flower', thumbnail: example_image
    assert_equal 1, ::EchoUploads::File.count
    meta = ::EchoUploads::File.first
    assert !meta.temporary
    assert_equal wid1, meta.owner
    
    malicious_data = Base64.encode64(JSON.dump({
      'thumbnail' => {'id' => meta.id}
    }))
    assert_raises(ActiveRecord::RecordNotFound) do
      wid2 = Widget.create name: 'Eagle', echo_uploads_data: malicious_data
    end
  end
  
  test 'replaces file when new version is uploaded' do
    wid = Widget.create! name: 'Flower', thumbnail: example_image(1)
    assert_meta wid.thumbnail_metadata, widget_num: 1
    old_path = wid.thumbnail_path
    assert ::File.exists?(old_path), "Expected #{old_path} to exist"
    
    wid.update_attributes! thumbnail: example_image(2)
    assert_meta wid.thumbnail_metadata, widget_num: 2
    assert !::File.exists?(old_path), "Expected #{old_path} not to exist"
  end
  
  test 'does not delete file if another record references it' do
    wid1 = Widget.create! name: 'Flower', thumbnail: example_image(1)
    assert_meta wid1.thumbnail_metadata, widget_num: 1
    old_path = wid1.thumbnail_path
    
    wid2 = Widget.create! name: 'Eagle', thumbnail: example_image(1)
    
    assert ::File.exists?(old_path), "Expected #{old_path} to exist"
    wid1.update_attributes! thumbnail: example_image(2)
    assert_meta wid1.thumbnail_metadata, widget_num: 2
    assert ::File.exists?(old_path), "Expected #{old_path} to exist"
  end
  
  test 'deletes file when deleted' do
    wid = Widget.create! name: 'Flower', thumbnail: example_image
    assert_equal 1, EchoUploads::File.count
    assert ::File.exists?(wid.thumbnail_path), "Expected #{wid.thumbnail_path} to exist"
    wid.destroy
    assert !::File.exists?(wid.thumbnail_path), "Expected #{wid.thumbnail_path} not to exist"
  end
  
  test 'does not confuse metadata records for different attributes' do
    wid1 = Widget.create! name: 'Flower', thumbnail: example_image
    assert_kind_of EchoUploads::File, wid1.thumbnail_metadata
    assert_nil wid1.manual_metadata
    
    wid2 = Widget.create! name: 'Flower', thumbnail: example_image, manual: example_textfile
    assert_equal 'test_image_1.png', wid2.thumbnail_original_filename
    assert_equal 'test_textfile_1.txt', wid2.manual_original_filename
  end
end