class CreateSquibs < ActiveRecord::Migration
  def change
    create_table :squibs do |t|
      t.timestamps
    end
  end
end
