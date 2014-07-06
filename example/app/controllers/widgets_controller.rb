class WidgetsController < ApplicationController
  def create
    @widget = Widget.new widget_params
    if @widget.save
      redirect_to root_url, notice: 'Widget created.'
    else
      render action: :edit
    end
  end
  
  def destroy
    Widget.find(params[:id]).destroy
    redirect_to root_url, notice: 'Widget deleted.'
  end
  
  def edit
    @widget = Widget.find params[:id]
  end
  
  def index
    @widgets = Widget.order('id DESC')
  end
  
  def new
    @widget = Widget.new
    render action: :edit
  end
  
  def manual
    # We find the Widget by its ID. Alternatively, we could have had this method use
    # params[:key], which is the digest of the file. In that case, instead of calling a
    # finder on Widget, we'd call a finder on EchoUploads::File. The behavior would be
    # the same for the most part--except when a user follows an old link to an widget whose
    # contents have changed. 
    widget = Widget.find params[:id]
    send_file widget.manual_path, type: widget.manual_mime, disposition: 'inline', filename: widget.manual_original_filename
  end
  
  def thumbnail
    # See comment in #manual action.
    widget = Widget.find params[:id]
    send_file widget.thumbnail_path, type: widget.thumbnail_mime, disposition: 'inline', filename: widget.thumbnail_original_filename
  end
  
  def update
    @widget = Widget.find params[:id]
    if @widget.update_attributes widget_params
      redirect_to root_url, notice: 'Widget updated.'
    else
      render action: :edit
    end
  end
  
  private
  
  def widget_params
    params.require(:widget).permit(:manual, :thumbnail, :name, :echo_uploads_data)
  end
end