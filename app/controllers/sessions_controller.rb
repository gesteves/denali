class SessionsController < ApplicationController
  skip_before_action :domain_redirect

  def new
    render
  end

  def create
    auth_hash = request.env['omniauth.auth']
    email = auth_hash.try(:[], 'info').try(:[], 'email')

    if email =~ /@gesteves\.com$/
      flash[:notice] = "Welcome, #{auth_hash['info']['name']}!"
      user = User.from_omniauth(env['omniauth.auth'])
      session[:user_id] = user.id
      url = session[:original_url] || admin_entries_path
      session[:original_url] = nil
      redirect_to url
    else
      redirect_to signin_path, alert: 'There was a problem logging you in.'
    end
  end

  def failure
    redirect_to signin_path, alert: "There was a problem logging you in: #{params[:message]}."
  end

  def destroy
    session[:current_user] = nil
    redirect_to signin_path, notice: 'You have been logged out.'
  end
end
