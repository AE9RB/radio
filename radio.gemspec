Gem::Specification.new do |s|
  s.name        = 'radio'
  s.version     = '0.0.1'
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['David Turnbull']
  s.email       = ['dturnbull@gmail.com']
  s.homepage    = 'https://github.com/ham21/radio'
  s.summary     = 'The Twenty-First Century Amateur Radio Project'

  s.add_dependency 'rack'
  s.add_dependency 'thin'
  s.add_dependency 'eventmachine'

  dirs = %w(bin lib)
  s.require_path = 'lib'
  s.files        = Dir.glob("{#{dirs.join ','}}/**/*")
  s.files       += %w(README.md)
  s.executables  = ['radio-server']
end
