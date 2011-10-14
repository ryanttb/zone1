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
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20111012180516) do

  create_table "access_levels", :force => true do |t|
    t.string "name",  :null => false
    t.string "label", :null => false
  end

  create_table "batches", :force => true do |t|
    t.integer "user_id"
  end

  create_table "content_types", :force => true do |t|
    t.string "name", :null => false
  end

  create_table "flags", :force => true do |t|
    t.string "name",  :null => false
    t.string "label", :null => false
  end

  create_table "flags_stored_files", :id => false, :force => true do |t|
    t.integer "flag_id"
    t.integer "stored_file_id"
  end

  create_table "groups", :force => true do |t|
    t.string   "name",       :null => false
    t.integer  "user_id",    :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "groups_users", :id => false, :force => true do |t|
    t.integer "user_id"
    t.integer "group_id"
  end

  create_table "roles", :id => false, :force => true do |t|
    t.string   "name",              :limit => 40
    t.string   "authorizable_type", :limit => 40
    t.integer  "authorizable_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "roles_groups", :id => false, :force => true do |t|
    t.integer  "group_id"
    t.integer  "role_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "roles_users", :id => false, :force => true do |t|
    t.integer  "user_id"
    t.integer  "role_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "stored_files", :force => true do |t|
    t.integer  "batch_id_id"
    t.integer  "user_id",               :null => false
    t.string   "original_file_name",    :null => false
    t.string   "collection_name"
    t.integer  "access_level_id",       :null => false
    t.integer  "content_type_id",       :null => false
    t.date     "retention_plan_date"
    t.string   "retention_plan_action"
    t.string   "format_name"
    t.string   "format_version"
    t.string   "mime_type"
    t.string   "md5"
    t.integer  "file_size"
    t.text     "description"
    t.text     "copyright"
    t.datetime "ingest_date"
    t.text     "license_terms"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "public_taggable"
  end

  create_table "stored_files_flags", :id => false, :force => true do |t|
    t.integer "stored_file_id"
    t.integer "flag_id"
  end

  create_table "taggings", :force => true do |t|
    t.integer  "tag_id"
    t.integer  "taggable_id"
    t.string   "taggable_type"
    t.integer  "tagger_id"
    t.string   "tagger_type"
    t.string   "context"
    t.datetime "created_at"
  end

  add_index "taggings", ["tag_id"], :name => "index_taggings_on_tag_id"
  add_index "taggings", ["taggable_id", "taggable_type", "context"], :name => "index_taggings_on_taggable_id_and_taggable_type_and_context"

  create_table "tags", :force => true do |t|
    t.string "name"
  end

  create_table "users", :force => true do |t|
    t.string   "email",                                 :default => "", :null => false
    t.string   "encrypted_password",     :limit => 128, :default => "", :null => false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",                         :default => 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.string   "name",                                                  :null => false
    t.string   "affiliation"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "users", ["email"], :name => "index_users_on_email", :unique => true
  add_index "users", ["reset_password_token"], :name => "index_users_on_reset_password_token", :unique => true

end
