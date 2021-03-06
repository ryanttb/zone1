class Admin::RightsController < Admin::BaseController
  add_breadcrumb "admin: rights", :admin_rights_path
  def index
    @rights = Right.all
    @right = Right.new
  end

  def create
    begin
      right = Right.new(params[:right])
      if right.save
        flash[:notice] = "created!"
        redirect_to edit_admin_right_path(right)
      else
        flash[:notice] = "Errors #{right.errors.full_messages.join(', ')}"
        redirect_to admin_rights_path
      end
    rescue Exception => e
      flash[:error] = "Problems creating! Please try again."
      log_exception e
      redirect_to admin_rights_path
    end
  end

  def show
    redirect_to edit_admin_right_path(params[:id])
  end

  def update
    begin
      right = Right.find(params[:id])
      right.update_attributes(params[:right])
      flash[:notice] = "updated!"
      redirect_to edit_admin_right_path(right)
    rescue Exception => e
      flash[:error] = "Problems updating: #{e}"
      log_exception e
      redirect_to edit_admin_right_path(right)
    end
  end

  def edit
    @roles = Role.all
    @right = Right.find(params[:id])
    add_breadcrumb "edit #{@right.action}", edit_admin_right_path(params[:id])
  end

  def destroy
    Right.destroy(params[:id])
    flash[:notice] = "Deleted right."
    redirect_to admin_rights_path
  end
end
