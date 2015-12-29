class Squib < ActiveRecord::Base
  include EchoUploads::Callbacks
  
  has_many :middens
  
  accepts_nested_attributes_for :middens, reject_if: :all_blank
  
  after_failed_save :write_midden_tmp_files
  
  def write_midden_tmp_files
    middens.each do |midden|
      midden.maybe_write_tmp_thumbnail
      midden.maybe_write_tmp_manual
    end
  end
end