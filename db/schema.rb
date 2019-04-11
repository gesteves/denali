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

ActiveRecord::Schema.define(version: 2019_04_10_235757) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.bigint "byte_size", null: false
    t.string "checksum", null: false
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "blogs", id: :serial, force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "tag_line"
    t.integer "posts_per_page", default: 10
    t.text "about"
    t.string "copyright"
    t.boolean "show_related_entries", default: true
    t.string "instagram"
    t.string "twitter"
    t.string "email"
    t.text "header_logo_svg"
    t.text "additional_meta_tags"
    t.string "flickr"
    t.string "facebook"
    t.integer "publish_schedules_count"
    t.string "time_zone", default: "UTC"
    t.text "meta_description"
  end

  create_table "cameras", force: :cascade do |t|
    t.string "make"
    t.string "model"
    t.string "slug"
    t.string "display_name"
    t.boolean "is_phone", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "entries", id: :serial, force: :cascade do |t|
    t.string "title"
    t.text "body"
    t.string "slug"
    t.string "status", default: "draft"
    t.integer "blog_id"
    t.integer "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "published_at"
    t.integer "photos_count"
    t.integer "position"
    t.boolean "post_to_twitter"
    t.string "tweet_text"
    t.boolean "post_to_facebook"
    t.boolean "post_to_flickr"
    t.boolean "show_in_map", default: true
    t.boolean "post_to_instagram"
    t.string "preview_hash"
    t.datetime "modified_at"
    t.text "instagram_text"
    t.index ["blog_id"], name: "index_entries_on_blog_id"
    t.index ["photos_count"], name: "index_entries_on_photos_count"
    t.index ["preview_hash"], name: "index_entries_on_preview_hash"
    t.index ["published_at"], name: "index_entries_on_published_at"
    t.index ["show_in_map"], name: "index_entries_on_show_in_map"
    t.index ["status"], name: "index_entries_on_status"
    t.index ["user_id"], name: "index_entries_on_user_id"
  end

  create_table "films", force: :cascade do |t|
    t.string "make"
    t.string "model"
    t.string "slug"
    t.string "display_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "lenses", force: :cascade do |t|
    t.string "make"
    t.string "model"
    t.string "slug"
    t.string "display_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "photos", id: :serial, force: :cascade do |t|
    t.text "alt_text"
    t.integer "position"
    t.integer "entry_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "source_url"
    t.datetime "taken_at"
    t.string "exposure"
    t.float "f_number"
    t.float "latitude"
    t.float "longitude"
    t.integer "width"
    t.integer "height"
    t.integer "iso"
    t.integer "focal_length"
    t.float "focal_x"
    t.float "focal_y"
    t.string "geocoded_address"
    t.string "country"
    t.string "locality"
    t.string "sublocality"
    t.string "neighborhood"
    t.string "administrative_area"
    t.string "color_vibrant"
    t.string "color_muted"
    t.string "color_palette"
    t.string "postal_code"
    t.bigint "camera_id"
    t.bigint "lens_id"
    t.bigint "film_id"
    t.index ["camera_id"], name: "index_photos_on_camera_id"
    t.index ["entry_id"], name: "index_photos_on_entry_id"
    t.index ["film_id"], name: "index_photos_on_film_id"
    t.index ["latitude"], name: "index_photos_on_latitude"
    t.index ["lens_id"], name: "index_photos_on_lens_id"
    t.index ["longitude"], name: "index_photos_on_longitude"
  end

  create_table "publish_schedules", force: :cascade do |t|
    t.integer "hour"
    t.bigint "blog_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["blog_id"], name: "index_publish_schedules_on_blog_id"
  end

  create_table "taggings", id: :serial, force: :cascade do |t|
    t.integer "tag_id"
    t.string "taggable_type"
    t.integer "taggable_id"
    t.string "tagger_type"
    t.integer "tagger_id"
    t.string "context", limit: 128
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

  create_table "tags", id: :serial, force: :cascade do |t|
    t.string "name"
    t.integer "taggings_count", default: 0
    t.string "slug"
    t.index ["name"], name: "index_tags_on_name", unique: true
    t.index ["slug"], name: "index_tags_on_slug"
  end

  create_table "users", id: :serial, force: :cascade do |t|
    t.string "provider"
    t.string "uid"
    t.string "name"
    t.string "email"
    t.string "oauth_token"
    t.datetime "oauth_expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "avatar_url"
  end

  add_foreign_key "entries", "blogs"
  add_foreign_key "entries", "users"
  add_foreign_key "photos", "cameras"
  add_foreign_key "photos", "entries"
  add_foreign_key "photos", "films"
  add_foreign_key "photos", "lenses"
end
