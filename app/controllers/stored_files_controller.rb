class StoredFilesController < ApplicationController
  protect_from_forgery
  include ApplicationHelper

  access_control do
    allow logged_in, :to => [:create, :new]

    allow logged_in, :to => [:bulk_edit, :bulk_destroy]

    allow all, :to => [:thumbnail, :edit, :download, :show], :if => :allow_show?

    allow logged_in, :to => [:thumbnail, :show, :update, :edit, :download], :if => :allow_show?

    allow logged_in, :to => [:update], :if => :allow_show?

    allow logged_in, :to => [:destroy], :if => :allow_destroy?

    allow logged_in, :to => :download_set
  end

  def allow_destroy?
    StoredFile.find(params[:id]).can_user_destroy?(current_user)
  end

  def allow_show?
    if StoredFile.find(params[:id]).access_level_name == "open"
      return true
    elsif current_user.present?
      return current_user.can_view_cached?(params[:id])
    end
    false
  end

  def edit
    @licenses = License.all
    @stored_file = StoredFile.find(params[:id], :include => [:comments, :access_level, :groups, :flags])

    @attr_accessible = @stored_file.attr_accessible_for({}, current_user)
    @title = 'EDIT'

    respond_to do |format|
      format.html do
        render 'show_edit'
      end
      format.js
    end
  end

  def show
    @licenses = License.all
    @stored_file = StoredFile.find(params[:id], :include => [:comments, :access_level, :groups, :flags])

    @attr_accessible = []
    @title = 'DETAIL'

    render 'show_edit'
  end


  def destroy
    begin
      StoredFile.find(params[:id]).destroy
      respond_to do |format|
        format.js
        format.html do
          flash[:notice] = "deleted"
          redirect_to root_path
        end
      end
    rescue Exception => e
      log_exception e
      respond_to do |format|
        format.js do
          @message = e.to_s
          render 'destroy_fail'
        end
        format.html do
          flash[:error] = "Problem deleting file: #{e}"
          ::Rails.logger.warn "Warning: stored_files_controller.delete got exception: #{e}"
          @stored_file = StoredFile.find(params[:id])
          redirect_to edit_stored_file_path(@stored_file)
        end
      end
    end
  end

  def bulk_destroy
    stored_file_ids = params[:stored_file].keys 
    destroyed = 0
    if stored_file_ids.is_a?(Array) && stored_file_ids.length > 0
      stored_files = StoredFile.find(stored_file_ids)
      stored_files.each do |stored_file|
        if stored_file.can_user_destroy?(current_user)
          if stored_file.destroy
            destroyed += 1
          end
        end
      end      
    end
    if destroyed == stored_file_ids.size
      flash[:notice] = "All files deleted."
    else 
      flash[:notice] = "#{destroyed} file(s) deleted, you do not have access to delete all #{stored_file_ids.size} files."
    end
    redirect_to params[:previous_search]
  end

  def bulk_edit
    redirect_to new_bulk_edit_path(:stored_file_ids => params[:stored_file].keys)
  end 

  def update
    begin
      @stored_file = StoredFile.find(params[:id])

      @stored_file.custom_save(params[:stored_file], current_user)
        
      @stored_file.index
   
      respond_to do |format|
        format.js
        format.html do
          flash[:notice] = "File has been updated."
          redirect_to edit_stored_file_path(@stored_file)
        end
      end
    rescue Exception => e
      log_exception e
      respond_to do |format|
        format.js do
          @message = e.to_s
          render "update_fail"
        end
        format.html do
          flash[:error] = "File update failed: #{e}"
          redirect_to edit_stored_file_path(@stored_file)
        end
      end
    end
  end

  def new
    @licenses = License.all
    @stored_file = StoredFile.new

    @attr_accessible = @stored_file.attr_accessible_for({}, current_user)
    
    # Note: This is important, to be set after initialized because
    # accessible attributes are defined by attr_accessible_for, 
    # and access_level_id and user_id are not global attributes
    # TODO: Possibly clean up later, but low priority
    @stored_file.user = current_user
    @stored_file.access_level = AccessLevel.default
    @stored_file.license = Preference.default_license
    @max_web_upload_file_size = Preference.max_web_upload_filesize.try(:value)
    @max_web_upload_file_size ||= '100mb' #arbitrary default. (standard 'mb', 'kb', 'b' units required)

    init_new_batch
  end
 
  def create
    # TODO: I think this gets handled in the ApplicationController now. If so, remove this.
    if current_user.nil?
      render :json => {:success => false, :message => "It doesn't look like you're logged in."}
      return
    end

    is_web_upload = params.has_key?(:name) && params.has_key?(:file)
    is_sftp_only = params[:sftp_only] == '1'

    # Note: This is done because the custom_save handles accepted attributes
    params[:stored_file].merge!({ :user_id => current_user.id,
      :original_filename => params.delete(:name),
      :file => params.delete(:file)
    })

    stored_file = StoredFile.new

    exceptions = []
    if !is_sftp_only
      begin
        # custom_save gets its own exception handling because we might still
        # need to enqueue a RemoteFileImporter job after custom_save barfs
        stored_file.custom_save(params[:stored_file], current_user)
        #::Rails.logger.debug "PHUNK: Enqueueing PostProcessor for file_url: #{stored_file.file_url}"
        Resque.enqueue(PostProcessor, stored_file.id) if stored_file.id
      rescue Exception => e
        exceptions << e
      end          
    end

    begin
      sftp_user = SftpUser.find_by_username(params[:sftp_username]) if params[:sftp_username].present?
      force_batch = (is_sftp_only || needs_remote_file_import?(sftp_user))

      # If this is a web-upload, we can only update_batch _after_ custom_save() so
      # update_batch can see the stored_file.id. For is_sftp_only, stored_file.id
      # will of course be nil, which update_batch can handle just fine.
      batch_id = update_batch(params[:temp_batch_id], stored_file, force_batch)
      params[:stored_file][:batch_id] = batch_id if batch_id
      
      # TODO: Add some logging for an index failure here, or refactor our exception handling all together?
      # Do not bother trying to index if not valid? because it will not work.
      if !is_sftp_only && stored_file.valid?
        stored_file.index rescue ''
      end

      if needs_remote_file_import?(sftp_user)
        enqueue_remote_file_import(params, sftp_user.username)
      end
    rescue Exception => e
      exceptions << e
    end

    if exceptions.empty?
      render :json => {:success => true}
    else
      errors = exceptions.inject([]) {|array, e| array << e.to_s; array}
      render :json => {:success => false, :message => errors.join(', ')}
    end

  end

  def enqueue_remote_file_import(file_params, sftp_username)
    # Only enqueue job once for this temp_batch_id
    session[:remote_import_temp_batch_ids] ||= {}
    session[:remote_import_temp_batch_ids][file_params[:temp_batch_id]] = true

    # Remove un-needed and potentially un-serializable fields from file_params
    file_params[:stored_file].delete :original_filename
    file_params[:stored_file].delete :file
    Resque.enqueue(RemoteFileImporter, sftp_username, file_params[:stored_file])
    #RemoteFileImporter.perform(sftp_username, file_params[:stored_file])  #inline for Dev only
  end

  def thumbnail
    stored_file = StoredFile.find(params[:id])
    send_file stored_file.file_url(:thumbnail), :disposition => 'inline', :type => 'image/jpg', :x_sendfile => true
  end

  def download
    stored_file = StoredFile.find(params[:id])
    send_file stored_file.file_url, :x_sendfile => true, :filename => stored_file.original_filename
  end

  def download_set
    selected_stored_file_ids = params[:stored_file].collect { |k,v| k.to_i }
    stored_files = StoredFile.find(selected_stored_file_ids)

    set = DownloadSet.new(stored_files)
    send_file set.path, :x_sendfile => true

    File.delete(set.path) if File.file?(set.path)
  end


  private

  def needs_remote_file_import?(sftp_user)
    return @needs_remote_file_import = false if sftp_user.nil?

    if @needs_remote_file_import.nil? 
      @needs_remote_file_import = !( session[:remote_import_temp_batch_ids] &&
        session[:remote_import_temp_batch_ids][params[:temp_batch_id]] ) &&
        sftp_user.uploaded_files?
    end
    @needs_remote_file_import
  end

  def update_batch(temp_batch_id, stored_file, force_create)
    # Returns: batch.id if a batch was created/found. Returns nil if no batch created/found 
    # (in which case, stored_file.id does not need to be assigned to any batch.)
    # The force_create boolean will be true when there are also remote files
    # that are going into this batch.
    file_count = session[:upload_batches][temp_batch_id][:file_count]
    first_file_id = session[:upload_batches][temp_batch_id][:first_file_id]

    # Get batch from session
    if session[:upload_batches][temp_batch_id][:system_batch_id].present?
      batch = Batch.find(session[:upload_batches][temp_batch_id][:system_batch_id].to_i)
    elsif force_create || file_count == 1
      batch = Batch.new(:user_id => current_user.id)
      batch.save!
    end

    # Populate first_file_id. Harmless no-op if stored_file.id is nil.
    first_file_id ||= stored_file.try(:id)

    # If there was already a single stored_file in this temp batch, retroactively 
    # add it to this new batch instance. This is needed because we only create a
    # Batch instance once the second file gets uploaded for this temp_batch
    if file_count == 1 && first_file_id
      batch.stored_files << StoredFile.find_by_id(first_file_id.to_i)
    end

    # This is the 2nd or later file in this batch or force_create is true.
    if batch && (file_count > 0 || force_create)
      batch.stored_files << stored_file if stored_file.id
    end

    # Update this temp_batch entry in the session
    session[:upload_batches][temp_batch_id] = {
      :system_batch_id => batch.try(:id),
      :updated_at => Time.now.to_i,
      :file_count => file_count + 1,
      :first_file_id => first_file_id
    }

    return batch.try(:id)
  end

  def init_new_batch
    # A new @temp_batch_id is created for each view of stored_files#new. That
    # is how we group all web/sftp files uploaded from that single view, into
    # the same Batch instance.
    session[:upload_batches] ||= {}
    prune_temp_batches

    @temp_batch_id = Batch.new_temp_batch_id
    session[:upload_batches][@temp_batch_id] = {
      :system_batch_id => nil,
      :updated_at => Time.now.to_i,
      :file_count => 0,
      :first_file_id => nil
    }
  end

  def prune_temp_batches
    # Limit to "the oldest X batches" to avoid ActionDispatch::Cookies::CookieOverflow

    # batch_limit is an arbitrary number chosen as "the max number of open upload
    # sessions an absent minded professor is likely to have open at once."
    # Note: Could use ruby 1.9's ActiveSupport.OrderedHash here, but it is not critical
    batch_limit = 5
    return unless session[:upload_batches].try(:length) > batch_limit

    timestamps = session[:upload_batches].collect {|id, batch| batch[:updated_at] }
    timestamps.sort!.reverse!
    limit = timestamps[batch_limit - 1]

    # delete any batch that is older than our limit batch
    session[:upload_batches].delete_if {|id, batch| batch[:updated_at] < limit }
    # TODO: Remove same temp_batch_id's from session[:remote_import_temp_batch_ids][params[:temp_batch_id]]
    # as populated by
  end

end
