require 'test_helper'

class SquibTest < ActiveSupport::TestCase
  test 'write_midden_tmp_files' do
    sqb = Squib.new(middens_attributes: [
      {name: 'Foo', manual: example_textfile},
      {name: '',    manual: example_textfile}
    ])
    refute sqb.save
    sqb.write_midden_tmp_files
    mid0 = sqb.middens[0]
    mid1 = sqb.middens[1]
    assert mid0.errors.empty?
    assert mid1.errors.any?
    refute mid0.has_prm_manual?
    refute mid1.has_prm_manual?
    assert mid0.has_tmp_manual?
    assert mid1.has_tmp_manual?
  end
end