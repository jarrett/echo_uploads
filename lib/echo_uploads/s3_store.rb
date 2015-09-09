# Uses the official Amazon Web Services SDK gem:
#   gem install aws-sdk
# Incompatible with 1.x.x versions of the aws-sdk gem.
module EchoUploads
  class S3Store < ::EchoUploads::AbstractStore    
    def delete(key)
      bucket.object(path(key)).delete
    end
    
    def exists?(key)
      bucket.object(path(key)).exists?
    end
    
    def read(key)
      bucket.object(path(key)).get.body.read
    end
    
    def url(key, options = {})
      options = {method: :get}.merge(options)
      url_str = bucket.object(path(key)).presigned_url options.delete(:method), options
      URI.parse url_str
    end
    
    def write(key, file)
      file.rewind
      bucket.object(path(key)).put body: file
    end
    
    private
    
    def aws_config
      Rails.configuration.echo_uploads.aws || {}
    end
    
    def bucket
      if @bucket.nil?
        bucket_name = Rails.configuration.echo_uploads.s3.bucket || raise(
          'You must define config.echo_uploads.s3.bucket in your application config.'
        )
        @bucket = Aws::S3::Bucket.new bucket_name, aws_config
        unless @bucket.exists?
          raise "S3 bucket does not exist: #{bucket_name.inspect}"
        end
      end
      @bucket
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