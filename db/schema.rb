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

ActiveRecord::Schema.define(version: 20161126233934) do

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
    t.boolean  "show_related_entries", default: true
    t.index ["domain"], name: "index_blogs_on_domain"
  end

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
    t.boolean  "show_in_map",       default: true
    t.boolean  "post_to_slack"
    t.boolean  "post_to_pinterest"
    t.index ["blog_id"], name: "index_entries_on_blog_id"
    t.index ["photos_count"], name: "index_entries_on_photos_count"
    t.index ["published_at"], name: "index_entries_on_published_at"
    t.index ["show_in_map"], name: "index_entries_on_show_in_map"
    t.index ["status"], name: "index_entries_on_status"
    t.index ["tumblr_id"], name: "index_entries_on_tumblr_id"
    t.index ["user_id"], name: "index_entries_on_user_id"
  end

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
    t.index ["entry_id"], name: "index_photos_on_entry_id"
    t.index ["latitude"], name: "index_photos_on_latitude"
    t.index ["longitude"], name: "index_photos_on_longitude"
  end

  create_table "slack_incoming_webhooks", force: :cascade do |t|
    t.string   "team_name"
    t.string   "team_id"
    t.string   "url"
    t.string   "channel"
    t.string   "configuration_url"
    t.integer  "blog_id"
    t.datetime "created_at",        null: false
    t.datetime "updated_at",        null: false
    t.index ["blog_id"], name: "index_slack_incoming_webhooks_on_blog_id"
  end

  create_table "taggings", force: :cascade do |t|
    t.integer  "tag_id"
    t.integer  "taggable_id"
    t.string   "taggable_type"
    t.integer  "tagger_id"
    t.string   "tagger_type"
    t.string   "context",       limit: 128
    t.datetime "created_at"
    t.index ["context"], name: "index_taggings_on_context"
    t.index ["tag_id", "taggable_id", "taggable_type", "context", "tagger_id", "tagger_type"], name: "taggings_idx", unique: true
    t.index ["tag_id"], name: "index_taggings_on_tag_id"
    t.index ["taggable_id", "taggable_type", "context"], name: "index_taggings_on_taggable_id_and_taggable_type_and_context"
    t.index ["taggable_id", "taggable_type", "tagger_id", "context"], name: "taggings_idy"
    t.index ["taggable_id"], name: "index_taggings_on_taggable_id"
    t.index ["taggable_type"], name: "index_taggings_on_taggable_type"
    t.index ["tagger_id", "tagger_type"], name: "index_taggings_on_tagger_id_and_tagger_type"
    t.index ["tagger_id"], name: "index_taggings_on_tagger_id"
  end

  create_table "tags", force: :cascade do |t|
    t.string  "name"
    t.integer "taggings_count", default: 0
    t.string  "slug"
    t.index ["name"], name: "index_tags_on_name", unique: true
    t.index ["slug"], name: "index_tags_on_slug"
  end

  create_table "users", force: :cascade do |t|
    t.string   "provider"
    t.string   "uid"
    t.string   "name"
    t.string   "email"
    t.string   "oauth_token"
    t.datetime "oauth_expires_at"
    t.datetime "created_at",       null: false
    t.datetime "updated_at",       null: false
    t.string   "first_name"
    t.string   "last_name"
    t.string   "avatar_url"
  end

end
