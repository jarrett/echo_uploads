class CreateMiddens < ActiveRecord::Migration[4.2]
  def change
    create_table :middens do |t|
      t.integer :squib_id, null: false
      t.string :name, null: false
      t.timestamps
    end
  end
end
