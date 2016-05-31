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

require_relative 'refinements'
require_relative 'operand'
require_relative 'context'
require_relative 'section'

module Raspp
  using self

  class TopLevel < Context
    def initialize(out = nil)
      super(nil, nil, out)
    end

    def text; puts ".text"; end
    def data; puts ".data"; end
    def bss;  puts ".bss";  end

    def section(sym, &body)
      sec = Section.new(sym)
      sec.instance_exec(&body) if body
      sec.use
      sec
    end

    def addr(addr)
      dir :".offset", addr
    end

    # TODO: This is target-specific
    def func(sym, &body)
      klass = $frame_type || AppFunction
      klass.new(self, sym).define(&body)
      puts
    end

    def import(*files)
      # Get path of the importing file
      base = caller_locations(1, 1)[0].path

      # If it's a real file, import relative to it
      if File.file?(base)
        base = File.dirname(base)
        files.map! { |f| File.join(base, f) }
      end

      # Keep track of imported files
      @_imported ||= {}

      # Import files
      files.each do |rel|
        abs = File.absolute_path(rel)
        unless @_imported[abs]
          instance_eval IO.read(rel), rel
          @_imported[abs] = rel
        end
      end
    end
  end
end

