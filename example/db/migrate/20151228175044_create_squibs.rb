class CreateSquibs < ActiveRecord::Migration[4.2]
  def change
    create_table :squibs do |t|
      t.timestamps
    end
  end
end
