class CreateMiddens < ActiveRecord::Migration
  def change
    create_table :middens do |t|
      t.integer :squib_id, null: false
      t.string :name, null: false
      t.timestamps
    end
  end
end
