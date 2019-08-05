class Admin::WebhooksController < AdminController

  def index
    @page = params[:page] || 1
    @webhooks = @photoblog.webhooks.page(@page).per(100)
    @page_title = 'Webhooks'
  end

  def new
    @webhook = Webhook.new
  end

  def create
    @webhook = Webhook.new(webhook_params)
    @webhook.blog = @photoblog
    respond_to do |format|
      if @webhook.save
        flash[:success] = "Webhook created!"
        format.html { redirect_to admin_webhooks_path }
      else
        flash[:warning] = 'The webhook couldn’t be created…'
        format.html { render :new }
      end
    end
  end

  def edit
    @webhook = Webhook.find(params[:id])
  end

  def update
    @webhook = Webhook.find(params[:id])
    respond_to do |format|
      if @webhook.update(webhook_params)
        format.html {
          flash[:success] = 'Your changes were saved!'
          redirect_to admin_webhooks_path
        }
      else
        format.html {
          flash[:warning] = 'Your changes couldn’t be saved…'
          render :edit
        }
      end
    end
  end

  def destroy
    webhook = Webhook.find(params[:id])
    webhook.destroy
    respond_to do |format|
      format.html { redirect_to admin_webhooks_path }
    end
  end

  private
  def webhook_params
    params.require(:webhook).permit(:url, :webhook_type)
  end
end
