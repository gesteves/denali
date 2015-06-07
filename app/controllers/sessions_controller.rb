class SessionsController < ApplicationController

  def new
    render layout: nil
  end

  def create
    auth_hash = request.env['omniauth.auth']
    email = auth_hash.try(:[], 'info').try(:[], 'email')

    if email =~ /@gesteves\.com$/
      flash[:notice] = "Welcome, #{auth_hash['info']['name']}."
      user = User.from_omniauth(env['omniauth.auth'])
      session[:user_id] = user.id
      redirect_to admin_entries_path
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
