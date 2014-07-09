# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20140708213050) do

  create_table "echo_uploads_files", force: true do |t|
    t.integer  "owner_id"
    t.string   "owner_type"
    t.string   "owner_attr"
    t.string   "storage_type"
    t.string   "key"
    t.string   "original_basename"
    t.string   "original_extension"
    t.string   "mime_type"
    t.boolean  "temporary"
    t.datetime "expires_at"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "echo_uploads_files", ["key"], name: "index_echo_uploads_files_on_key"
  add_index "echo_uploads_files", ["owner_id"], name: "index_echo_uploads_files_on_owner_id"
  add_index "echo_uploads_files", ["temporary"], name: "index_echo_uploads_files_on_temporary"

  create_table "snarks", force: true do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "widgets", force: true do |t|
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

end
