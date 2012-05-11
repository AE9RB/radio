# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require 'radio/version'

Gem::Specification.new do |s|
  s.name        = 'radio'
  s.version     = Radio::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['David Turnbull']
  s.email       = ['dturnbull@gmail.com']
  s.homepage    = 'https://github.com/ham21/radio'
  s.summary     = 'The Twenty-First Century Amateur Radio Project'
  # s.description = ''

  s.add_dependency 'fftw3'
  s.add_dependency 'thin'
  s.add_dependency 'libusb'
  s.add_dependency 'serialport'
  # s.add_development_dependency 'minitest'

  dirs = %w(bin lib www)
  s.files        = Dir.glob("{#{dirs.join ','}}/**/*")
  s.files       += %w(README.md LICENSE)
  # s.test_files    = Dir.glob('test/**/*')
  s.require_path = 'lib'
  s.executables  = ['radio-server']
end
