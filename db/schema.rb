# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.0].define(version: 2024_09_08_143941) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", precision: nil, null: false
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "blogs", id: :serial, force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.text "tag_line"
    t.integer "posts_per_page", default: 10
    t.text "about"
    t.string "copyright"
    t.boolean "show_related_entries", default: true
    t.text "header_logo_svg"
    t.text "additional_meta_tags"
    t.string "facebook"
    t.integer "publish_schedules_count"
    t.string "time_zone", default: "UTC"
    t.text "meta_description"
    t.string "map_style"
    t.text "analytics_head"
    t.text "analytics_body"
    t.boolean "show_search", default: false
    t.string "email"
    t.string "flickr"
    t.string "instagram"
    t.string "tumblr"
    t.string "mastodon"
    t.string "bluesky"
  end

  create_table "cameras", force: :cascade do |t|
    t.string "make"
    t.string "model"
    t.string "slug"
    t.string "display_name"
    t.boolean "is_phone", default: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "amazon_url"
  end

  create_table "crops", force: :cascade do |t|
    t.float "x"
    t.float "y"
    t.float "width"
    t.float "height"
    t.bigint "photo_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "aspect_ratio"
    t.index ["aspect_ratio"], name: "index_crops_on_aspect_ratio"
    t.index ["photo_id"], name: "index_crops_on_photo_id"
  end

  create_table "entries", id: :serial, force: :cascade do |t|
    t.string "title"
    t.text "body"
    t.string "slug"
    t.string "status"
    t.integer "blog_id"
    t.integer "user_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.datetime "published_at", precision: nil
    t.integer "photos_count"
    t.integer "position"
    t.boolean "post_to_flickr", default: true
    t.boolean "show_location", default: true
    t.boolean "post_to_instagram", default: true
    t.string "preview_hash"
    t.datetime "modified_at", precision: nil
    t.text "instagram_text"
    t.boolean "post_to_flickr_groups", default: true
    t.string "tumblr_id"
    t.boolean "hide_from_search_engines", default: false
    t.boolean "post_to_tumblr", default: true
    t.string "tumblr_reblog_key"
    t.text "mastodon_text"
    t.boolean "post_to_mastodon", default: true
    t.string "content_warning"
    t.text "tumblr_text"
    t.boolean "is_sensitive", default: false
    t.boolean "post_to_bluesky", default: true
    t.text "bluesky_text"
    t.datetime "last_shared_on_instagram_at"
    t.datetime "last_shared_on_bluesky_at"
    t.datetime "last_shared_on_mastodon_at"
    t.index ["blog_id"], name: "index_entries_on_blog_id"
    t.index ["hide_from_search_engines"], name: "index_entries_on_hide_from_search_engines"
    t.index ["photos_count"], name: "index_entries_on_photos_count"
    t.index ["preview_hash"], name: "index_entries_on_preview_hash"
    t.index ["published_at"], name: "index_entries_on_published_at"
    t.index ["show_location"], name: "index_entries_on_show_location"
    t.index ["status"], name: "index_entries_on_status"
    t.index ["tumblr_id"], name: "index_entries_on_tumblr_id"
    t.index ["user_id"], name: "index_entries_on_user_id"
  end

  create_table "films", force: :cascade do |t|
    t.string "make"
    t.string "model"
    t.string "slug"
    t.string "display_name"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "amazon_url"
  end

  create_table "lenses", force: :cascade do |t|
    t.string "make"
    t.string "model"
    t.string "slug"
    t.string "display_name"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "amazon_url"
  end

  create_table "parks", force: :cascade do |t|
    t.string "full_name"
    t.string "short_name"
    t.string "code"
    t.string "designation"
    t.string "url"
    t.string "slug"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "display_name"
    t.index ["code"], name: "index_parks_on_code"
    t.index ["slug"], name: "index_parks_on_slug"
  end

  create_table "photos", id: :serial, force: :cascade do |t|
    t.text "alt_text"
    t.integer "position"
    t.integer "entry_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "source_url"
    t.datetime "taken_at", precision: nil
    t.string "exposure"
    t.float "f_number"
    t.float "latitude"
    t.float "longitude"
    t.integer "iso"
    t.integer "focal_length"
    t.float "focal_x"
    t.float "focal_y"
    t.string "country"
    t.string "locality"
    t.string "sublocality"
    t.string "neighborhood"
    t.string "administrative_area"
    t.string "postal_code"
    t.bigint "camera_id"
    t.bigint "lens_id"
    t.bigint "film_id"
    t.string "blurhash"
    t.boolean "color"
    t.boolean "black_and_white"
    t.string "dominant_color"
    t.text "territories"
    t.string "location"
    t.bigint "park_id"
    t.index ["camera_id"], name: "index_photos_on_camera_id"
    t.index ["entry_id"], name: "index_photos_on_entry_id"
    t.index ["film_id"], name: "index_photos_on_film_id"
    t.index ["latitude"], name: "index_photos_on_latitude"
    t.index ["lens_id"], name: "index_photos_on_lens_id"
    t.index ["longitude"], name: "index_photos_on_longitude"
    t.index ["park_id"], name: "index_photos_on_park_id"
  end

  create_table "profiles", force: :cascade do |t|
    t.string "username"
    t.string "name"
    t.string "instagram"
    t.string "tumblr"
    t.string "flickr"
    t.string "email"
    t.string "summary"
    t.text "bio"
    t.string "meta_description"
    t.bigint "photo_id"
    t.bigint "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "website"
    t.index ["photo_id"], name: "index_profiles_on_photo_id"
    t.index ["user_id"], name: "index_profiles_on_user_id"
    t.index ["username"], name: "index_profiles_on_username"
  end

  create_table "publish_schedules", force: :cascade do |t|
    t.integer "hour"
    t.bigint "blog_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["blog_id"], name: "index_publish_schedules_on_blog_id"
  end

  create_table "push_subscriptions", force: :cascade do |t|
    t.string "endpoint"
    t.string "p256dh"
    t.string "auth"
    t.bigint "blog_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["blog_id"], name: "index_push_subscriptions_on_blog_id"
  end

  create_table "tag_customizations", force: :cascade do |t|
    t.text "instagram_hashtags"
    t.text "flickr_groups"
    t.bigint "blog_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.text "flickr_albums"
    t.text "tumblr_tags"
    t.index ["blog_id"], name: "index_tag_customizations_on_blog_id"
  end

  create_table "taggings", id: :serial, force: :cascade do |t|
    t.integer "tag_id"
    t.string "taggable_type"
    t.integer "taggable_id"
    t.string "tagger_type"
    t.integer "tagger_id"
    t.string "context", limit: 128
    t.datetime "created_at", precision: nil
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
    t.datetime "oauth_expires_at", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "first_name"
    t.string "last_name"
    t.string "avatar_url"
  end

  create_table "webhooks", force: :cascade do |t|
    t.string "url"
    t.bigint "blog_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["blog_id"], name: "index_webhooks_on_blog_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "crops", "photos"
  add_foreign_key "entries", "blogs"
  add_foreign_key "entries", "users"
  add_foreign_key "photos", "cameras"
  add_foreign_key "photos", "entries"
  add_foreign_key "photos", "films"
  add_foreign_key "photos", "lenses"
  add_foreign_key "profiles", "photos"
  add_foreign_key "profiles", "users"
  add_foreign_key "push_subscriptions", "blogs"
  add_foreign_key "webhooks", "blogs"
end
