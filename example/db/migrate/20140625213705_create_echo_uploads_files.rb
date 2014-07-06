class CreateEchoUploadsFiles < ActiveRecord::Migration
  def change
    create_table :echo_uploads_files do |t|
      t.integer :owner_id
      t.string :owner_type
      t.string :owner_attr
      t.string :storage_type
      t.string :key
      t.string :original_basename
      t.string :original_extension
      t.string :mime_type
      t.boolean :temporary
      t.datetime :expires_at
      t.timestamps
    end
    add_index :echo_uploads_files, :owner_id
    add_index :echo_uploads_files, :key
    add_index :echo_uploads_files, :temporary
  end
end
