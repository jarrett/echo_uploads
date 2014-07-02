Gem::Specification.new do |s|
  s.name         = 'echo_uploads'
  s.version      = '0.0.0'
  s.date         = '2014-06-09'
  s.summary      = 'Uploaded files for Rails'
  s.description  = ''
  s.authors      = ['Jarrett Colby']
  s.email        = 'jarrett@madebyhq.com'
  s.files        = Dir.glob('lib/**/*')
  s.homepage     = 'https://github.com/jarrett/echo_uploads'
  s.license      = 'MIT'
  
  s.add_runtime_dependency 'mime-types'
  s.add_development_dependency 'turn', '~> 0'
end