class PagesController < ApplicationController
  before_action :set_max_age, only: [:about]

  def about
  end
end
