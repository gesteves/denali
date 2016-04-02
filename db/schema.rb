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

ActiveRecord::Schema.define(version: 20160402191657) do

  create_table "blogs", force: :cascade do |t|
    t.string   "name"
    t.datetime "created_at",                          null: false
    t.datetime "updated_at",                          null: false
    t.string   "domain"
    t.text     "description"
    t.integer  "posts_per_page",       default: 10
    t.string   "short_domain"
    t.text     "about"
    t.string   "copyright"
    t.integer  "max_age",              default: 5
    t.boolean  "show_related_entries", default: true
  end

  add_index "blogs", ["domain"], name: "index_blogs_on_domain"

  create_table "entries", force: :cascade do |t|
    t.string   "title"
    t.text     "body"
    t.string   "slug"
    t.string   "status",            default: "draft"
    t.integer  "blog_id"
    t.integer  "user_id"
    t.datetime "created_at",                          null: false
    t.datetime "updated_at",                          null: false
    t.datetime "published_at"
    t.integer  "photos_count"
    t.integer  "position"
    t.string   "tumblr_id"
    t.boolean  "post_to_twitter"
    t.boolean  "post_to_tumblr"
    t.string   "tweet_text"
    t.boolean  "post_to_facebook"
    t.boolean  "post_to_flickr"
    t.boolean  "post_to_500px"
    t.boolean  "show_in_map",       default: true
    t.boolean  "post_to_slack"
    t.boolean  "post_to_pinterest"
  end

  add_index "entries", ["blog_id"], name: "index_entries_on_blog_id"
  add_index "entries", ["tumblr_id"], name: "index_entries_on_tumblr_id"
  add_index "entries", ["user_id"], name: "index_entries_on_user_id"

  create_table "photos", force: :cascade do |t|
    t.text     "caption"
    t.integer  "position"
    t.integer  "entry_id"
    t.datetime "created_at",         null: false
    t.datetime "updated_at",         null: false
    t.string   "image_file_name"
    t.string   "image_content_type"
    t.integer  "image_file_size"
    t.datetime "image_updated_at"
    t.string   "source_url"
    t.string   "make"
    t.string   "model"
    t.datetime "taken_at"
    t.string   "exposure"
    t.float    "f_number"
    t.float    "latitude"
    t.float    "longitude"
    t.integer  "width"
    t.integer  "height"
    t.integer  "iso"
    t.integer  "focal_length"
    t.string   "film_make"
    t.string   "film_type"
    t.string   "crop"
  end

  add_index "photos", ["entry_id"], name: "index_photos_on_entry_id"

  create_table "slack_incoming_webhooks", force: :cascade do |t|
    t.string   "team_name"
    t.string   "team_id"
    t.string   "url"
    t.string   "channel"
    t.string   "configuration_url"
    t.integer  "blog_id"
    t.datetime "created_at",        null: false
    t.datetime "updated_at",        null: false
  end

  add_index "slack_incoming_webhooks", ["blog_id"], name: "index_slack_incoming_webhooks_on_blog_id"

  create_table "taggings", force: :cascade do |t|
    t.integer  "tag_id"
    t.integer  "taggable_id"
    t.string   "taggable_type"
    t.integer  "tagger_id"
    t.string   "tagger_type"
    t.string   "context",       limit: 128
    t.datetime "created_at"
  end

  add_index "taggings", ["tag_id", "taggable_id", "taggable_type", "context", "tagger_id", "tagger_type"], name: "taggings_idx", unique: true
  add_index "taggings", ["taggable_id", "taggable_type", "context"], name: "index_taggings_on_taggable_id_and_taggable_type_and_context"

  create_table "tags", force: :cascade do |t|
    t.string  "name"
    t.integer "taggings_count", default: 0
    t.string  "slug"
  end

  add_index "tags", ["name"], name: "index_tags_on_name", unique: true
  add_index "tags", ["slug"], name: "index_tags_on_slug"

  create_table "users", force: :cascade do |t|
    t.string   "provider"
    t.string   "uid"
    t.string   "name"
    t.string   "email"
    t.string   "oauth_token"
    t.datetime "oauth_expires_at"
    t.datetime "created_at",       null: false
    t.datetime "updated_at",       null: false
  end

end
