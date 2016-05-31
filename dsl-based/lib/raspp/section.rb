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
require_relative 'context'

module Raspp
  using self

  class Section < BasicObject
    # TODO: Needs to use context _out_stream
    def initialize(name)
      @name = name.to_sym
    end

    def use
      k = ::Kernel
      k.print %Q[.section #{@name}]
      k.print %Q[, "#{@flags}"] if @type || @flags
      k.print %Q[, #{@type}]    if @type
      k.puts
    end

    protected
    def allocate ; flag 'a'         ; end
    def write    ; flag 'w'         ; end
    def execute  ; flag 'x'         ; end
    def content  ; type '@progbits' ; end
    def empty    ; type '@nobits'   ; end
    def notes    ; type '@note'     ; end

    private
    def flag(f) (@flags ||= '') << f ; self end
    def type(t)  @type           = t ; self end
  end
end

