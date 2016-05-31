#!/usr/bin/env ruby
#
# AEx - Assembly Extensions for Ruby
#
# This file is part of AEx.
# Copyright (C) 2015 Jeffrey Sharp
#
# AEx is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published
# by the Free Software Foundation, either version 3 of the License,
# or (at your option) any later version.
#
# AEx is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See
# the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with AEx.  If not, see <http://www.gnu.org/licenses/>.
#

require_relative "aex/top_level"

if __FILE__ == $0
  # Running as a script
  require_relative 'aex/options'
  AEX_OPTS = Aex::parse_options(ARGV).freeze
  require_relative "aex/targets/#{AEX_OPTS[:cpu]}"
  using Aex

  loop do
    Aex::TopLevel.new.instance_eval(ARGF.file.read, ARGF.filename)
    ARGF.skip
    break if ARGV.empty?
  end
end

