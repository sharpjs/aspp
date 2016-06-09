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

task :default => :test

task :test do
  ruby \
    '-e', 'ARGV.each { |f| require f }',
    '--', *Dir['./test/**/*_test.rb']
end

