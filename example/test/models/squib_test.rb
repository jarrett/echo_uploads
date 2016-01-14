require 'test_helper'

class SquibTest < ActiveSupport::TestCase
  test 'writes midden tmp files on create' do
    sqb = Squib.new(middens_attributes: [
      {name: 'Foo', manual: example_textfile},
      {name: '',    manual: example_textfile}
    ])
    refute sqb.save, 'Should fail to save'
    mid0 = sqb.middens[0]
    mid1 = sqb.middens[1]
    refute mid0.errors.any?, 'Should be valid'
    assert mid1.errors.any?, 'Should be invalid'
    refute mid0.has_prm_manual?, 'Should not have prm manual'
    refute mid1.has_prm_manual?, 'Should not have prm manual'
    assert mid0.has_tmp_manual?, 'Should have tmp manual'
    assert mid1.has_tmp_manual?, 'Should have tmp manual'
  end
  
  test 'writes midden tmp files on update' do
    sqb = Squib.new(middens_attributes: [
      {name: 'Foo', manual: example_textfile(1)},
      {name: 'Bar', manual: example_textfile(1)}
    ])
    assert sqb.save, 'Should fail to save'
    mid0 = sqb.middens[0]
    mid1 = sqb.middens[1]
    
    refute(sqb.update_attributes(middens_attributes: [
      {id: mid0.id, name: 'Foo', manual: example_textfile(2)},
      {id: mid1.id, name: '', manual: example_textfile(2)},
    ]), 'Should fail to save')
    mid0 = sqb.middens[0]
    mid1 = sqb.middens[1]
    refute mid0.errors.any?, 'Should be valid'
    assert mid1.errors.any?, 'Should be invalid'
    assert mid0.has_prm_manual?, 'Should have prm manual'
    assert mid1.has_prm_manual?, 'Should have prm manual'
    assert mid0.has_tmp_manual?, 'Should have tmp manual'
    assert mid1.has_tmp_manual?, 'Should have tmp manual'
  end
  
  test 'writes midden prm files on update' do
    sqb = Squib.create!(middens_attributes: [
      {name: 'Foo', manual: example_textfile(1)},
      {name: 'Bar', manual: example_textfile(1)}
    ])
    mid0 = sqb.middens[0]
    mid1 = sqb.middens[1]
    
    # ActiveRecord will save the nested records only if they're marked as dirty. By
    # setting the names to the same values, we verify that EchoUploads properly marks the
    # record as dirty based solely on the presence of the uploaded file.
    sqb.update_attributes!(middens_attributes: [
      {id: mid0.id, name: 'Foo', manual: example_textfile(2)},
      {id: mid1.id, name: 'Bar', manual: example_textfile(2)},
    ])
    
    assert_equal 'Another example text file.', mid0.read_manual
    assert_equal 'Another example text file.', mid1.read_manual
  end
end