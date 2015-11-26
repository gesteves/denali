class PagesController < ApplicationController
  before_action :set_max_age, only: [:about]
  before_action :check_if_user_has_visited, only: [:about]
  
  def about
  end
end
