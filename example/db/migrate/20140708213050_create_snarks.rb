class CreateSnarks < ActiveRecord::Migration[4.2]
  def change
    create_table :snarks do |t|
      t.timestamps
    end
  end
end
