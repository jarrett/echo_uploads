require File.expand_path(File.join(File.dirname(__FILE__), 'lib', 'echo_uploads', 'version'))

Gem::Specification.new do |s|
  s.name         = 'echo_uploads'
  s.version      = EchoUploads::VERSION
  s.date         = Time.now.strftime('%Y-%m-%d')
  s.summary      = 'Uploaded files for Rails'
  s.description  = "Gracefully handles invalid form submissions, so users don't have to resubmit the file. " +
                   "Supports transforming the file before saving, e.g. scaling an image. " +
                   "Compatible with any storage mechanism, including the local filesystem and the cloud."
  s.authors      = ['Jarrett Colby']
  s.email        = 'jarrett@madebyhq.com'
  s.files        = Dir.glob('lib/**/*')
  s.homepage     = 'https://github.com/jarrett/echo_uploads'
  s.license      = 'MIT'
  
  s.add_runtime_dependency 'mime-types', '~> 2'
end