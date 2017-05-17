if Rails::VERSION::MAJOR < 5
  parent_class = ActiveRecord::Migration
else
  parent_class = ActiveRecord::Migration[4.2]
end

class CreateWidgets < parent_class
  def change
    create_table :widgets do |t|
      t.string :name
      t.timestamps
    end
  end
end
