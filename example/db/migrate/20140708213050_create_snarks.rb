class CreateSnarks < ActiveRecord::Migration
  def change
    create_table :snarks do |t|
      t.timestamps
    end
  end
end
