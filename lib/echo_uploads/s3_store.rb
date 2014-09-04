# Uses the official Amazon Web Services SDK gem:
#   gem install aws-sdk
module EchoUploads
  class S3Store < ::EchoUploads::AbstractStore    
    def delete(key)
      bucket.objects[path(key)].delete
    end
    
    def exists?(key)
      bucket.objects[path(key)].exists?
    end
    
    def read(key)
      data = ''
      bucket.objects[path(key)].read { |chunk| data << chunk }
      data
    end
    
    def url(key, options = {})
      options = {method: :read}.merge(options)
      bucket.objects[path(key)].url_for options.delete(:method), options
    end
    
    def write(key, file)
      file.rewind
      bucket.objects[path(key)].write file
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
      if Rails.configuration.respond_to?(:echo_uploads) and Rails.configuration.echo_uploads.s3.folder
        Rails.configuration.echo_uploads.s3.folder
      else
        ::File.join 'echo_uploads', Rails.env
      end
    end
    
    def path(key)
      ::File.join folder, key
    end
  end
end