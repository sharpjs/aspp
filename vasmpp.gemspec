# frozen_string_literal: true
#
# This file is part of vasmpp, a preprocessor for vasm
# Copyright (C) 2016 Jeffrey Sharp
#
# vasmpp is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published
# by the Free Software Foundation, either version 3 of the License,
# or (at your option) any later version.
#
# vasmpp is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See
# the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with vasmpp.  If not, see <http://www.gnu.org/licenses/>.
#

Gem::Specification.new do |s|
  s.name        = 'vasmpp'
  s.version     = '0.0.0'
  s.license     = 'GPL-3.0'
  s.summary     = 'A preprocessor for vasm'
  s.description = 'A minimal text preprocessor for the vasm assembler, ' \
                + 'with the full power of the Ruby programming language'
  s.homepage    = 'https://github.com/sharpjs/raspp'

  s.authors     = ['Jeff Sharp']
  s.email       = 'do.not.send@example.com'

  s.files       = `git ls-files | grep -v '^\.git'`.split("\n")
end

