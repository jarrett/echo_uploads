# Uses the official Amazon Web Services SDK gem:
#   gem install aws-sdk
module EchoUploads
  class S3Store < ::EchoUploads::AbstractStore    
    def delete(key)
      bucket.objects[key].delete
    end
    
    def exists?(key)
      bucket.objects[key].exists?
    end
    
    def read(key)
      data = ''
      bucket.objects[key].read { |chunk| data << chunk }
      data
    end
    
    def url(key, options = {})
      options = {method: :read}.merge(options)
      bucket.objects[key].url_for options.delete(:method), options
    end
    
    def write(key, file)
      bucket.objects[key].write file
    end
    
    private
    
    def bucket
      if Rails.configuration.echo_uploads.aws
        s3 = AWS::S3.new Rails.configuration.echo_uploads.aws
      else
        s3 = AWS::S3.new
      end
      bucket_name = Rails.configuration.echo_uploads.s3.bucket || raise(
        'You must define config.echo_uploads.s3.bucket in your application config.'
      )
      if s3.buckets[bucket_name].nil?
        s3.buckets.create bucket_name
      end
      s3.buckets[bucket_name]
    end
    
    def folder
      Rails.configuration.echo_uploads.s3.folder || raise(
        'You must define config.echo_uploads.s3.folder in your application config.'
      )
    end
  end
end