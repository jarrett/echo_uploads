class Squib < ActiveRecord::Base
  has_many :middens
  
  accepts_nested_attributes_for :middens, reject_if: :all_blank
  
  def write_midden_tmp_files
    if errors.any?
      middens.each do |midden|
        midden.maybe_write_tmp_thumbnail
        midden.maybe_write_tmp_manual
      end
    end
  end
end