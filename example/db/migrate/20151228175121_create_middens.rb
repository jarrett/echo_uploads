if Rails.version.major < 5
  parent_class = ActiveRecord::Migration
else
  parent_class = ActiveRecord::Migration[4.2]
end

class CreateMiddens < ActiveRecord::Migration[4.2]
  def change
    create_table :middens do |t|
      t.integer :squib_id, null: false
      t.string :name, null: false
      t.timestamps
    end
  end
end
