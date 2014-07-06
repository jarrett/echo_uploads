module ApplicationHelper
  def error_on(obj, attr)
    if obj.errors.include? attr
      content_tag('span', :class => 'error-message') do
        obj.errors[attr].join('; ')
      end
    else
      nil
    end
  end
  
  def widget_thumbnail(widget)
    image_tag widget_thumbnail_url(widget, key: widget.thumbnail_key), alt: 'Thumbnail'
  end
end
