class Admin::BaseController < ApplicationController
  include ApplicationHelper

  access_control do
    allow logged_in, :to => [:index, :edit, :show, :destroy, :update, :create], :if => :can_view_admin?
  end

  def index
    @preferences = Preference.order('name')
  end

  def update
    params[:preference].each do |k, v|
      Preference.find(k).update_attribute(:value, v)
    end
    flash[:notice] = "Updated!"
    redirect_to "/admin"
  end
end
