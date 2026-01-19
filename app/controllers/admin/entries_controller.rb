class Admin::EntriesController < AdminController
  include TagList

  before_action :set_entry, only: [:show, :edit, :update, :destroy, :publish, :queue, :draft, :crops, :prints, :refresh_metadata, :generate_alt_text, :share]
  before_action :get_tags, only: [:new, :edit, :create, :update]
  before_action :load_tags, only: [:tagged]
  before_action :set_redirect_url, if: -> { request.get? }, except: [:photo]

  # GET /admin/entries
  def index
    set_srcset
    @page = params[:page] || 1
    @entries = @photoblog.entries.includes(:blog, photos: [:image_attachment, :image_blob], taggings: :tag).published.page(@page)
    @page_title = 'Published'
    respond_to do |format|
      format.html
    end
  end

  # GET /admin/entries/queued
  def queued
    set_srcset
    @page = params[:page] || 1
    @count = ([@photoblog.publish_schedules_count.presence || 0, 1].max) * 7
    @entries = @photoblog.entries.includes(:blog, blog: :publish_schedules, photos: [:image_attachment, :image_blob], taggings: :tag).queued.page(@page).per(@count)
    @page_title = 'Queued'
    respond_to do |format|
      format.html
    end
  end

  # GET /admin/entries/drafts
  def drafts
    set_srcset
    @page = params[:page] || 1
    @entries = @photoblog.entries.includes(:blog, photos: [:image_attachment, :image_blob], taggings: :tag).drafted.page(@page)
    @page_title = 'Drafts'
    respond_to do |format|
      format.html
    end
  end

  # GET /admin/entries/tagged/film
  def tagged
    set_srcset
    @page = params[:page] || 1
    entries = @photoblog.entries.includes(photos: [:image_attachment, :image_blob], taggings: :tag).tagged_with(@tag_list, any: true).order('entries.created_at DESC')
    @entries = entries.page(@page)
    @page_title = "Entries tagged \"#{@tag_list.first}\""
    @tagged_count = entries.size
    raise ActiveRecord::RecordNotFound if @tags.empty? || @entries.empty?
    respond_to do |format|
      format.html
    end
  end

  def review_alt_text
    set_srcset
    @page = params[:page] || 1
    entries = @photoblog.entries.includes(photos: [:image_attachment, :image_blob])
      .joins(:photos)
      .merge(Photo.needs_alt_text_review)
      .distinct
      .order('entries.created_at DESC')
    @entries_count = entries.reorder(nil).pluck(:id).count
    @entries = entries.page(@page)
    @page_title = 'Alt text review'
    respond_to do |format|
      format.html
    end
  end

  def shareable_on_bluesky
    set_srcset
    @page = params[:page] || 1
    @entries = @photoblog.entries.published
      .shareable_on_bluesky
      .with_minimum_bluesky_shares
      .by_bluesky_share_priority
      .includes(:blog, photos: [:image_attachment, :image_blob], taggings: :tag)
      .page(@page)
    @page_title = 'Shareable on Bluesky'
    respond_to do |format|
      format.html
    end
  end

  def shareable_on_mastodon
    set_srcset
    @page = params[:page] || 1
    @entries = @photoblog.entries.published
      .shareable_on_mastodon
      .with_minimum_mastodon_shares
      .by_mastodon_share_priority
      .includes(:blog, photos: [:image_attachment, :image_blob], taggings: :tag)
      .page(@page)
    @page_title = 'Shareable on Mastodon'
    respond_to do |format|
      format.html
    end
  end

  def shareable_on_threads
    set_srcset
    @page = params[:page] || 1
    @entries = @photoblog.entries.published
      .shareable_on_threads
      .with_minimum_threads_shares
      .by_threads_share_priority
      .includes(:blog, photos: [:image_attachment, :image_blob], taggings: :tag)
      .page(@page)
    @page_title = 'Shareable on Threads'
    respond_to do |format|
      format.html
    end
  end

  def shareable_on_instagram
    set_srcset
    @page = params[:page] || 1
    @entries = @photoblog.entries.published
      .shareable_on_instagram
      .with_minimum_instagram_shares
      .by_instagram_share_priority
      .includes(:blog, photos: [:image_attachment, :image_blob], taggings: :tag)
      .page(@page)
    @page_title = 'Shareable on Instagram'
    respond_to do |format|
      format.html
    end
  end

  def unshareable
    set_srcset
    @page = params[:page] || 1
    base_query = @photoblog.entries.published
      .where(post_to_bluesky: false)
      .where(post_to_mastodon: false)
      .where(post_to_threads: false)
      .where(post_to_instagram: false)
      .order(published_at: :desc)
    @entries = base_query.includes(:blog, photos: [:image_attachment, :image_blob], taggings: :tag).page(@page)
    @page_title = 'Unshareable'
    respond_to do |format|
      format.html
    end
  end

  # GET /admin/entries/:id
  def show
    set_srcset
    @page_title = @entry.plain_title
    respond_to do |format|
      format.html
    end
  end

  # GET /admin/entries/new
  def new
    @entry = @photoblog.entries.new
    @entry.status = 'queued'
    @entry.photos.build
    @page_title = 'New entry'

    if ActiveModel::Type::Boolean.new.cast(params[:continue].presence)
      previous_entry = @photoblog.entries.order('created_at DESC').first
      @entry.title = previous_entry.title
      @entry.slug = previous_entry.slug
      @entry.tag_list = previous_entry.tag_list
    end
  end

  def search
    raise ActionController::RoutingError.new('Not Found') unless @photoblog.has_search?
    set_srcset
    @page = (params[:page] || 1).to_i
    @count = 10
    @query = params[:q]
    @page_title = "Search"

    if @query.present?
      @page_title = "Search results for \"#{@query}\""

      results = Entry.full_search(@query, @page, @count)

      @total_count = results.results.total
      # Preserve Elasticsearch score order by fetching IDs first, then reordering
      hit_ids = results.response.hits.hits.map { |h| h._id.to_i }
      records_by_id = Entry.includes(photos: [:image_attachment, :image_blob], taggings: :tag).where(id: hit_ids).index_by(&:id)
      ordered_records = hit_ids.map { |id| records_by_id[id] }.compact
      @entries = Kaminari.paginate_array(ordered_records, total_count: @total_count).page(@page).per(@count)
    end

    respond_to do |format|
      format.html
    end
  end

  # GET /admin/entries/1/edit
  def edit
    @page_title = "Editing “#{@entry.title}”"
    @srcset = PHOTOS[:admin_edit][:srcset]
    @sizes = PHOTOS[:admin_edit][:sizes].join(', ')
  end

  # PATCH /admin/entries/1/publish
  def publish
    if @entry.publish
      flash[:success] = 'Your entry was published!'
    else
      flash[:warning] = 'Your entry couldn’t be published…'
    end
    redirect_to admin_entries_path
  end

  # PATCH /admin/entries/1/queue
  def queue
    if @entry.queue
      flash[:success] = 'Your entry was sent to the queue.'
    else
      flash[:warning] = 'Your entry couldn’t be queued…'
    end
    redirect_to queued_admin_entries_path
  end

  # PATCH /admin/entries/1/draft
  def draft
    if @entry.draft
      flash[:success] = 'Your entry was moved to the drafts.'
    else
      flash[:warning] = 'Your entry couldn’t be moved to the drafts…'
    end
    redirect_to drafts_admin_entries_path
  end

  # POST /admin/entries
  def create
    @entry = Entry.new(entry_params)
    @entry.user = current_user
    @entry.blog = @photoblog
    respond_to do |format|
      if @entry.save
        @entry.update_tags
        flash[:success] = "Your entry was saved!"
        format.html { redirect_to new_admin_entry_path(continue: true) }
      else
        flash[:warning] = 'Your entry couldn’t be saved…'
        format.html { render :new }
      end
    end
  end

  # PATCH/PUT /admin/entries/1
  def update
    respond_to do |format|
      @entry.modified_at = Time.current if @entry.is_published?
      if @entry.update(entry_params)
        @entry.update_tags
        @entry.photos.each do |photo|
          photo.extract_metadata
          photo.detect_colors
          photo.encode_blurhash
        end
        @photoblog.purge_from_cdn
        OpenGraphWorker.perform_in(1.minute, @entry.id) if @entry.is_published?
        flash[:success] = 'Your entry has been updated!'
        format.html { redirect_to admin_entry_path(@entry) }
      else
        flash[:warning] = 'Your entry couldn’t be updated…'
        format.html { render :edit }
      end
    end
  end

  # DELETE /admin/entries/1
  def destroy
    @photoblog.purge_from_cdn
    @entry.destroy
    respond_to do |format|
      flash[:danger] = 'Your entry was deleted forever.'
      format.html { redirect_to session[:redirect_url] || admin_entries_path }
    end
  end

  def organize_queue
    @srcset = PHOTOS[:admin_queue][:srcset]
    @sizes = PHOTOS[:admin_queue][:sizes].join(', ')
    @entries = @photoblog.entries.includes(photos: [:image_attachment, :image_blob]).queued
    @page_title = 'Organize queue'
    respond_to do |format|
      format.html
    end
  end

  def update_queue
    entry_ids = params[:entry_ids].map(&:to_i)
    entries = Entry.where(id: entry_ids)
    position = 1
    entry_ids.each do |id|
      entry = entries.find { |e| e.id == id }
      if entry.is_queued?
        entry.position = position
        entry.save
        position += 1
      end
    end
    respond_to do |format|
      format.json {
        response = {
          status: 'success',
          message: 'The changes you’ve made to the queue have been saved!'
        }
        render json: response
      }
    end
  end

  def photo
    @entry = Entry.new
    @count = params[:count] || 1
    @entry.photos.build
    request.format = 'html'
    respond_to do |format|
      format.html { render layout: nil }
    end
  end

  def crops
    @page_title = "Crops for “#{@entry.title}”"
    respond_to do |format|
      format.html {
        render
      }
    end
  end

  def prints
    set_srcset
    @page_title = "Print options for "#{@entry.title}""
    @color_print_sizes = YAML.load_file(Rails.root.join('config/prints.yml'))['color']
    @bw_print_sizes = YAML.load_file(Rails.root.join('config/prints.yml'))['blackandwhite']
    respond_to do |format|
      format.html {
        render
      }
    end
  end

  def share
    raise ActiveRecord::RecordNotFound unless @entry.is_photo?
    set_srcset
    @page_title = "Share “#{@entry.title}”"
    @bluesky_text = @entry.bluesky_caption(utm_campaign: 'share')
    @mastodon_text = @entry.mastodon_caption(utm_campaign: 'share')
    @threads_text = @entry.threads_caption(utm_campaign: 'share')
    @instagram_text = @entry.instagram_caption
    respond_to do |format|
      format.html
    end
  end

  def instagram
    @entry = @photoblog.entries.published.find(params[:id])
    raise ActiveRecord::RecordNotFound unless @entry.is_photo?
    if request.get?
      @text = @entry.instagram_caption
      respond_to do |format|
        format.html {
          if params[:modal]
            render layout: nil
          else
            render
          end
        }
      end
    elsif request.post?
      scheduled_at = params[:scheduled_at].present? ? ActiveSupport::TimeZone[@photoblog.time_zone].parse(params[:scheduled_at]) : nil
      scheduled = scheduled_at.present? && scheduled_at > Time.current

      if scheduled
        InstagramWorker.perform_at(scheduled_at, @entry.id, params[:text])
        @message = "Your entry will be shared on Instagram at #{scheduled_at.strftime('%B %-d, %Y at %-l:%M %p')}."
      else
        InstagramWorker.perform_inline(@entry.id, params[:text])
        @entry.reload
        @message = 'Your entry was shared on Instagram.'
      end

      respond_to do |format|
        format.html {
          flash[:success] = @message
          redirect_to session[:redirect_url] || admin_entry_path(@entry)
        }
        format.js { render 'admin/shared/notify' }
        format.json {
          render json: {
            status: 'success',
            message: @message,
            shares_count: @entry.instagram_shares_count,
            last_shared_at: @entry.last_shared_on_instagram_at&.strftime('%B %-d, %Y at %-l:%M %p'),
            scheduled: scheduled
          }
        }
      end
    end
  end

  def instagram_story
    @entry = @photoblog.entries.find(params[:id])
    raise ActiveRecord::RecordNotFound unless @entry.is_photo?
    if request.get?
      respond_to do |format|
        format.html {
          if params[:modal]
            render layout: nil
          else
            render
          end
        }
      end
    elsif request.post?
      crop = params[:crop] == 'true'
      scheduled_at = params[:scheduled_at].present? ? ActiveSupport::TimeZone[@photoblog.time_zone].parse(params[:scheduled_at]) : nil
      scheduled = scheduled_at.present? && scheduled_at > Time.current

      if scheduled
        InstagramStoryWorker.perform_at(scheduled_at, @entry.id, crop)
        @message = "Your entry will be shared on your Instagram Story at #{scheduled_at.strftime('%B %-d, %Y at %-l:%M %p')}."
      else
        InstagramStoryWorker.perform_inline(@entry.id, crop)
        @message = 'Your entry was shared on your Instagram Story.'
      end

      respond_to do |format|
        format.html {
          flash[:success] = @message
          redirect_to session[:redirect_url] || admin_entry_path(@entry)
        }
        format.js { render 'admin/shared/notify' }
        format.json {
          render json: {
            status: 'success',
            message: @message,
            scheduled: scheduled
          }
        }
      end
    end
  end

  def threads
    @entry = @photoblog.entries.published.find(params[:id])
    raise ActiveRecord::RecordNotFound unless @entry.is_photo?
    if request.get?
      @text = @entry.threads_caption(utm_campaign: 'share')
      respond_to do |format|
        format.html {
          if params[:modal]
            render layout: nil
          else
            render
          end
        }
      end
    elsif request.post?
      scheduled_at = params[:scheduled_at].present? ? ActiveSupport::TimeZone[@photoblog.time_zone].parse(params[:scheduled_at]) : nil
      scheduled = scheduled_at.present? && scheduled_at > Time.current

      if scheduled
        ThreadsWorker.perform_at(scheduled_at, @entry.id, params[:text])
        @message = "Your entry will be shared on Threads at #{scheduled_at.strftime('%B %-d, %Y at %-l:%M %p')}."
      else
        ThreadsWorker.perform_inline(@entry.id, params[:text])
        @entry.reload
        @message = 'Your entry was shared on Threads.'
      end

      respond_to do |format|
        format.html {
          flash[:success] = @message
          redirect_to session[:redirect_url] || admin_entry_path(@entry)
        }
        format.js { render 'admin/shared/notify' }
        format.json {
          render json: {
            status: 'success',
            message: @message,
            shares_count: @entry.threads_shares_count,
            last_shared_at: @entry.last_shared_on_threads_at&.strftime('%B %-d, %Y at %-l:%M %p'),
            scheduled: scheduled
          }
        }
      end
    end
  end

  def mastodon
    @entry = @photoblog.entries.published.find(params[:id])
    raise ActiveRecord::RecordNotFound unless @entry.is_photo?
    if request.get?
      @text = @entry.mastodon_caption(utm_campaign: 'share')
      respond_to do |format|
        format.html {
          if params[:modal]
            render layout: nil
          else
            render
          end
        }
      end
    elsif request.post?
      scheduled_at = params[:scheduled_at].present? ? ActiveSupport::TimeZone[@photoblog.time_zone].parse(params[:scheduled_at]) : nil
      scheduled = scheduled_at.present? && scheduled_at > Time.current

      if scheduled
        MastodonWorker.perform_at(scheduled_at, @entry.id, params[:text])
        @message = "Your entry will be shared on Mastodon at #{scheduled_at.strftime('%B %-d, %Y at %-l:%M %p')}."
      else
        MastodonWorker.perform_inline(@entry.id, params[:text])
        @entry.reload
        @message = 'Your entry was shared on Mastodon.'
      end

      respond_to do |format|
        format.html {
          flash[:success] = @message
          redirect_to session[:redirect_url] || admin_entry_path(@entry)
        }
        format.js { render 'admin/shared/notify' }
        format.json {
          render json: {
            status: 'success',
            message: @message,
            shares_count: @entry.mastodon_shares_count,
            last_shared_at: @entry.last_shared_on_mastodon_at&.strftime('%B %-d, %Y at %-l:%M %p'),
            scheduled: scheduled
          }
        }
      end
    end
  end

  def bluesky
    @entry = @photoblog.entries.published.find(params[:id])
    raise ActiveRecord::RecordNotFound unless @entry.is_photo?
    if request.get?
      @text = @entry.bluesky_caption(utm_campaign: 'share')
      respond_to do |format|
        format.html {
          if params[:modal]
            render layout: nil
          else
            render
          end
        }
      end
    elsif request.post?
      scheduled_at = params[:scheduled_at].present? ? ActiveSupport::TimeZone[@photoblog.time_zone].parse(params[:scheduled_at]) : nil
      scheduled = scheduled_at.present? && scheduled_at > Time.current

      if scheduled
        BlueskyWorker.perform_at(scheduled_at, @entry.id, params[:text], params[:in_reply_to], params[:quote])
        @message = "Your entry will be shared on Bluesky at #{scheduled_at.strftime('%B %-d, %Y at %-l:%M %p')}."
      else
        BlueskyWorker.perform_inline(@entry.id, params[:text], params[:in_reply_to], params[:quote])
        @entry.reload
        @message = 'Your entry was shared on Bluesky.'
      end

      respond_to do |format|
        format.html {
          flash[:success] = @message
          redirect_to session[:redirect_url] || admin_entry_path(@entry)
        }
        format.js { render 'admin/shared/notify' }
        format.json {
          render json: {
            status: 'success',
            message: @message,
            shares_count: @entry.bluesky_shares_count,
            last_shared_at: @entry.last_shared_on_bluesky_at&.strftime('%B %-d, %Y at %-l:%M %p'),
            scheduled: scheduled
          }
        }
      end
    end
  end

  def sharing_settings
    @entry = @photoblog.entries.find(params[:id])
    if request.get?
      respond_to do |format|
        format.html {
          if params[:modal]
            render layout: nil
          else
            render
          end
        }
      end
    elsif request.post?
      if @entry.update(sharing_settings_params)
        @message = 'Sharing settings have been updated.'
        respond_to do |format|
          format.html {
            flash[:success] = @message
            redirect_to session[:redirect_url] || admin_entry_path(@entry)
          }
          format.js { render 'admin/shared/notify' }
          format.json {
            render json: {
              status: 'success',
              message: @message,
              settings: {
                post_to_bluesky: @entry.post_to_bluesky,
                post_to_mastodon: @entry.post_to_mastodon,
                post_to_instagram: @entry.post_to_instagram,
                post_to_threads: @entry.post_to_threads
              }
            }
          }
        end
      else
        @message = 'Sharing settings could not be updated.'
        respond_to do |format|
          format.html {
            flash[:warning] = @message
            redirect_to session[:redirect_url] || admin_entry_path(@entry)
          }
          format.js { render 'admin/shared/notify' }
          format.json {
            render json: {
              status: 'danger',
              message: @message
            }
          }
        end
      end
    end
  end

  def refresh_metadata
    @entry.update_tags
    @entry.photos.each do |photo|
      photo.extract_metadata
      photo.detect_colors
      photo.encode_blurhash
    end
    @message = 'Your entry’s metadata is being updated. This may take a few moments.'
    respond_to do |format|
      format.html {
        flash[:success] = @message
        redirect_to session[:redirect_url] || admin_entry_path(@entry)
      }
      format.js { render 'admin/shared/notify' }
    end
  end

  def generate_alt_text
    @entry.photos.each do |photo|
      photo.generate_alt_text
    end
    @message = 'The alt text is being generated. This may take a few moments.'
    respond_to do |format|
      format.html {
        flash[:success] = @message
        redirect_to session[:redirect_url] || admin_entry_path(@entry)
      }
      format.js { render 'admin/shared/notify' }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_entry
      @entry = @photoblog.entries.find(params[:id])
    end

    def get_tags
      @tags = ActsAsTaggableOn::Tag.order('taggings_count desc')
    end

    def entry_params
      params.require(:entry).permit(:title, :body, :slug, :status, :tag_list, :post_to_flickr, :post_to_instagram, :post_to_flickr_groups, :post_to_mastodon, :post_to_bluesky, :post_to_threads, :instagram_text, :threads_text, :bluesky_text, :mastodon_text, :show_location, :hide_from_search_engines, :content_warning, :is_sensitive, photos_attributes: [:image, :id, :_destroy, :position, :alt_text, :focal_x, :focal_y, :location, :park_id, :auto_generated_alt_text])
    end

    def sharing_settings_params
      params.require(:entry).permit(:post_to_bluesky, :post_to_mastodon, :post_to_instagram, :post_to_threads)
    end

    def set_redirect_url
      session[:redirect_url] = request.referer
    end

    def set_srcset
      @srcset = PHOTOS[:admin_entry][:srcset]
      @sizes = PHOTOS[:admin_entry][:sizes].join(', ')
    end
end
