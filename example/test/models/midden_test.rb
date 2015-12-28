require 'test_helper'

class MiddenTest < ActiveSupport::TestCase
  test 'writes temp thumbnail after failed validation' do
    mid = Midden.new thumbnail: example_image
    refute mid.has_tmp_thumbnail?
    refute mid.valid?
    assert mid.errors.has_key?(:name)
    refute mid.errors.has_key?(:thumbnail)
    refute mid.errors.has_key?(:manual)
    assert mid.has_tmp_thumbnail?
  end
  
  test 'never writes temp manual' do
    mid = Midden.new manual: example_textfile
    refute mid.has_tmp_manual?
    refute mid.valid?
    assert mid.errors.has_key?(:name)
    refute mid.errors.has_key?(:thumbnail)
    refute mid.errors.has_key?(:manual)
    refute mid.has_tmp_manual?
    refute mid.save
    refute mid.has_tmp_manual?
  end
end