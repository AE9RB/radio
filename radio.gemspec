Gem::Specification.new do |s|
  s.name        = 'radio'
  s.version     = '0.0.1'
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['David Turnbull']
  s.email       = ['dturnbull@gmail.com']
  s.homepage    = 'https://github.com/dturnbull/radio'
  s.summary     = 'Amateur radio software'

  dirs = %w(lib)
  s.require_path = 'lib'
  s.files        = Dir.glob("{#{dirs.join ','}}/**/*")
  s.files       += %w(README.md)
  s.files       += Dir.glob('scripts/*')
end
