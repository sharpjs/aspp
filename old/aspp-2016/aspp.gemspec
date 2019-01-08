# frozen_string_literal: true
#
# This file is part of aspp, a preprocessor for GNU as
# Copyright (C) 2016 Jeffrey Sharp
#
# aspp is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published
# by the Free Software Foundation, either version 3 of the License,
# or (at your option) any later version.
#
# aspp is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See
# the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with aspp.  If not, see <http://www.gnu.org/licenses/>.
#

Gem::Specification.new do |s|
  s.name        = 'aspp'
  s.version     = '0.0.0'
  s.license     = 'GPL-3.0'
  s.summary     = 'Preprocessor for GNU as'
  s.description = 'Minimal text preprocessor for as, the GNU assembler'
  s.homepage    = 'https://github.com/sharpjs/aspp'

  s.authors     = ['Jeff Sharp']
  s.email       = 'no-email@example.com'

  s.files       = ['lib/aspp.rb', 'LICENSE', 'README.md']
end

