if Rails::VERSION::MAJOR < 5
  parent_class = ActiveRecord::Migration
else
  parent_class = ActiveRecord::Migration[4.2]
end

class CreateSquibs < parent_class
  def change
    create_table :squibs do |t|
      t.timestamps
    end
  end
end
