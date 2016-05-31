#
# Raspp - Assembly Extensions for Ruby
#
# This file is part of Raspp.
# Copyright (C) 2016 Jeffrey Sharp
#
# Raspp is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published
# by the Free Software Foundation, either version 3 of the License,
# or (at your option) any later version.
#
# Raspp is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See
# the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Raspp.  If not, see <http://www.gnu.org/licenses/>.
#

require 'optparse'

module Raspp
  def self.parse_options(args)
    {
      cpu: 'mcf5307'
    }
    .tap do |opts|
      OptionParser.new do |p|
        p.banner = "usage: raspp [options] [file ...]"

        p.on("-c", "--cpu CPU", "Set the target CPU. (default: #{opts[:cpu]})") do |cpu|
          opts[:cpu] = cpu
        end

        p.on("-D", "--define NAME[=value]", "Define a constant.") do |d|
          name, value = d.split('=', 2)
          Context.const_set name, value ? Kernel::eval(value) : true
        end

        p.on("-h", "--help", "Print this help message.") do
          puts p
          exit
        end
      end.parse!(args)
    end
  end
end

