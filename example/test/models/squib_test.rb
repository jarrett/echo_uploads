require 'test_helper'

class SquibTest < ActiveSupport::TestCase
  test 'write_midden_tmp_files' do
    sqb = Squib.new(middens_attributes: [
      {name: 'Foo', manual: example_textfile},
      {name: '',    manual: example_textfile}
    ])
    refute sqb.save, 'Should fail to save'
    mid0 = sqb.middens[0]
    mid1 = sqb.middens[1]
    refute mid0.errors.any?, 'Should be valid'
    assert mid1.errors.any?, 'Should be invalid'
    refute mid0.has_prm_manual?, 'Should not have perm manual'
    refute mid1.has_prm_manual?, 'Should not have perm manual'
    assert mid0.has_tmp_manual?, 'Should have temp manual'
    assert mid1.has_tmp_manual?, 'Should have temp manual'
  end
end