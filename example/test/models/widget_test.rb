require 'test_helper'

class WidgetTest < ActiveSupport::TestCase
  def assert_meta(meta, options = {})
    options.reverse_merge!(
      temporary: false,
      widget_num: 1,
      original_extension: '.png',
      mime_type: 'image/png',
    )
    # Merge a second time for keys that depend on widget_num.
    options.reverse_merge!(
      original_basename: "example_image_#{options[:widget_num]}",
      key: example_image_digest(options[:widget_num])
    )
    
    assert_equal options[:key], meta.key
    assert_equal options[:original_basename], meta.original_basename
    assert_equal options[:original_extension], meta.original_extension
    assert_equal options[:mime_type], meta.mime_type
    assert_equal options[:temporary], meta.temporary
    if options[:temporary]
      assert_in_delta 1.day.from_now.to_i, meta.expires_at.to_i, 5
    else
      assert_nil meta.expires_at
    end
    
    path = meta.storage.path(meta.key)
    assert ::File.exists? path
    assert_equal File.size(path), meta.size
    assert_equal(
      options[:key],
      Digest::SHA512.hexdigest(File.read(path))
    )
  end
  
  def assert_not_remember_meta(record)
    data = JSON.parse(Base64.decode64(record.echo_uploads_data))
    assert_equal({}, data)
  end
  
  def assert_remember_meta(record, attr, meta)
    data = JSON.parse(Base64.decode64(record.echo_uploads_data))
    assert_equal meta.id, data[attr.to_s].first['id']
  end
  
  test 'creation' do
    Widget.create! name: 'Lorem Ipsum', thumbnail: example_image
  end
  
  test 'temp file persisted if record but not the file itself is invalid' do
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
  
  # Tests bug fix: Temp files saved during failed call to update_attributes were lost
  # during ActiveRecord transaction rollback.
  test 'temp file persisted on update_attributes' do
    # Save a valid record.
    assert_equal 0, ::EchoUploads::File.count
    wid = Widget.create! name: 'Lorem ipsum', thumbnail: example_image(1)
    assert wid.persisted?
    assert_equal 1, ::EchoUploads::File.count
    meta1 = ::EchoUploads::File.last
    assert_meta meta1, temporary: false, widget_num: 1
    
    # Try to update_attributes with name blank and a new thumbnail.
    Rails.logger.info 'About to update attributes'
    refute wid.update_attributes(name: '', thumbnail: example_image(2))
    Rails.logger.info 'Done updating attributes'
    assert_equal 2, ::EchoUploads::File.count, 'Maybe temp file was rolled back in transaction'
    meta2 = ::EchoUploads::File.last
    assert_meta meta2, temporary: true, widget_num: 2
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
      'thumbnail' => [{'id' => meta.id}]
    }))
    wid2 = Widget.create name: 'Eagle', echo_uploads_data: malicious_data
    assert !wid2.persisted?
    assert wid2.errors[:thumbnail] == ['must be uploaded']
    assert !wid2.has_tmp_thumbnail?
    assert !wid2.has_prm_thumbnail?
    assert !wid2.has_thumbnail?
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
    assert_equal 'example_image_1.png', wid2.thumbnail_original_filename
    assert_equal 'example_textfile_1.txt', wid2.manual_original_filename
  end
  
  # Tests :map with :multiple.
  test 'resizes photos' do
    wid = Widget.create! name: 'Flower', thumbnail: example_image(1), photo: example_image(2)
    
    img = ChunkyPNG::Image.from_file(wid.photos[0].path)
    assert_equal 200, img.width
    assert_equal 200, img.height
    assert_equal 'image/png', wid.photos[0].mime_type
    
    img = ChunkyPNG::Image.from_file(wid.photos[1].path)
    assert_equal 300, img.width
    assert_equal 300, img.height
    assert_equal 'image/png', wid.photos[1].mime_type
  end
  
  # Tests :map without :multiple
  test 'reverses warranty text' do
    wid = Widget.create! name: 'Flower', thumbnail: example_image, warranty: example_textfile
    assert File.exists?(wid.warranty_path)
    text = File.read wid.warranty_path
    assert_equal '.elif txet elpmaxE', text
  end
  
  test 'does not try to persist the permanent file twice even if saved twice' do
    # If we tried to persist twice, the manual's mapping would raise a 'No such file or
    # directory' exception.
    wid = Widget.create! name: 'Flower', thumbnail: example_image, warranty: example_textfile
    wid.save!
  end
  
  test 'does not try to persist the temporary file twice even if saved twice' do
    # Invalid attributes.
    wid = Widget.create warranty: example_textfile
    wid.save
    assert wid.new_record?
  end
  
  test 'deletes temporary files created by :map' do
    prev_files = Dir.glob File.join(Rails.root, 'tmp/echo_uploads/*')
    wid = Widget.create! name: 'Flower', thumbnail: example_image(1), photo: example_image(2)
    curr_files = Dir.glob File.join(Rails.root, 'tmp/echo_uploads/*')
    new_files = curr_files - prev_files
    assert_empty new_files
  end
  
  test 'tracks dirtiness of file attributes' do
    wid = Widget.create! name: 'Flower', thumbnail: example_image(1), photo: example_image(2)
    wid.reload
    wid.thumbnail = example_image(2)
    assert wid.attribute_changed?(:thumbnail)
    wid.reload
    wid.attributes = {thumbnail: example_image(2)}
    assert wid.attribute_changed?(:thumbnail)
  end
  
  test 'supports read_manual' do
    wid = Widget.create! name: 'Flower', thumbnail: example_image, manual: example_textfile
    assert wid.has_prm_manual?
    assert_equal 'Example text file.', wid.read_manual
  end
  
  test 'knows its size' do
    wid = Widget.create! name: 'Lorem Ipsum', thumbnail: example_image
    assert_equal 1421, wid.thumbnail_size
    wid.reload
    assert_equal 1421, wid.thumbnail_size
  end
  
  test 'write_thumbnail with block' do
    wid = Widget.create! name: 'Flower', thumbnail: example_image(1)
    assert_meta wid.thumbnail_metadata, widget_num: 1
    old_path = wid.thumbnail_path
    assert ::File.exists?(old_path), "Expected #{old_path} to exist"
    
    wid.write_thumbnail do |f|
      f.write File.read(example_image_path(2))
    end
    wid.reload
    
    assert wid.has_prm_thumbnail?, 'Expected has_prm_thumbnail? to be true'
    # The original_filename doesn't change.
    assert_meta wid.thumbnail_metadata, widget_num: 2, original_basename: 'example_image_1'
    assert ::File.exists?(wid.thumbnail_path), "Expected #{wid.thumbnail_path} to exist"
    assert !::File.exists?(old_path), "Expected #{old_path} not to exist"
  end
  
  test 'write_thumbnail without block' do
    wid = Widget.create! name: 'Flower', thumbnail: example_image(1)
    assert_meta wid.thumbnail_metadata, widget_num: 1
    old_path = wid.thumbnail_path
    assert ::File.exists?(old_path), "Expected #{old_path} to exist"
    
    f = wid.write_thumbnail
    f.write File.read(example_image_path(2))
    f.close
    wid.reload
    
    assert wid.has_prm_thumbnail?, 'Expected has_prm_thumbnail? to be true'
    # The original_filename doesn't change.
    assert_meta wid.thumbnail_metadata, widget_num: 2, original_basename: 'example_image_1'
    assert ::File.exists?(wid.thumbnail_path), "Expected #{wid.thumbnail_path} to exist"
    assert !::File.exists?(old_path), "Expected #{old_path} not to exist"
  end
  
  test 'write_thumbnail tempfile accessor' do
    wid = Widget.create! name: 'Flower', thumbnail: example_image(1)
    wid.write_thumbnail do |f|
      assert_kind_of Tempfile, f.tempfile
    end
  end
  
  test 'destroy thumbnail' do
    wid = Widget.create! name: 'Flower', thumbnail: example_image(1)
    assert wid.has_thumbnail?
    wid.destroy_thumbnail
    wid = Widget.find wid.id
    refute wid.has_thumbnail?
  end
  
  test 'destroy one of the photos' do
    wid = Widget.create! name: 'Flower', photo: example_image(1), thumbnail: example_image(1)
    assert_equal 2, wid.photos.count
    wid.photos[0].destroy
    wid = Widget.find wid.id
    assert_equal 1, wid.photos.count
  end
end