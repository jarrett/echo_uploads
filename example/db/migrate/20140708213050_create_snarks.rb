if Rails::VERSION::MAJOR < 5
  parent_class = ActiveRecord::Migration
else
  parent_class = ActiveRecord::Migration[4.2]
end

class CreateSnarks < parent_class
  def change
    create_table :snarks do |t|
      t.timestamps
    end
  end
end
