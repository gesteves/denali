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

ActiveRecord::Schema[8.1].define(version: 2026_02_01_201304) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", precision: nil, null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "blogs", id: :serial, force: :cascade do |t|
    t.text "about"
    t.text "additional_meta_tags"
    t.text "analytics_body"
    t.text "analytics_head"
    t.string "bluesky"
    t.datetime "created_at", precision: nil, null: false
    t.string "email"
    t.string "facebook"
    t.string "flickr"
    t.text "header_logo_svg"
    t.boolean "hide_from_search_engines", default: false
    t.string "instagram"
    t.string "mastodon"
    t.text "meta_description"
    t.string "name"
    t.integer "posts_per_page", default: 10
    t.integer "publish_schedules_count"
    t.boolean "show_related_entries", default: true
    t.boolean "show_search", default: false
    t.string "threads"
    t.string "time_zone", default: "UTC"
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "cameras", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.string "display_name"
    t.boolean "is_phone", default: false
    t.string "make"
    t.string "model"
    t.string "slug"
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "crops", force: :cascade do |t|
    t.string "aspect_ratio"
    t.datetime "created_at", null: false
    t.float "height"
    t.bigint "photo_id"
    t.datetime "updated_at", null: false
    t.float "width"
    t.float "x"
    t.float "y"
    t.index ["aspect_ratio"], name: "index_crops_on_aspect_ratio"
    t.index ["photo_id"], name: "index_crops_on_photo_id"
  end

  create_table "entries", id: :serial, force: :cascade do |t|
    t.integer "blog_id"
    t.integer "bluesky_shares_count", default: 0, null: false
    t.text "bluesky_text"
    t.text "body"
    t.string "content_warning"
    t.datetime "created_at", precision: nil, null: false
    t.boolean "hide_from_search_engines", default: false
    t.integer "instagram_shares_count", default: 0, null: false
    t.text "instagram_text"
    t.boolean "is_sensitive", default: false
    t.datetime "last_shared_on_bluesky_at"
    t.datetime "last_shared_on_instagram_at"
    t.datetime "last_shared_on_mastodon_at"
    t.datetime "last_shared_on_threads_at"
    t.integer "mastodon_shares_count", default: 0, null: false
    t.text "mastodon_text"
    t.datetime "modified_at", precision: nil
    t.integer "photos_count"
    t.integer "position"
    t.boolean "post_to_bluesky", default: true
    t.boolean "post_to_flickr", default: true
    t.boolean "post_to_flickr_groups", default: true
    t.boolean "post_to_instagram", default: true
    t.boolean "post_to_mastodon", default: true
    t.boolean "post_to_threads", default: true
    t.string "preview_hash"
    t.datetime "published_at", precision: nil
    t.boolean "show_location", default: true
    t.string "slug"
    t.string "status"
    t.integer "threads_shares_count", default: 0, null: false
    t.text "threads_text"
    t.string "title"
    t.datetime "updated_at", precision: nil, null: false
    t.integer "user_id"
    t.boolean "valid_bluesky_caption", default: true, null: false
    t.boolean "valid_instagram_caption", default: true, null: false
    t.boolean "valid_mastodon_caption", default: true, null: false
    t.boolean "valid_threads_caption", default: true, null: false
    t.index ["blog_id", "status", "created_at"], name: "index_entries_on_blog_status_created", order: { created_at: :desc }
    t.index ["blog_id", "status", "hide_from_search_engines", "modified_at"], name: "index_entries_on_blog_status_indexable"
    t.index ["blog_id", "status", "position"], name: "index_entries_on_blog_status_position"
    t.index ["blog_id", "status", "published_at"], name: "index_entries_on_blog_status_published", order: { published_at: :desc }
    t.index ["bluesky_shares_count"], name: "index_entries_on_bluesky_shares_count"
    t.index ["hide_from_search_engines"], name: "index_entries_on_hide_from_search_engines"
    t.index ["instagram_shares_count"], name: "index_entries_on_instagram_shares_count"
    t.index ["mastodon_shares_count"], name: "index_entries_on_mastodon_shares_count"
    t.index ["photos_count"], name: "index_entries_on_photos_count"
    t.index ["preview_hash"], name: "index_entries_on_preview_hash"
    t.index ["published_at"], name: "index_entries_on_published_at"
    t.index ["show_location"], name: "index_entries_on_show_location"
    t.index ["status", "published_at"], name: "index_entries_on_status_published_at"
    t.index ["threads_shares_count"], name: "index_entries_on_threads_shares_count"
    t.index ["user_id"], name: "index_entries_on_user_id"
  end

  create_table "films", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.string "display_name"
    t.string "make"
    t.string "model"
    t.string "slug"
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "lenses", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.string "display_name"
    t.string "make"
    t.string "model"
    t.string "slug"
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "mastodon_apps", force: :cascade do |t|
    t.string "client_id", null: false
    t.text "client_secret", null: false
    t.datetime "created_at", null: false
    t.string "instance_url", null: false
    t.datetime "updated_at", null: false
    t.index ["instance_url"], name: "index_mastodon_apps_on_instance_url", unique: true
  end

  create_table "parks", force: :cascade do |t|
    t.string "code"
    t.datetime "created_at", null: false
    t.string "designation"
    t.string "display_name"
    t.string "full_name"
    t.string "instagram_location_id"
    t.string "short_name"
    t.string "slug"
    t.string "threads_location_id"
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["code"], name: "index_parks_on_code"
    t.index ["slug"], name: "index_parks_on_slug"
  end

  create_table "photo_territories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "photo_id", null: false
    t.bigint "territory_id", null: false
    t.datetime "updated_at", null: false
    t.index ["photo_id", "territory_id"], name: "index_photo_territories_on_photo_id_and_territory_id", unique: true
    t.index ["photo_id"], name: "index_photo_territories_on_photo_id"
    t.index ["territory_id"], name: "index_photo_territories_on_territory_id"
  end

  create_table "photos", id: :serial, force: :cascade do |t|
    t.string "administrative_area"
    t.text "alt_text"
    t.boolean "alt_text_needs_review", default: false
    t.text "auto_generated_alt_text"
    t.boolean "black_and_white"
    t.string "blurhash"
    t.bigint "camera_id"
    t.boolean "color"
    t.string "country"
    t.datetime "created_at", precision: nil, null: false
    t.string "dominant_color"
    t.integer "entry_id"
    t.string "exposure"
    t.float "f_number"
    t.bigint "film_id"
    t.integer "focal_length"
    t.float "focal_x"
    t.float "focal_y"
    t.integer "iso"
    t.float "latitude"
    t.bigint "lens_id"
    t.string "locality"
    t.string "location"
    t.float "longitude"
    t.string "neighborhood"
    t.bigint "park_id"
    t.integer "position"
    t.string "postal_code"
    t.string "source_url"
    t.string "sublocality"
    t.datetime "taken_at", precision: nil
    t.datetime "updated_at", precision: nil, null: false
    t.index ["camera_id"], name: "index_photos_on_camera_id"
    t.index ["entry_id"], name: "index_photos_on_entry_id"
    t.index ["film_id"], name: "index_photos_on_film_id"
    t.index ["latitude"], name: "index_photos_on_latitude"
    t.index ["lens_id"], name: "index_photos_on_lens_id"
    t.index ["longitude"], name: "index_photos_on_longitude"
    t.index ["park_id"], name: "index_photos_on_park_id"
  end

  create_table "publish_schedules", force: :cascade do |t|
    t.bigint "blog_id"
    t.datetime "created_at", precision: nil, null: false
    t.integer "hour"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["blog_id"], name: "index_publish_schedules_on_blog_id"
  end

  create_table "push_subscriptions", force: :cascade do |t|
    t.string "auth"
    t.bigint "blog_id"
    t.datetime "created_at", null: false
    t.string "endpoint"
    t.string "p256dh"
    t.datetime "updated_at", null: false
    t.index ["blog_id"], name: "index_push_subscriptions_on_blog_id"
  end

  create_table "social_accounts", force: :cascade do |t|
    t.text "access_token"
    t.text "access_token_secret"
    t.datetime "connected_at"
    t.datetime "created_at", null: false
    t.string "handle"
    t.string "provider", null: false
    t.string "server_url"
    t.string "uid"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["provider", "uid"], name: "index_social_accounts_on_provider_and_uid", unique: true
    t.index ["user_id", "provider"], name: "index_social_accounts_on_user_id_and_provider", unique: true
    t.index ["user_id"], name: "index_social_accounts_on_user_id"
  end

  create_table "tag_customizations", force: :cascade do |t|
    t.bigint "blog_id"
    t.text "bluesky_hashtags"
    t.datetime "created_at", precision: nil, null: false
    t.text "flickr_albums"
    t.text "flickr_groups"
    t.text "instagram_hashtags"
    t.text "mastodon_hashtags"
    t.text "threads_topics"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["blog_id"], name: "index_tag_customizations_on_blog_id"
  end

  create_table "taggings", id: :serial, force: :cascade do |t|
    t.string "context", limit: 128
    t.datetime "created_at", precision: nil
    t.integer "tag_id"
    t.integer "taggable_id"
    t.string "taggable_type"
    t.integer "tagger_id"
    t.string "tagger_type"
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
    t.string "slug"
    t.integer "taggings_count", default: 0
    t.index ["name"], name: "index_tags_on_name", unique: true
    t.index ["slug"], name: "index_tags_on_slug"
  end

  create_table "territories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.string "slug"
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["slug"], name: "index_territories_on_slug", unique: true
  end

  create_table "users", id: :serial, force: :cascade do |t|
    t.string "avatar_url"
    t.datetime "created_at", precision: nil, null: false
    t.string "email"
    t.string "first_name"
    t.string "last_name"
    t.string "name"
    t.datetime "oauth_expires_at", precision: nil
    t.string "oauth_token"
    t.string "provider"
    t.string "uid"
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "webhooks", force: :cascade do |t|
    t.bigint "blog_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "url"
    t.index ["blog_id"], name: "index_webhooks_on_blog_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "crops", "photos"
  add_foreign_key "entries", "blogs"
  add_foreign_key "entries", "users"
  add_foreign_key "photo_territories", "photos"
  add_foreign_key "photo_territories", "territories"
  add_foreign_key "photos", "cameras"
  add_foreign_key "photos", "entries"
  add_foreign_key "photos", "films"
  add_foreign_key "photos", "lenses"
  add_foreign_key "push_subscriptions", "blogs"
  add_foreign_key "social_accounts", "users"
  add_foreign_key "webhooks", "blogs"
end
