class AddCompositeIndexesToEntries < ActiveRecord::Migration[8.0]
  def change
    # For published entries (admin index, public index, feeds)
    # Covers: WHERE blog_id=? AND status='published' ORDER BY published_at DESC
    add_index :entries, [:blog_id, :status, :published_at],
              order: { published_at: :desc },
              name: 'index_entries_on_blog_status_published'

    # For queued entries (admin queued)
    # Covers: WHERE blog_id=? AND status='queued' ORDER BY position ASC
    add_index :entries, [:blog_id, :status, :position],
              name: 'index_entries_on_blog_status_position'

    # For draft entries (admin drafts)
    # Covers: WHERE blog_id=? AND status='draft' ORDER BY created_at DESC
    add_index :entries, [:blog_id, :status, :created_at],
              order: { created_at: :desc },
              name: 'index_entries_on_blog_status_created'

    # For random query (no blog_id filter)
    # Covers: WHERE status='published' AND published_at >= ?
    add_index :entries, [:status, :published_at],
              name: 'index_entries_on_status_published_at'

    # For sitemaps (indexable_in_search_engines scope)
    # Covers: WHERE blog_id=? AND status='published' AND hide_from_search_engines=false
    add_index :entries, [:blog_id, :status, :hide_from_search_engines, :modified_at],
              name: 'index_entries_on_blog_status_indexable'

    # Remove redundant single-column indexes (now covered by composite indexes above)
    remove_index :entries, :blog_id, name: 'index_entries_on_blog_id'
    remove_index :entries, :status, name: 'index_entries_on_status'
  end
end
