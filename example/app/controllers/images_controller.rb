class ImagesController < ApplicationController
  def create
    @image = Image.new image_params
    if @image.save
      redirect_to root_url, notice: 'Image created.'
    else
      render action: :edit
    end
  end
  
  def destroy
    Image.find(params[:id]).destroy
    redirect_to root_url, notice: 'Image deleted.'
  end
  
  def edit
    @image = Image.find params[:id]
  end
  
  def index
    @images = Image.order('id DESC')
  end
  
  def new
    @image = Image.new
    render action: :edit
  end
  
  def show
    # We find the Image by its ID. Alternatively, we could have had this method use
    # params[:key], which is the digest of the file. In that case, instead of calling a
    # finder on Image, we'd call a finder on EchoUploads::File. The behavior would be
    # the same for the most part--except when a user follows an old link to an image whose
    # contents have changed. 
    image = Image.find params[:id]
    send_file image.file_path, type: image.file_mime, disposition: 'inline', filename: image.file_original_filename
  end
  
  def update
    @image = Image.find params[:id]
    if @image.update_attributes image_params
      redirect_to root_url, notice: 'Image updated.'
    else
      render action: :edit
    end
  end
  
  private
  
  def image_params
    params.require(:image).permit(:file, :name, :echo_uploads_data)
  end
end