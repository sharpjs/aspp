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

require "minitest/autorun"

require_relative "../lib/aex/bit_field"

module Aex
  module BitFieldTest

    class FromFixnum < Minitest::Test
      def setup
        @field = Aex::BitField.new(7)
      end

      def test_to_i
        assert_equal 0x80, @field.to_i
      end

      def test_complement
        assert_equal ~0x80, ~@field
      end

      def test_call
        assert_equal 0x80, @field.(1)
      end
    end


    class FromRange < Minitest::Test
      def setup
        @field = Aex::BitField.new(5..7)
      end

      def test_to_i
        assert_equal 0xE0, @field.to_i
      end

      def test_complement
        assert_equal ~0xE0, ~@field
      end

      def test_call
        assert_equal 0x60, @field.(3)
      end
    end
  end
end

