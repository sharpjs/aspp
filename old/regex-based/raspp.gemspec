# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name        = 'raspp'
  s.version     = '0.0.0'
  s.license     = 'GPL-3.0'
  s.summary     = 'Assembly Preprocessor in Ruby'
  s.description = 'raspp is a minimal text preprocessor with the full power of the Ruby programming language.'
  s.homepage    = 'https://github.com/sharpjs/raspp'

  s.authors     = ['Jeff Sharp']
  s.email       = 'do.not.send@example.com'

  s.files       = `git ls-files | grep -v '^\.git'`.split("\n")
end

