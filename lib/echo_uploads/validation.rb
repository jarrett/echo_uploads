# If you want to validate the presence of a file, be sure to use:
#   validates :attr, uploads: {presence: true}
# instead of:
#   validates :attr, presence: true
# The former takes into account files that have already been persisted, whereas the
# latter does not and will cause false validation errors.

module EchoUploads
  module Validation
    class UploadValidator < ActiveModel::EachValidator
      def validate_each(record, attr, val)
        # Presence validation
        if options[:presence]
          unless record.send("has_#{attr}?")
            record.errors[attr] << (
              options[:message] ||
              'must be uploaded'
            )
          end
        end
        
        # File size validation
        if options[:max_size]
          unless options[:max_size].is_a? Numeric
            raise(ArgumentError,
              "validates :#{attr}, :upload called with invalid :max_size option. " +
              ":max_size must be a number, e.g. 1.megabyte"
            )
          end
          
          if val.present?
            unless val.respond_to?(:size)
              raise ArgumentError, "Expected ##{attr} to respond to #size"
            end
            
            if val.size > options[:max_size]
              record.errors[attr] << (
                options[:message] ||
                "must be smaller than #{options[:max_size].to_i} bytes"
              )
            end
          end
        end
        
        # Extension validation
        if options[:extension]
          unless options[:extension].is_a? Array
            raise(ArgumentError,
              "validates :#{attr}, :upload called with invalid :extension option. " +
              ":extension must be an array of extensions like ['.jpg', '.png']"
            )
          end
    
          if val.present?
            unless val.respond_to?(:original_filename)
              raise ArgumentError, "Expected ##{attr} to respond to #original_filename"
            end
      
            ext = ::File.extname(val.original_filename).downcase
            unless options[:extension].include?(ext.downcase)
              record.errors[attr] << (
                options[:message] ||
                "must have one of the following extensions: #{options[:extension].join(',')}"
              )
            end
          end
        end
      end
    end
  end
end

# If you pass in the presence: true option, this validator will assume you're using the
# CachedUploads module. It will look at the has_cached_upload config for the given
# attribute and check if a) the upload is present, b) the temporary MD5 hash is present,
# or c) the record has already been saved.
class UploadValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    if options[:presence]
      config = record.class.cached_uploads[attribute.to_sym]
      if record.new_record? and value.blank? and record.send(config[:md5_attr]).blank?
        record.errors[attribute] << (options[:message] || "can't be blank")
      end
    end
    if value.present? and value.size > options[:max_size]
      record.errors[attribute] << (options[:message] || "is too large (max is #{options[:max_size]} bytes)")
    end
  end
end