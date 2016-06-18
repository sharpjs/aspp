# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name        = 'aex'
  s.version     = '0.0.0'
  s.license     = 'GPL-3.0'
  s.summary     = 'Assembly Extensions for Ruby'
  s.description = 'Æx is an experiment in which Ruby becomes a macro preprocessor for assembly language.'
  s.homepage    = 'https://github.com/sharpjs/aex'

  s.authors     = ['Jeff Sharp']
  s.email       = 'do.not.send@example.com'

  s.files       = `git ls-files | grep -v '^\.git'`.split("\n")
end

