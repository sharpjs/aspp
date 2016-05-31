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

module Raspp
  using self

  class BitField
    attr :bits, :mask, :scale, :options

    def initialize(bits, scale = 0, **options)
      case bits
      when Enumerable
        @bits  = bits
        @mask  = bits.reduce(0) { |v, n| v | 1 << n }
      when Fixnum
        @bits  = bits..bits
        @mask  = 1 << bits
      else
        raise "invalid bit spec"
      end
      @scale   = scale
      @options = if !options.empty?
                   options
                 elsif @bits.size == 1
                   BOOLEAN
                 else
                   EMPTY
                 end
    end

    def bit
      @bits.begin
    end

    def coerce(other)
      [other, self.mask]
    end

    def to_operand(ctx)
      @mask.to_operand(ctx)
    end

    def to_i
      @mask
    end

    def ~
      ~@mask
    end

    def &(other)
      @mask & other
    end

    def ^(other)
      @mask ^ other
    end

    def |(other)
      @mask | other
    end

    def call(value)
      (@options[value] || value.to_i) << (@bits.min - @scale) & @mask
    end

    private

    EMPTY   = { }.freeze
    BOOLEAN = { true  => 1, false => 0 }.freeze
  end
end

